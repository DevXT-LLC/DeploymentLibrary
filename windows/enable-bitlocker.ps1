# Enable BitLocker (Windows)
# Enables BitLocker full-disk encryption on the system drive
$ErrorActionPreference = 'Stop'
Write-Host "Checking BitLocker status..."

$Status = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
if ($Status.ProtectionStatus -eq "On") {
    Write-Host "BitLocker is already enabled on C: drive."
    exit 0
}

Write-Host "Enabling BitLocker on C: drive..."

# Enable BitLocker with TPM protector
try {
    Enable-BitLocker -MountPoint "C:" -TpmProtector -EncryptionMethod XtsAes256 -UsedSpaceOnly
    # Add a recovery password
    $RecoveryKey = Add-BitLockerKeyProtector -MountPoint "C:" -RecoveryPasswordProtector
    Write-Host "BitLocker enabled successfully."
    Write-Host "Recovery Key: $($RecoveryKey.KeyProtector[-1].RecoveryPassword)"
    Write-Host "IMPORTANT: Save this recovery key securely!"
} catch {
    Write-Error "Failed to enable BitLocker: $_"
    Write-Host "Ensure TPM is available and the system meets BitLocker requirements."
    exit 1
}
