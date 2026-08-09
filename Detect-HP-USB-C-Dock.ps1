# Detect HP USB-C Dock (G5 and relatives) and retrieve Ethernet MAC address
Write-Host "==== HP USB-C Dock Diagnostic ====" -ForegroundColor Cyan

# HP vendor ID (03f0) as string for matching
$hpVid = "03f0"

# Common HP G5 Dock product IDs found in lsusb dump
$hpDockPIDs = @("036b","046b","056b","066b","076b","086b")
$potentialDockFound = $false

# Display all HP USB Devices attached (in case multiple present)
$allHpDevices = Get-PnpDevice | Where-Object { $_.InstanceId -match "^USB\\VID_$hpVid" }
if ($allHpDevices) {
    Write-Host "USB devices with HP VID ($hpVid):"
    $allHpDevices |
        Select-Object -Property FriendlyName, InstanceId, Status |
        Format-Table -AutoSize
} else {
    Write-Host "No HP USB devices detected."
}

# Attempt to specifically find a G5 Dock by PID (partial match, tolerates minor variants)
$dockDevices = Get-PnpDevice | Where-Object {
    $_.InstanceId -match "^USB\\VID_$hpVid&PID_([0-9A-F]{4})" -and
    $hpDockPIDs -contains ($matches[1])
}
if ($dockDevices) {
    Write-Host "`nPotential HP Dock found:" -ForegroundColor Green
    $dockDevices | Select-Object FriendlyName, InstanceId, Status | Format-Table -AutoSize
    $potentialDockFound = $true
} else {
    Write-Host "`nCould not positively identify a known HP Dock model via VID/PID, scanning by Product name..." -ForegroundColor Yellow
    # Fallback: search all present USB devices for anything dock/g5 related in the name
    $dockDevices = Get-PnpDevice | Where-Object { $_.FriendlyName -match "Dock|G5" }
    if ($dockDevices) {
        Write-Host "Possible dock device(s) via product name match:"
        $dockDevices | Select-Object FriendlyName, InstanceId, Status | Format-Table -AutoSize
        $potentialDockFound = $true
    }
}

# Now try to get MAC for USB-attached Ethernet (as in your dump, usually Realtek)
$ethAdapters = Get-NetAdapter | Where-Object {
    $_.InterfaceDescription -match "HP|Realtek|USB" -and $_.Status -eq "Up"
}
if ($ethAdapters) {
    Write-Host "`nUSB/Ethernet Adapters detected (likely dock LAN):" -ForegroundColor Cyan
    $ethAdapters | Select-Object Name, InterfaceDescription, MacAddress, Status | Format-Table -AutoSize

    # Heuristic: try to link adapter to dock's USB chain (direct relation impossible from Win shell, but show info)
    foreach ($adapter in $ethAdapters) {
        Write-Host ("Possible dock MAC: " + $adapter.MacAddress) -ForegroundColor Green
    }
} else {
    Write-Host "`nNo active USB/Ethernet adapters matching HP/Realtek string found."
}

Write-Host "`n==== Diagnostics Complete ====" -ForegroundColor Cyan