# Reboot Machine
# Gracefully reboots the machine after a configurable delay
$delay = if ($env:REBOOT_DELAY) { [int]$env:REBOOT_DELAY } else { 5 }
Write-Host "Rebooting machine in $delay seconds..."
shutdown /r /t $delay /c "Scheduled reboot via XT Systems"
