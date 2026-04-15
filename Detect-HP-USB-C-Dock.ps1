param (
    [string]$ConfigFile = ''
)

########################################################################################################################################################################################################
# HP USB-C Dock Detection Script
# Identifies connected HP USB-C docks, extracts serial numbers, outputs hostname, and queries SnipeIT for the assigned user.
########################################################################################################################################################################################################

# HP vendor ID
$hpVid = "03F0"

# Known HP dock Product IDs (PIDs) that carry unique serial numbers on the parent USB Composite Device.
# Evidence collected from physical systems:
#   - PID 046B: HP USB-C Dock G5 (seen on PC1485, PC1701)
#   - PID 0A6B: HP USB-C/A Universal Dock G2 (seen on PC1486)
$knownDockPIDs = @{
    "046B" = "HP USB-C Dock G5"
    "0A6B" = "HP USB-C/A Universal Dock G2"
}

# Additional HP dock-related component PIDs (hubs, audio, etc.) that are part of a dock
# but do not carry unique serial numbers on their composite device entry:
#   036B - Generic USB Hub (G5)
#   056B - HP USB-C Dock Audio Headset (G5)
#   066B - Generic SuperSpeed USB Hub (G5)
#   076B - Generic SuperSpeed USB Hub (G5)
#   086B - Generic USB Hub (G5)
#   096B - Generic USB Hub (G2)
#   0C6B - Generic SuperSpeed USB Hub (G2)
#   0D6B - Generic SuperSpeed USB Hub (G2)
#   0E6B - Generic USB Hub (G2)
#   0269 - HP Thunderbolt Dock Audio Headset

$Hostname = $env:COMPUTERNAME

Write-Host "==== HP USB-C Dock Detection ====" -ForegroundColor Cyan
Write-Host "Hostname: $Hostname" -ForegroundColor White

########################################################################################################################################################################################################
# Dock Detection
########################################################################################################################################################################################################

# Get all HP USB devices for diagnostic display
$allHpDevices = Get-PnpDevice | Where-Object { $_.InstanceId -match "^USB\\VID_$hpVid" }
If ($allHpDevices) {
    Write-Host "`nHP USB devices detected (VID $hpVid):" -ForegroundColor Gray
    $allHpDevices | Select-Object -Property FriendlyName, InstanceId, Status | Format-Table -AutoSize
}

# Find dock parent composite devices by known PID.
# Parent composite devices have InstanceIds like USB\VID_03F0&PID_046B\<SERIAL> (no &MI_ segment).
# Child interface devices have &MI_XX in the path and should be skipped.
$detectedDocks = @()

ForEach ($device in $allHpDevices) {
    If ($device.InstanceId -notmatch "&MI_") {
        If ($device.InstanceId -match "^USB\\VID_$hpVid&PID_([0-9A-Fa-f]{4})\\(.+)$") {
            $devicePid = $Matches[1].ToUpper()
            $serialNumber = $Matches[2]
            If ($knownDockPIDs.ContainsKey($devicePid)) {
                $detectedDocks += [PSCustomObject]@{
                    Model        = $knownDockPIDs[$devicePid]
                    SerialNumber = $serialNumber
                    PID          = $devicePid
                    InstanceId   = $device.InstanceId
                    Status       = $device.Status
                    FriendlyName = $device.FriendlyName
                }
            }
        }
    }
}

# Fallback: name-based detection for HP USB-C docks not matched by known PIDs.
# This handles new or unknown dock models that include "Dock" in the FriendlyName.
$nameMatchedDocks = Get-PnpDevice | Where-Object {
    $_.FriendlyName -match "HP.*USB.*Dock" -and
    $_.InstanceId -notmatch "&MI_" -and
    $_.InstanceId -match "^USB\\" -and
    $_.InstanceId -notin $detectedDocks.InstanceId
}
ForEach ($device in $nameMatchedDocks) {
    If ($device.InstanceId -match "\\([^\\]+)$") {
        $detectedDocks += [PSCustomObject]@{
            Model        = $device.FriendlyName
            SerialNumber = $Matches[1]
            PID          = "Unknown"
            InstanceId   = $device.InstanceId
            Status       = $device.Status
            FriendlyName = $device.FriendlyName
        }
    }
}

# Also detect DisplayLink-based HP docks (VID 17E9), seen as "HP USB-C Universal Docking Station" on PC1486
$displayLinkDocks = Get-PnpDevice | Where-Object {
    $_.FriendlyName -match "HP.*Dock" -and
    $_.InstanceId -match "^USB\\VID_17E9" -and
    $_.InstanceId -notmatch "&MI_"
}
ForEach ($device in $displayLinkDocks) {
    If ($device.InstanceId -match "\\([^\\]+)$") {
        $detectedDocks += [PSCustomObject]@{
            Model        = $device.FriendlyName
            SerialNumber = $Matches[1]
            PID          = "DisplayLink"
            InstanceId   = $device.InstanceId
            Status       = $device.Status
            FriendlyName = $device.FriendlyName
        }
    }
}

########################################################################################################################################################################################################
# Output Results
########################################################################################################################################################################################################

# Filter to only currently connected docks (Status OK) to exclude remembered but disconnected docks
$connectedDocks = $detectedDocks | Where-Object { $_.Status -eq "OK" }

