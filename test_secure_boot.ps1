# Test Script for Secure Boot and BIOS Information Collection
# This script tests the new functionality without requiring a full SnipeIT environment

Write-Host "=== Testing Secure Boot and BIOS Information Collection ===" -ForegroundColor Cyan
Write-Host ""

# Simulate the Win32_BIOS object that would be available in the main script
$Win32_BIOS = Get-CimInstance -ClassName Win32_BIOS
$SerialNumber = $Win32_BIOS.SerialNumber
If (!$SerialNumber) { $SerialNumber = "TEST123" }

Write-Host "System Information:" -ForegroundColor Yellow
Write-Host "  Serial Number: $SerialNumber"
Write-Host "  BIOS Version: $($Win32_BIOS.SMBIOSBIOSVersion)"
Write-Host "  BIOS Manufacturer: $($Win32_BIOS.Manufacturer)"
Write-Host ""

# Test 1: Secure Boot Status
Write-Host "Test 1: Secure Boot Status" -ForegroundColor Green
Try {
    $SecureBootEnabled = Confirm-SecureBootUEFI -ErrorAction Stop
    If ($SecureBootEnabled -eq $true) {
        $SecureBootStatus = "Enabled"
    } ElseIf ($SecureBootEnabled -eq $false) {
        $SecureBootStatus = "Disabled"
    } Else {
        $SecureBootStatus = "Unknown"
    }
} Catch {
    $SecureBootStatus = "Not Supported (Legacy BIOS)"
}
Write-Host "  Result: $SecureBootStatus" -ForegroundColor Cyan
Write-Host ""

# --- Replacement "Test 2: Secure Boot Certificate Expiry" block ---

Write-Host "Test 2: Secure Boot Certificate Expiry" -ForegroundColor Green
$SecureBootCertInfo = ""

# GUIDs from UEFI spec
$GUID_X509   = [guid]'a5c059a1-94e4-4aa7-87b5-ab155c2bf072'  # EFI_CERT_X509_GUID
$GUID_SHA256 = [guid]'c1c41626-504c-4092-aca9-41f936934328'  # EFI_CERT_SHA256_GUID
$GUID_PKCS7  = [guid]'4aafd29d-68df-49ee-8aa9-347d375665a7'  # EFI_CERT_TYPE_PKCS7_GUID'

function Read-UInt32LE([byte[]]$b, [int]$o) { :ToUInt32($b, $o) }
function Get-Guid([byte[]]$b, [int]$o) {
    $slice = New-Object byte[] 16
    :BlockCopy($b, $o, $slice, 0, 16)
    # Guid(byte[]) ctor expects little-endian fields as in UEFI storage
    return New-Object System.Guid(,$slice)
}

function Parse-Db {
    param([byte[]]$Raw)

    $result = New-Object System.Collections.Generic.List[object]
    $ofs = 0
    $HDR = 16 + 4 + 4 + 4  # Type(16) + ListSize + HeaderSize + SigSize

    while ($ofs -le $Raw.Length - $HDR) {
        $sigType = Get-Guid $Raw $ofs; $ofs += 16
        $listSize = Read-UInt32LE $Raw $ofs; $ofs += 4
        $hdrSize  = Read-UInt32LE $Raw $ofs; $ofs += 4
        $sigSize  = Read-UInt32LE $Raw $ofs; $ofs += 4

        # Bounds check
        $listStart = $ofs - $HDR
        $listEnd   = $listStart + $listSize
        if ($listSize -lt $HDR -or $listEnd -gt $Raw.Length -or $sigSize -lt 16) {
            # Malformed list; bail out of this list
            $ofs = $listEnd
            continue
        }

        # Skip signature header (rarely used)
        $ofs += $hdrSize

        # Walk EFI_SIGNATURE_DATA entries
        while ($ofs + $sigSize -le $listEnd) {
            # First 16 bytes is Owner GUID, remainder is SignatureData
            $owner = Get-Guid $Raw $ofs
            $ofsOwnerEnd = $ofs + 16
            $dataLen = $sigSize - 16

            $sigData = New-Object byte[] $dataLen
            :BlockCopy($Raw, $ofsOwnerEnd, $sigData, 0, $dataLen)
            $ofs += $sigSize

            switch ($true) {
                { $sigType -eq $GUID_X509 } {
                    try {
                        $x = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,$sigData)
                        $result.Add([pscustomobject]@{
                            Type        = 'X509'
                            OwnerGuid   = $owner
                            Subject     = $x.Subject
                            Issuer      = $x.Issuer
                            NotAfter    = $x.NotAfter
                            Thumbprint  = $x.Thumbprint
                        })
                    } catch {}
                }
                { $sigType -eq $GUID_PKCS7 } {
                    try {
                        Add-Type -AssemblyName System.Security # for Pkcs
                        Add-Type -AssemblyName System.Security.Cryptography
                        $cms = New-Object System.Security.Cryptography.Pkcs.SignedCms
                        $cms.Decode($sigData)
                        foreach ($c in $cms.Certificates) {
                            $result.Add([pscustomobject]@{
                                Type        = 'PKCS7-Cert'
                                OwnerGuid   = $owner
                                Subject     = $c.Subject
                                Issuer      = $c.Issuer
                                NotAfter    = $c.NotAfter
                                Thumbprint  = $c.Thumbprint
                            })
                        }
                    } catch {}
                }
                { $sigType -eq $GUID_SHA256 } {
                    # Hash allow-list entry; no expiry
                    $result.Add([pscustomobject]@{
                        Type        = 'SHA256-Hash'
                        OwnerGuid   = $owner
                        Subject     = '<hash entry>'
                        Issuer      = ''
                        NotAfter    = $null
                        Thumbprint  = (:ToString($sigData) -replace '-', '')
                    })
                }
                default {
                    # Unknown/other signature type; record basics
                    $result.Add([pscustomobject]@{
                        Type        = "Other:$sigType"
                        OwnerGuid   = $owner
                        Subject     = ''
                        Issuer      = ''
                        NotAfter    = $null
                        Thumbprint  = ''
                    })
                }
            }
        }

        # move to next list (in case of padding/misalignment)
        $ofs = $listEnd
    }

    # De-duplicate by Thumbprint when present (PKCS7 can contain repeats)
    $seen = @{}
    $unique = foreach ($r in $result) {
        $key = if ($r.Thumbprint) { $r.Type + ':' + $r.Thumbprint } else { :NewGuid().ToString() }
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $r
        }
    }
    return ,$unique
}

