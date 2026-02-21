# Shutdown Machine (Windows)
$delay = if ($env:SHUTDOWN_DELAY) { [int]$env:SHUTDOWN_DELAY } else { 5 }
Write-Host "Shutting down machine in $delay seconds..."
shutdown /s /t $delay /c "Scheduled shutdown via XT Systems"
