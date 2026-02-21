# Collect System Information (Windows)
Write-Host "=== System Information ==="
Write-Host ""
Write-Host "--- OS ---"
Get-CimInstance Win32_OperatingSystem | Format-List Caption, Version, BuildNumber, OSArchitecture
Write-Host "--- Computer ---"
Get-CimInstance Win32_ComputerSystem | Format-List Name, Domain, Manufacturer, Model, TotalPhysicalMemory
Write-Host "--- Processor ---"
Get-CimInstance Win32_Processor | Format-List Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
Write-Host "--- Disk ---"
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | Format-Table DeviceID, @{N='Size(GB)';E={[math]::Round($_.Size/1GB,2)}}, @{N='Free(GB)';E={[math]::Round($_.FreeSpace/1GB,2)}}
Write-Host "--- Network ---"
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne "127.0.0.1" } | Format-Table InterfaceAlias, IPAddress
Write-Host "--- GPU ---"
Get-CimInstance Win32_VideoController | Format-List Name, DriverVersion, AdapterRAM
Write-Host "=== End System Information ==="
