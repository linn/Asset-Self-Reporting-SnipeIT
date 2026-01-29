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

# Test 2: Secure Boot Certificate Expiry
Write-Host "Test 2: Secure Boot Certificate Expiry" -ForegroundColor Green
$SecureBootCertInfo = "";
If ($SecureBootStatus -eq "Enabled" -or $SecureBootStatus -eq "Disabled") {
    Try {
        # Export Secure Boot db to temp file (sanitize serial number for filename)
        $SanitizedSerial = $SerialNumber -replace '[\\/:*?"<>|]', '_';
        $TempDbPath = "$env:TEMP\secureboot_db_$($SanitizedSerial).bin";
        $SecureBootDb = Get-SecureBootUEFI -Name db -OutputFilePath $TempDbPath -ErrorAction Stop;
        
        If (Test-Path $TempDbPath) {
            $dbBytes = [System.IO.File]::ReadAllBytes($TempDbPath);
            $Certificates = @();
            
            Write-Host "  Parsing certificate database ($($dbBytes.Length) bytes)..." -ForegroundColor Cyan
            
            # Parse X.509 certificates from the UEFI variable
            For ($i = 0; $i -lt $dbBytes.Length - 3; $i++) {
                If ($dbBytes[$i] -eq 0x30 -and $dbBytes[$i+1] -eq 0x82) {
                    $length = ([int]$dbBytes[$i+2] -shl 8) + [int]$dbBytes[$i+3] + 4;
                    
                    If (($i + $length) -le $dbBytes.Length -and $length -gt 4 -and $length -lt 10000) {
                        Try {
                            $certBytes = $dbBytes[$i..($i+$length-1)];
                            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @(,$certBytes);
                            
                            $Certificates += [PSCustomObject]@{
                                Subject = $cert.Subject;
                                NotAfter = $cert.NotAfter;
                            }
                            
                            $i += $length - 1;
                        } Catch {
                            # Not a valid certificate, continue searching
                        }
                    }
                }
            }
            
            Write-Host "  Found $($Certificates.Count) certificate(s)" -ForegroundColor Cyan
            Write-Host ""
            
            # Format certificate expiry information
            If ($Certificates.Count -gt 0) {
                $Today = Get-Date;
                $CertLines = @();
                
                ForEach ($cert in $Certificates) {
                    $DaysUntilExpiry = ($cert.NotAfter - $Today).Days;
                    $ExpiryDate = $cert.NotAfter.ToString('yyyy-MM-dd');
                    $Subject = ($cert.Subject -replace 'CN=', '' -replace ',.*', '').Trim();
                    
                    If ($DaysUntilExpiry -lt 0) {
                        $Status = "EXPIRED";
                        $Color = "Red";
                    } ElseIf ($DaysUntilExpiry -lt 180) {
                        $Status = "EXPIRING SOON";
                        $Color = "Yellow";
                    } Else {
                        $Status = "Valid";
                        $Color = "Green";
                    }
                    
                    Write-Host "    $Subject" -ForegroundColor White
                    Write-Host "      Expires: $ExpiryDate ($Status, $DaysUntilExpiry days)" -ForegroundColor $Color
                    
                    $CertLines += "$Subject : $ExpiryDate ($Status, $DaysUntilExpiry days)";
                }
                
                $SecureBootCertInfo = $CertLines -join "`n";
                
                # Check for certificates expiring in 2026
                $ExpiringIn2026 = $Certificates | Where-Object { $_.NotAfter.Year -eq 2026 -and $_.NotAfter.Month -le 6 };
                If ($ExpiringIn2026.Count -gt 0) {
                    Write-Host ""
                    Write-Host "  WARNING: Found $($ExpiringIn2026.Count) certificate(s) expiring in early 2026!" -ForegroundColor Red
                }
            } Else {
                $SecureBootCertInfo = "No certificates found in db";
                Write-Host "  $SecureBootCertInfo" -ForegroundColor Yellow
            }
            
            # Clean up temp file
            Remove-Item $TempDbPath -Force -ErrorAction SilentlyContinue;
        }
    } Catch {
        $SecureBootCertInfo = "Unable to read certificates (requires admin privileges)";
        Write-Host "  $SecureBootCertInfo" -ForegroundColor Yellow
    }
} Else {
    $SecureBootCertInfo = "N/A (Secure Boot not supported)";
    Write-Host "  $SecureBootCertInfo" -ForegroundColor Gray
}
Write-Host ""

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
