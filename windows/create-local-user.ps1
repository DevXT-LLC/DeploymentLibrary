# Create Local User (Windows)
# Creates a new local user account
$ErrorActionPreference = 'Stop'
$Username = $env:NEW_USERNAME
$Password = $env:NEW_PASSWORD
$FullName = if ($env:NEW_FULLNAME) { $env:NEW_FULLNAME } else { $Username }
$IsAdmin = $env:MAKE_ADMIN -eq "true"

if (-not $Username -or -not $Password) {
    Write-Error "NEW_USERNAME and NEW_PASSWORD environment variables are required."
    exit 1
}

Write-Host "Creating local user: $Username..."

$SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
New-LocalUser -Name $Username -Password $SecurePassword -FullName $FullName -PasswordNeverExpires -Description "Created by XT Systems"

if ($IsAdmin) {
    Add-LocalGroupMember -Group "Administrators" -Member $Username
    Write-Host "User added to Administrators group."
}

Write-Host "Local user '$Username' created successfully."