try {
    if ($SecureBootStatus -in @('Enabled','Disabled')) {
        $raw = (Get-SecureBootUEFI -Name db -ErrorAction Stop).Bytes
        Write-Host "  Parsing EFI signature lists ($($raw.Length) bytes)..." -ForegroundColor Cyan
        $entries = Parse-Db -Raw $raw

        $certs = $entries | Where-Object { $_.Type -in 'X509','PKCS7-Cert' }
        $hashes = $entries | Where-Object { $_.Type -eq 'SHA256-Hash' }

        Write-Host ("  Found {0} certificate(s), {1} hash entry/entries" -f $certs.Count, $hashes.Count) -ForegroundColor Cyan
        Write-Host ""

        if ($certs.Count -gt 0) {
            $today = Get-Date
            $lines = @()
            foreach ($c in ($certs | Sort-Object Subject, NotAfter -Unique)) {
                $days = if ($c.NotAfter) { ($c.NotAfter - $today).Days } else { $null }
                $expiry = if ($c.NotAfter) { $c.NotAfter.ToString('yyyy-MM-dd') } else { 'N/A' }
                $subjectCN = ($c.Subject -replace '^.*CN=([^,]+).*$','$1')

                if ($days -lt 0) { $status = "EXPIRED"; $color = "Red" }
                elseif ($days -lt 180) { $status = "EXPIRING SOON"; $color = "Yellow" }
                else { $status = "Valid"; $color = "Green" }

                Write-Host ("    {0}" -f $subjectCN) -ForegroundColor White
                Write-Host ("      Expires: {0} ({1}{2})" -f $expiry, $status, $(if ($days -ne $null) { ", $days days" } else { "" })) -ForegroundColor $color
                $lines += ("{0} : {1} ({2}{3})" -f $subjectCN, $expiry, $status, $(if ($days -ne $null) { ", $days days" } else { "" }))
            }

            # Your summary sink
            $SecureBootCertInfo = $lines -join "`n"

            # Your early-2026 warning:
            $exp26 = $certs | Where-Object { $_.NotAfter -and $_.NotAfter.Year -eq 2026 -and $_.NotAfter.Month -le 6 }
            if ($exp26.Count -gt 0) {
                Write-Host ""
                Write-Host ("  WARNING: Found {0} certificate(s) expiring in early 2026!" -f $exp26.Count) -ForegroundColor Red
            }
        }
        else {
            $SecureBootCertInfo = "No X.509 certificates present (DB may contain only hashes)."
            Write-Host "  $SecureBootCertInfo" -ForegroundColor Yellow
        }
    } else {
        $SecureBootCertInfo = "N/A (Secure Boot not supported)"
        Write-Host "  $SecureBootCertInfo" -ForegroundColor Gray
    }
} catch {
    $SecureBootCertInfo = "Unable to read/parse Secure Boot DB ($($_.Exception.Message))"
    Write-Host "  $SecureBootCertInfo" -ForegroundColor Yellow
}

# Test 3: BIOS Release Date
Write-Host "Test 3: BIOS Release Date" -ForegroundColor Green
If ($Win32_BIOS.ReleaseDate) {
    Try {
        # CIM uses DateTime objects directly, no conversion needed
        $BiosReleaseDate = $Win32_BIOS.ReleaseDate;
        $BiosReleaseDateFormatted = $BiosReleaseDate.ToString('yyyy-MM-dd');
        Write-Host "  Result: $BiosReleaseDateFormatted" -ForegroundColor Cyan
        
        $DaysSinceRelease = (Get-Date) - $BiosReleaseDate;
        Write-Host "  Age: $([math]::Round($DaysSinceRelease.TotalDays / 365, 1)) years" -ForegroundColor Cyan
    } Catch {
        $BiosReleaseDateFormatted = '';
        Write-Host "  Result: Unable to parse date" -ForegroundColor Yellow
    }
} Else {
    $BiosReleaseDateFormatted = '';
    Write-Host "  Result: Not available" -ForegroundColor Yellow
}
Write-Host ""

# Summary
Write-Host "=== Summary of Data to be Added to DataHashTable ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "DataHashTable['SecureBootStatus'] = '$SecureBootStatus'"
Write-Host "DataHashTable['SecureBootCertExpiry'] = " 
If ($SecureBootCertInfo) {
    $SecureBootCertInfo -split "`n" | ForEach-Object { Write-Host "  $_" }
} Else {
    Write-Host "  (empty)"
}
Write-Host "DataHashTable['BiosReleaseDate'] = '$BiosReleaseDateFormatted'"
Write-Host ""

# Final note
Write-Host "=== Test Complete ===" -ForegroundColor Green
Write-Host "If you see 'Unable to read certificates', run this script as Administrator" -ForegroundColor Yellow
