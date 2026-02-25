# Set Timezone (Windows)
# Changes the system timezone
$ErrorActionPreference = 'Stop'
$Timezone = $env:TIMEZONE

if (-not $Timezone) {
    Write-Error "TIMEZONE environment variable is required (e.g. 'Eastern Standard Time')."
    Write-Host "Available timezones:"
    Get-TimeZone -ListAvailable | Select-Object -Property Id | Format-Table
    exit 1
}

Write-Host "Setting timezone to: $Timezone"
Set-TimeZone -Id $Timezone
Write-Host "Timezone set to: $((Get-TimeZone).Id)"