If ($connectedDocks.Count -eq 0) {
    Write-Host "`nNo connected HP USB-C docks detected." -ForegroundColor Yellow
} Else {
    Write-Host "`nConnected HP USB-C Dock(s):" -ForegroundColor Green
    ForEach ($dock in $connectedDocks) {
        Write-Host "  Model:         $($dock.Model)" -ForegroundColor White
        Write-Host "  Serial Number: $($dock.SerialNumber)" -ForegroundColor White
        Write-Host "  Status:        $($dock.Status)" -ForegroundColor White
    }
}

# Also report disconnected (previously seen) docks for diagnostic purposes
$disconnectedDocks = $detectedDocks | Where-Object { $_.Status -ne "OK" }
If ($disconnectedDocks.Count -gt 0) {
    Write-Host "`nPreviously connected dock(s) (currently disconnected):" -ForegroundColor DarkGray
    ForEach ($dock in $disconnectedDocks) {
        Write-Host "  Model:         $($dock.Model)" -ForegroundColor DarkGray
        Write-Host "  Serial Number: $($dock.SerialNumber)" -ForegroundColor DarkGray
        Write-Host "  Status:        $($dock.Status)" -ForegroundColor DarkGray
    }
}

# Detect dock Ethernet adapter (typically Realtek USB GbE on HP docks)
# Evidence shows adapters named "Realtek USB GbE Family Controller" on dock-connected systems
$ethAdapters = Get-NetAdapter | Where-Object {
    $_.InterfaceDescription -match "(Realtek.*USB.*GbE|HP.*Ethernet|USB.*GbE|USB.*Gigabit)" -and $_.Status -eq "Up"
}
If ($ethAdapters) {
    Write-Host "`nDock Ethernet Adapter(s):" -ForegroundColor Cyan
    ForEach ($adapter in $ethAdapters) {
        Write-Host "  $($adapter.Name): $($adapter.InterfaceDescription) - MAC: $($adapter.MacAddress)" -ForegroundColor White
    }
}

########################################################################################################################################################################################################
# SnipeIT Lookup
########################################################################################################################################################################################################

If ($ConfigFile -and (Test-Path $ConfigFile)) {
    $Config = (Get-Content $ConfigFile) | ConvertFrom-Json
    $Snipe = $Config.Snipe

    Try {
        If (-not (Get-Module -ListAvailable -Name SnipeitPS)) {
            Write-Host "`nSnipeitPS module is not installed. Install it with: Install-Module -Name SnipeitPS" -ForegroundColor Red
            Write-Host "Skipping SnipeIT lookup." -ForegroundColor Yellow
        } Else {
            Import-Module SnipeitPS -ErrorAction Stop
            Connect-SnipeitPS -URL $Snipe.Url -apiKey $Snipe.Token

            # Look up the PC asset in SnipeIT by BIOS serial number (same approach as AssetSelfReport.ps1)
            $pcSerial = $null
            Try {
                $pcSerial = (Get-CimInstance -ClassName Win32_BIOS).SerialNumber
            } Catch {
                Write-Host "`nUnable to retrieve BIOS serial number, falling back to hostname lookup." -ForegroundColor Yellow
            }

            $SnipeAsset = $null
            If ($pcSerial) {
                $SnipeAsset = Get-SnipeItAsset -asset_serial $pcSerial

                # Retry once on error (same pattern as AssetSelfReport.ps1)
                If ($SnipeAsset.StatusCode -eq 'InternalServerError') {
                    $SnipeAsset = Get-SnipeItAsset -asset_serial $pcSerial
                }
            }

            # Fallback: search by hostname if serial lookup returned nothing
            If (-not $SnipeAsset -or $SnipeAsset.StatusCode) {
                $SnipeAsset = Get-SnipeItAsset -Search $Hostname | Where-Object { $_.name -eq $Hostname } | Select-Object -First 1
            }

            If ($SnipeAsset -and $SnipeAsset.assigned_to) {
                Write-Host "`nSnipeIT Asset Information:" -ForegroundColor Cyan
                Write-Host "  Asset Name:    $($SnipeAsset.name)" -ForegroundColor White
                Write-Host "  Assigned To:   $($SnipeAsset.assigned_to.name)" -ForegroundColor White
                Write-Host "  Username:      $($SnipeAsset.assigned_to.username)" -ForegroundColor White
            } ElseIf ($SnipeAsset -and -not $SnipeAsset.assigned_to) {
                Write-Host "`nSnipeIT Asset Information:" -ForegroundColor Cyan
                Write-Host "  Asset Name:    $($SnipeAsset.name)" -ForegroundColor White
                Write-Host "  Assigned To:   (not assigned)" -ForegroundColor Yellow
            } Else {
                Write-Host "`nPC not found in SnipeIT or not assigned to a user." -ForegroundColor Yellow
            }
        }
    } Catch {
        Write-Host "`nUnable to query SnipeIT: $_" -ForegroundColor Red
    }
} Else {
    Write-Host "`nNo config file provided - skipping SnipeIT lookup." -ForegroundColor Yellow
    Write-Host "Use -ConfigFile parameter to enable SnipeIT user lookup." -ForegroundColor Yellow
}

Write-Host "`n==== Detection Complete ====" -ForegroundColor Cyan
