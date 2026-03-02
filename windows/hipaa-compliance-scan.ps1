# HIPAA Compliance Scan (Windows)
# Assesses system configuration against HIPAA Security Rule requirements
# Covers Administrative, Physical, and Technical Safeguards
# Reference: 45 CFR Part 164 - Security and Privacy

$ErrorActionPreference = "SilentlyContinue"
$ReportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$Hostname = $env:COMPUTERNAME

Write-Host "========================================================================"
Write-Host "  HIPAA COMPLIANCE ASSESSMENT REPORT"
Write-Host "  Host: $Hostname"
Write-Host "  Date: $ReportDate"
Write-Host "  OS: $((Get-CimInstance Win32_OperatingSystem).Caption)"
Write-Host "  Framework: HIPAA Security Rule (45 CFR 164.312)"
Write-Host "========================================================================"
Write-Host ""

$Global:Compliant = 0
$Global:NonCompliant = 0
$Global:NeedsReview = 0

function Print-Compliant($Title, $HipaaRef) {
    $Global:Compliant++
    Write-Host "[COMPLIANT] $Title" -ForegroundColor Green
    Write-Host "  HIPAA Ref: $HipaaRef"
    Write-Host ""
}

function Print-NonCompliant($Title, $HipaaRef, $Finding, $RequiredAction) {
    $Global:NonCompliant++
    Write-Host "[NON-COMPLIANT] $Title" -ForegroundColor Red
    Write-Host "  HIPAA Ref: $HipaaRef"
    Write-Host "  Finding: $Finding"
    Write-Host "  Required Action: $RequiredAction"
    Write-Host ""
}

function Print-Review($Title, $HipaaRef, $Details) {
    $Global:NeedsReview++
    Write-Host "[NEEDS REVIEW] $Title" -ForegroundColor Yellow
    Write-Host "  HIPAA Ref: $HipaaRef"
    Write-Host "  Details: $Details"
    Write-Host ""
}

# ============================================================
# 164.312(a)(1) - ACCESS CONTROL
# ============================================================
Write-Host "================================================================"
Write-Host "  164.312(a)(1) - ACCESS CONTROL"
Write-Host "  Standard: Implement technical policies and procedures for"
Write-Host "  electronic information systems that maintain ePHI"
Write-Host "================================================================"
Write-Host ""

# (i) Unique User Identification (Required)
Write-Host "--- 164.312(a)(2)(i) - Unique User Identification [REQUIRED] ---"
Write-Host ""

$LocalUsers = Get-LocalUser
$EnabledUsers = $LocalUsers | Where-Object { $_.Enabled -eq $true }
Write-Host "  Local user accounts:"
$EnabledUsers | Format-Table Name, Enabled, PasswordRequired, LastLogon -AutoSize

# Check for generic/shared accounts
$GenericNames = @("shared", "generic", "temp", "test", "guest", "service", "user1", "admin1")
$GenericFound = $EnabledUsers | Where-Object { $GenericNames -contains $_.Name.ToLower() -or $_.Name -match "^(shared|generic|temp|test)" }
if ($GenericFound) {
    Print-NonCompliant "Potential shared/generic accounts detected" "164.312(a)(2)(i)" ($GenericFound.Name -join ", ") "Replace with individually-assigned user accounts"
} else {
    Print-Compliant "No shared/generic accounts detected" "164.312(a)(2)(i)"
}

# (iii) Automatic Logoff (Addressable)
Write-Host "--- 164.312(a)(2)(iii) - Automatic Logoff [ADDRESSABLE] ---"
Write-Host ""

# Check screen saver timeout and lock
$ScreenSaverTimeout = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ScreenSaveTimeOut" -ErrorAction SilentlyContinue).ScreenSaveTimeOut
$ScreenSaverActive = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ScreenSaveActive" -ErrorAction SilentlyContinue).ScreenSaveActive
$ScreenSaverLock = (Get-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "ScreenSaverIsSecure" -ErrorAction SilentlyContinue).ScreenSaverIsSecure

Write-Host "  Screen saver active: $ScreenSaverActive"
Write-Host "  Screen saver timeout: $ScreenSaverTimeout seconds"
Write-Host "  Screen saver lock: $ScreenSaverLock"
Write-Host ""

if ($ScreenSaverActive -eq "1" -and $ScreenSaverLock -eq "1") {
    if ($ScreenSaverTimeout -and [int]$ScreenSaverTimeout -le 900) {
        Print-Compliant "Screen lock timeout is set to $ScreenSaverTimeout seconds" "164.312(a)(2)(iii)"
    } else {
        Print-NonCompliant "Screen lock timeout exceeds 15 minutes" "164.312(a)(2)(iii)" "Timeout: $ScreenSaverTimeout seconds" "Set screen saver timeout to 900 seconds (15 min) or less"
    }
} else {
    Print-NonCompliant "Screen lock is not properly configured" "164.312(a)(2)(iii)" "Screen saver lock not enabled" "Enable screen saver with password lock via Group Policy"
}

# Check idle session disconnect for RDP
$RDPTimeout = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -Name "MaxIdleTime" -ErrorAction SilentlyContinue).MaxIdleTime
if ($RDPTimeout) {
    $RDPTimeoutMin = $RDPTimeout / 60000
    Write-Host "  RDP idle timeout: $RDPTimeoutMin minutes"
    if ($RDPTimeoutMin -le 15) {
        Print-Compliant "RDP idle timeout is $RDPTimeoutMin minutes" "164.312(a)(2)(iii)"
    } else {
        Print-NonCompliant "RDP idle timeout is $RDPTimeoutMin minutes" "164.312(a)(2)(iii)" "Exceeds 15 minute recommendation" "Set via Group Policy: Computer Config > Admin Templates > Terminal Services"
    }
} else {
    Print-Review "RDP idle timeout not configured via policy" "164.312(a)(2)(iii)" "Configure via Group Policy for remote access sessions"
}

# (iv) Encryption and Decryption (Addressable)
Write-Host "--- 164.312(a)(2)(iv) - Encryption and Decryption [ADDRESSABLE] ---"
Write-Host ""

# Check BitLocker
try {
    $BitLockerVolumes = Get-BitLockerVolume -ErrorAction Stop
    $AllEncrypted = $true
    foreach ($vol in $BitLockerVolumes) {
        Write-Host "  Drive $($vol.MountPoint): Protection=$($vol.ProtectionStatus), Encryption=$($vol.EncryptionMethod), Percentage=$($vol.EncryptionPercentage)%"
        if ($vol.ProtectionStatus -ne "On") {
            $AllEncrypted = $false
        }
    }
    Write-Host ""
    if ($AllEncrypted) {
        Print-Compliant "All drives are encrypted with BitLocker" "164.312(a)(2)(iv)"
    } else {
        Print-NonCompliant "Not all drives are encrypted" "164.312(a)(2)(iv)" "Unencrypted volumes detected" "Enable BitLocker on all drives containing ePHI"
    }
} catch {
    Print-NonCompliant "Unable to verify BitLocker encryption" "164.312(a)(2)(iv)" "BitLocker may not be available or enabled" "Verify disk encryption status and enable BitLocker"
}

# Check EFS availability
$EFSStatus = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\EFS" -Name "EfsConfiguration" -ErrorAction SilentlyContinue).EfsConfiguration
if ($EFSStatus -eq 1) {
    Print-Review "EFS is disabled by policy" "164.312(a)(2)(iv)" "EFS is disabled - ensure BitLocker or other encryption protects ePHI"
} else {
    Write-Host "  EFS (Encrypting File System) is available"
    Write-Host ""
}

# ============================================================
# 164.312(b) - AUDIT CONTROLS
# ============================================================
Write-Host "================================================================"
Write-Host "  164.312(b) - AUDIT CONTROLS"
Write-Host "  Standard: Implement mechanisms to record and examine"
Write-Host "  activity in systems containing or using ePHI"
Write-Host "================================================================"
Write-Host ""

# Check audit policies
Write-Host "--- Audit Policy Configuration ---"
$AuditCategories = @{
    "Account Logon" = "Logon/Logoff"
    "Account Management" = "Account Management"
    "Object Access" = "Object Access"
    "Policy Change" = "Policy Change"
    "Privilege Use" = "Privilege Use"
    "System" = "System"
}

$AuditOutput = auditpol /get /category:* 2>&1
$NoAuditCount = ($AuditOutput | Select-String "No Auditing").Count
$TotalPolicies = ($AuditOutput | Select-String "Success|Failure|No Auditing").Count

Write-Host "  Audit policies configured: $($TotalPolicies - $NoAuditCount) / $TotalPolicies"
Write-Host "  Policies with 'No Auditing': $NoAuditCount"
Write-Host ""

# Check critical audit subcategories
$CriticalAudits = @("Logon", "Logoff", "Account Lockout", "User Account Management", "Security Group Management", "File System", "Registry")
$MissingAudits = @()
foreach ($audit in $CriticalAudits) {
    $line = $AuditOutput | Select-String $audit | Select-Object -First 1
    if ($line -and $line -match "No Auditing") {
        $MissingAudits += $audit
    }
}

if ($MissingAudits.Count -gt 0) {
    Print-NonCompliant "Critical audit categories not enabled" "164.312(b)" ("Missing: " + ($MissingAudits -join ", ")) "Enable via: auditpol /set /subcategory:'Logon' /success:enable /failure:enable"
} else {
    Print-Compliant "Critical audit categories are enabled" "164.312(b)"
}

# Check event log sizes and retention
Write-Host "--- Event Log Configuration ---"
$LogNames = @("Security", "System", "Application")
foreach ($logName in $LogNames) {
    $log = Get-WinEvent -ListLog $logName -ErrorAction SilentlyContinue
    if ($log) {
        $MaxMB = [math]::Round($log.MaximumSizeInBytes / 1MB, 2)
        $CurrentMB = [math]::Round($log.FileSize / 1MB, 2)
        Write-Host "  $logName : $CurrentMB MB / $MaxMB MB (Mode: $($log.LogMode))"
        if ($MaxMB -lt 128) {
            Print-NonCompliant "$logName log max size is only $MaxMB MB" "164.312(b)" "HIPAA requires adequate log retention" "Increase: wevtutil sl $logName /ms:134217728 (128 MB minimum)"
        }
    }
}
Write-Host ""

# Check if Windows Event Forwarding is configured
$WEFSubscriptions = wecutil es 2>&1
if ($WEFSubscriptions -and $WEFSubscriptions -notmatch "Error") {
    Print-Compliant "Windows Event Forwarding subscriptions found" "164.312(b)"
} else {
    Print-Review "No Windows Event Forwarding configured" "164.312(b)" "Consider centralized log collection for ePHI access monitoring"
}

# Check log retention meets HIPAA 6-year requirement
Print-Review "Verify log backup/archival meets 6-year retention" "164.312(b)" "HIPAA requires audit log retention for 6 years minimum"

# ============================================================
# 164.312(c)(1) - INTEGRITY
# ============================================================
Write-Host "================================================================"
Write-Host "  164.312(c)(1) - INTEGRITY CONTROLS"
Write-Host "  Standard: Protect ePHI from improper alteration"
Write-Host "================================================================"
Write-Host ""

# Check Windows Defender / Tamper Protection
try {
    $DefenderStatus = Get-MpComputerStatus -ErrorAction Stop
    if ($DefenderStatus.IsTamperProtected) {
        Print-Compliant "Windows Defender Tamper Protection is ON" "164.312(c)(2)"
    } else {
        Print-NonCompliant "Windows Defender Tamper Protection is OFF" "164.312(c)(2)" "Security settings can be tampered with" "Enable Tamper Protection in Windows Security settings"
    }
    if ($DefenderStatus.RealTimeProtectionEnabled) {
        Print-Compliant "Real-time protection is enabled" "164.312(c)(2)"
    } else {
        Print-NonCompliant "Real-time protection is DISABLED" "164.312(c)(2)" "Files are not being monitored for changes" "Enable real-time protection"
    }
} catch {
    Print-Review "Unable to check Windows Defender status" "164.312(c)(2)" "Verify endpoint protection is active"
}

# Check System Restore
$SRStatus = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "RPSessionInterval" -ErrorAction SilentlyContinue)
if ($SRStatus) {
    Print-Compliant "System Restore is configured" "164.312(c)(1)"
} else {
    Print-Review "System Restore configuration not verified" "164.312(c)(1)" "Ensure system restore points are created regularly"
}

# Check Windows File Integrity (sfc)
Write-Host "  Note: Run 'sfc /scannow' periodically to verify system file integrity"
Write-Host ""
Print-Review "Schedule periodic System File Checker (sfc) scans" "164.312(c)(2)" "Run: sfc /scannow to verify Windows system file integrity"

# ============================================================
# 164.312(d) - PERSON OR ENTITY AUTHENTICATION
# ============================================================
Write-Host "================================================================"
Write-Host "  164.312(d) - PERSON OR ENTITY AUTHENTICATION"
Write-Host "  Standard: Verify identity of persons seeking ePHI access"
Write-Host "================================================================"
Write-Host ""

# Check password policy
Write-Host "--- Password Policy ---"
$NetAccounts = net accounts 2>&1
$NetAccounts | ForEach-Object { Write-Host "  $_" }
Write-Host ""

# Parse password policy values
$MinPwdLen = ($NetAccounts | Select-String "Minimum password length").ToString() -replace '.*:\s*', ''
$MaxPwdAge = ($NetAccounts | Select-String "Maximum password age").ToString() -replace '.*:\s*', ''
$MinPwdAge = ($NetAccounts | Select-String "Minimum password age").ToString() -replace '.*:\s*', ''
$LockoutThreshold = ($NetAccounts | Select-String "Lockout threshold").ToString() -replace '.*:\s*', ''
$LockoutDuration = ($NetAccounts | Select-String "Lockout duration").ToString() -replace '.*:\s*', ''

# Minimum password length
if ($MinPwdLen -match '\d+' -and [int]$Matches[0] -ge 12) {
    Print-Compliant "Minimum password length is $MinPwdLen" "164.312(d)"
} elseif ($MinPwdLen -match '\d+' -and [int]$Matches[0] -ge 8) {
    Print-Review "Minimum password length is $MinPwdLen" "164.312(d)" "HIPAA recommends 12+ characters; current setting meets minimum"
} else {
    Print-NonCompliant "Minimum password length is $MinPwdLen" "164.312(d)" "Weak passwords allowed" "Set: net accounts /minpwlen:12"
}

# Password age
if ($MaxPwdAge -match '(\d+)' -and [int]$Matches[1] -le 90 -and [int]$Matches[1] -gt 0) {
    Print-Compliant "Maximum password age: $MaxPwdAge" "164.312(d)"
} elseif ($MaxPwdAge -match "Unlimited|Never") {
    Print-NonCompliant "Passwords never expire" "164.312(d)" "No password rotation enforced" "Set: net accounts /maxpwage:90"
} else {
    Print-Review "Maximum password age: $MaxPwdAge" "164.312(d)" "Verify password rotation meets organizational policy"
}

# Account lockout
if ($LockoutThreshold -match '(\d+)' -and [int]$Matches[1] -gt 0 -and [int]$Matches[1] -le 5) {
    Print-Compliant "Account lockout threshold: $LockoutThreshold" "164.312(d)"
} elseif ($LockoutThreshold -match "Never") {
    Print-NonCompliant "No account lockout threshold" "164.312(d)" "Unlimited login attempts allowed — brute force risk" "Set: net accounts /lockoutthreshold:5"
} else {
    Print-Review "Account lockout threshold: $LockoutThreshold" "164.312(d)" "Consider reducing to 5 attempts or fewer"
}

# Check for Windows Hello / MFA
Write-Host "--- Multi-Factor Authentication ---"
$WHFBEnabled = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork" -Name "Enabled" -ErrorAction SilentlyContinue).Enabled
if ($WHFBEnabled -eq 1) {
    Print-Compliant "Windows Hello for Business is enabled" "164.312(d)"
} else {
    Print-Review "Windows Hello for Business not detected via policy" "164.312(d)" "Implement MFA for all ePHI access (Windows Hello, smart cards, or third-party MFA)"
}

# Check credential guard
$CredGuard = (Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard -ErrorAction SilentlyContinue)
if ($CredGuard -and $CredGuard.SecurityServicesRunning -contains 1) {
    Print-Compliant "Credential Guard is running" "164.312(d)"
} else {
    Print-Review "Credential Guard status unknown or not running" "164.312(d)" "Enable Credential Guard to protect authentication credentials"
}

# ============================================================
# 164.312(e)(1) - TRANSMISSION SECURITY
# ============================================================
Write-Host "================================================================"
Write-Host "  164.312(e)(1) - TRANSMISSION SECURITY"
Write-Host "  Standard: Guard against unauthorized access to ePHI"
Write-Host "  being transmitted over electronic communications"
Write-Host "================================================================"
Write-Host ""

# Check TLS configuration
Write-Host "--- TLS/SSL Protocol Configuration ---"
$Protocols = @{
    "SSL 2.0" = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 2.0\Server"
    "SSL 3.0" = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server"
    "TLS 1.0" = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.0\Server"
    "TLS 1.1" = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.1\Server"
    "TLS 1.2" = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2\Server"
    "TLS 1.3" = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.3\Server"
}

foreach ($proto in $Protocols.GetEnumerator()) {
    $regPath = $proto.Value
    $enabled = (Get-ItemProperty -Path $regPath -Name "Enabled" -ErrorAction SilentlyContinue).Enabled
    $disabled = (Get-ItemProperty -Path $regPath -Name "DisabledByDefault" -ErrorAction SilentlyContinue).DisabledByDefault

    if ($proto.Key -match "SSL|TLS 1\.0|TLS 1\.1") {
        if ($enabled -eq 0 -or $disabled -eq 1) {
            Print-Compliant "$($proto.Key) is disabled" "164.312(e)(2)(ii)"
        } else {
            Print-NonCompliant "$($proto.Key) may be enabled" "164.312(e)(2)(ii)" "Deprecated protocol with known vulnerabilities" "Disable via registry at $regPath"
        }
    } else {
        if ($enabled -eq 0) {
            Print-NonCompliant "$($proto.Key) appears disabled" "164.312(e)(2)(ii)" "Modern TLS should be enabled" "Enable $($proto.Key) for secure communications"
        } else {
            Print-Compliant "$($proto.Key) is available" "164.312(e)(2)(ii)"
        }
    }
}

# Check Windows Firewall
Write-Host "--- Firewall Configuration ---"
$FWProfiles = Get-NetFirewallProfile
foreach ($profile in $FWProfiles) {
    if ($profile.Enabled) {
        Print-Compliant "Firewall profile '$($profile.Name)' is enabled" "164.312(e)(1)"
    } else {
        Print-NonCompliant "Firewall profile '$($profile.Name)' is DISABLED" "164.312(e)(1)" "Network traffic is unfiltered" "Enable: Set-NetFirewallProfile -Profile $($profile.Name) -Enabled True"
    }
}

# Check SMB encryption
Write-Host "--- SMB Encryption ---"
try {
    $SMBConfig = Get-SmbServerConfiguration
    if ($SMBConfig.EncryptData) {
        Print-Compliant "SMB encryption is enabled" "164.312(e)(2)(ii)"
    } else {
        Print-NonCompliant "SMB encryption is not enabled" "164.312(e)(2)(ii)" "File shares may transmit ePHI unencrypted" "Enable: Set-SmbServerConfiguration -EncryptData `$true -Force"
    }
    if ($SMBConfig.EnableSMB1Protocol) {
        Print-NonCompliant "SMBv1 is enabled" "164.312(e)(2)(ii)" "SMBv1 has critical vulnerabilities (EternalBlue)" "Disable: Set-SmbServerConfiguration -EnableSMB1Protocol `$false"
    } else {
        Print-Compliant "SMBv1 is disabled" "164.312(e)(2)(ii)"
    }
} catch {
    Print-Review "Unable to check SMB configuration" "164.312(e)(2)(ii)" "Verify SMB encryption settings manually"
}

# Check for IPsec policies
Write-Host "--- IPsec / VPN ---"
$IPsecRules = Get-NetIPsecRule -ErrorAction SilentlyContinue
if ($IPsecRules) {
    Print-Compliant "IPsec rules are configured ($($IPsecRules.Count) rules)" "164.312(e)(1)"
} else {
    Print-Review "No IPsec rules configured" "164.312(e)(1)" "Verify VPN or other encrypted tunnels protect remote ePHI access"
}

# Check RDP encryption level
$RDPEncryption = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "MinEncryptionLevel" -ErrorAction SilentlyContinue).MinEncryptionLevel
if ($RDPEncryption -ge 3) {
    Print-Compliant "RDP encryption level is High ($RDPEncryption)" "164.312(e)(2)(ii)"
} elseif ($RDPEncryption) {
    Print-NonCompliant "RDP encryption level is $RDPEncryption (should be 3+)" "164.312(e)(2)(ii)" "Low RDP encryption" "Set High encryption via Group Policy or registry"
} else {
    Print-Review "RDP encryption level not explicitly set" "164.312(e)(2)(ii)" "Verify RDP uses high encryption"
}

# ============================================================
# 164.310 - PHYSICAL SAFEGUARDS (System-level)
# ============================================================
Write-Host "================================================================"
Write-Host "  164.310 - PHYSICAL SAFEGUARDS (System-level)"
Write-Host "================================================================"
Write-Host ""

# Check USB storage policy
Write-Host "--- Removable Storage Policy ---"
$USBPolicy = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices" -Name "Deny_All" -ErrorAction SilentlyContinue).Deny_All
$USBWritePolicy = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" -Name "Deny_Write" -ErrorAction SilentlyContinue).Deny_Write
if ($USBPolicy -eq 1) {
    Print-Compliant "Removable storage access is blocked by policy" "164.310(d)(1)"
} elseif ($USBWritePolicy -eq 1) {
    Print-Compliant "Removable storage write access is blocked" "164.310(d)(1)"
} else {
    Print-NonCompliant "Removable storage is not restricted" "164.310(d)(1)" "Data exfiltration risk via USB/removable media" "Block via Group Policy: Computer Config > Admin Templates > System > Removable Storage Access"
}

# Check auto-play
$AutoPlay = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -ErrorAction SilentlyContinue).NoDriveTypeAutoRun
if ($AutoPlay -eq 255) {
    Print-Compliant "AutoPlay is disabled for all drives" "164.310(d)(1)"
} else {
    Print-NonCompliant "AutoPlay may be enabled" "164.310(d)(1)" "Auto-executing removable media is a malware risk" "Disable: Set NoDriveTypeAutoRun to 255 via Group Policy"
}

# ============================================================
# 164.308 - ADMINISTRATIVE SAFEGUARDS (System-level)
# ============================================================
Write-Host "================================================================"
Write-Host "  164.308 - ADMINISTRATIVE SAFEGUARDS (System-level)"
Write-Host "================================================================"
Write-Host ""

# 164.308(a)(5)(ii)(C) - Login Monitoring
Write-Host "--- 164.308(a)(5)(ii)(C) - Login Monitoring ---"
try {
    $FailedLogins = Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4625} -MaxEvents 50 -ErrorAction Stop
    Write-Host "  Recent failed login attempts: $($FailedLogins.Count)"
    $FailedLogins | Select-Object -First 10 | ForEach-Object {
        Write-Host "    $($_.TimeCreated) - Event 4625"
    }
    Write-Host ""
    if ($FailedLogins.Count -ge 50) {
        Print-NonCompliant "High volume of failed login attempts" "164.308(a)(5)(ii)(C)" "$($FailedLogins.Count)+ failed logins detected" "Investigate failed login sources and tighten lockout policy"
    } else {
        Print-Compliant "Login monitoring is functional (Security log events present)" "164.308(a)(5)(ii)(C)"
    }
} catch {
    Print-Review "Unable to query failed login events" "164.308(a)(5)(ii)(C)" "Verify Security event log is accessible and logging"
}

# Check Windows Defender Antivirus
Write-Host "--- 164.308(a)(5)(ii)(B) - Malware Protection ---"
try {
    $Defender = Get-MpComputerStatus -ErrorAction Stop
    if ($Defender.AntivirusEnabled -and $Defender.RealTimeProtectionEnabled) {
        Print-Compliant "Windows Defender antivirus and real-time protection active" "164.308(a)(5)(ii)(B)"
        $SigAge = $Defender.AntivirusSignatureAge
        if ($SigAge -gt 7) {
            Print-NonCompliant "Antivirus signatures are $SigAge days old" "164.308(a)(5)(ii)(B)" "Outdated malware definitions" "Update: Update-MpSignature"
        } else {
            Print-Compliant "Antivirus signatures are current ($SigAge day(s) old)" "164.308(a)(5)(ii)(B)"
        }
    } else {
        Print-NonCompliant "Windows Defender protection is incomplete" "164.308(a)(5)(ii)(B)" "AV or real-time protection is disabled" "Enable all protection features in Windows Security"
    }
} catch {
    Print-Review "Unable to verify antivirus status" "164.308(a)(5)(ii)(B)" "Confirm endpoint protection is installed and active"
}

# 164.308(a)(7) - Contingency Plan
Write-Host "--- 164.308(a)(7) - Contingency Plan (Backup) ---"

# Check Volume Shadow Copy
$VSS = Get-CimInstance Win32_ShadowCopy -ErrorAction SilentlyContinue
if ($VSS) {
    Write-Host "  Volume Shadow Copies found: $($VSS.Count)"
    Print-Compliant "Volume Shadow Copies are configured" "164.308(a)(7)"
} else {
    Print-NonCompliant "No Volume Shadow Copies found" "164.308(a)(7)" "No local backup snapshots" "Enable Volume Shadow Copies for data drives"
}

# Check Windows Backup
$BackupStatus = Get-WBSummary -ErrorAction SilentlyContinue
if ($BackupStatus) {
    Write-Host "  Last backup: $($BackupStatus.LastSuccessfulBackupTime)"
    $BackupAge = (New-TimeSpan -Start $BackupStatus.LastSuccessfulBackupTime -End (Get-Date)).Days
    if ($BackupAge -le 1) {
        Print-Compliant "Windows Backup ran within last 24 hours" "164.308(a)(7)"
    } else {
        Print-NonCompliant "Last backup was $BackupAge days ago" "164.308(a)(7)" "Backups may not be current" "Verify backup schedule and run backup"
    }
} else {
    Print-Review "Windows Server Backup status not available" "164.308(a)(7)" "Verify backup solution is in place for ePHI data"
}

# ============================================================
# ADDITIONAL CHECKS
# ============================================================
Write-Host "================================================================"
Write-Host "  ADDITIONAL TECHNICAL SAFEGUARD CHECKS"
Write-Host "================================================================"
Write-Host ""

# Check UAC
$UACEnabled = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue).EnableLUA
if ($UACEnabled -eq 1) {
    Print-Compliant "User Account Control (UAC) is enabled" "164.312(a)(1)"
} else {
    Print-NonCompliant "User Account Control (UAC) is DISABLED" "164.312(a)(1)" "Elevated actions not controlled" "Enable UAC via registry or Group Policy"
}

# Check NTP synchronization
Write-Host "--- Time Synchronization ---"
$W32Time = Get-Service W32Time -ErrorAction SilentlyContinue
if ($W32Time -and $W32Time.Status -eq "Running") {
    Print-Compliant "Windows Time service is running (NTP sync)" "164.312(b)"
} else {
    Print-NonCompliant "Windows Time service is not running" "164.312(b)" "Audit timestamps may be inaccurate" "Start: Start-Service W32Time"
}

# Check PowerShell logging
$ScriptBlockLogging = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -ErrorAction SilentlyContinue).EnableScriptBlockLogging
if ($ScriptBlockLogging -eq 1) {
    Print-Compliant "PowerShell Script Block Logging is enabled" "164.312(b)"
} else {
    Print-NonCompliant "PowerShell Script Block Logging not enabled" "164.312(b)" "PowerShell commands not being logged" "Enable via Group Policy for forensic audit trail"
}

# Check login banner
$LegalNotice = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "legalnoticecaption" -ErrorAction SilentlyContinue).legalnoticecaption
$LegalText = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "legalnoticetext" -ErrorAction SilentlyContinue).legalnoticetext
if ($LegalNotice -or $LegalText) {
    Print-Compliant "Login legal notice/banner is configured" "164.312(a)(1)"
    Write-Host "  Caption: $LegalNotice"
    Write-Host ""
} else {
    Print-NonCompliant "No login banner/legal notice configured" "164.312(a)(1)" "No warning about authorized use" "Configure via Group Policy: Security Settings > Local Policies > Security Options"
}

# ============================================================
# §164.308(a)(1) - RISK ANALYSIS & RISK MANAGEMENT
# ============================================================
Write-Host "================================================================"
Write-Host "  §164.308(a)(1) - RISK ANALYSIS & RISK MANAGEMENT"
Write-Host "  Standard: Conduct accurate and thorough assessment of"
Write-Host "  potential risks and vulnerabilities to ePHI"
Write-Host "================================================================"
Write-Host ""

# Check for vulnerability scanning tools
Write-Host "--- Risk Analysis Tools ---"
$VulnToolsFound = $false
$scanners = @(
    @{Name="Windows Defender"; Check={ (Get-MpComputerStatus -ErrorAction SilentlyContinue) -ne $null }},
    @{Name="Nessus"; Check={ Get-Service -Name "Tenable Nessus" -ErrorAction SilentlyContinue }},
    @{Name="Qualys"; Check={ Get-Service -Name "QualysAgent" -ErrorAction SilentlyContinue }},
    @{Name="Rapid7"; Check={ Get-Service -Name "ir_agent" -ErrorAction SilentlyContinue }},
    @{Name="OpenVAS"; Check={ Get-Command openvas -ErrorAction SilentlyContinue }}
)
foreach ($scanner in $scanners) {
    try {
        if (& $scanner.Check) {
            $VulnToolsFound = $true
            Print-Compliant "Vulnerability scanning tool available: $($scanner.Name)" "§164.308(a)(1)(ii)(A)"
        }
    } catch {}
}
if (-not $VulnToolsFound) {
    Print-NonCompliant "No vulnerability scanning tools detected" "§164.308(a)(1)(ii)(A)" "Cannot perform automated risk assessments" "Install vulnerability scanning tools (Nessus, Qualys, Defender)"
}

# Check EDR/endpoint security
Write-Host "--- Endpoint Protection (Risk Mitigation) ---"
$Global:EdrFound = $false
$Global:EdrProducts = @()
$edrServices = @(
    @{Name="CrowdStrike Falcon"; Service="CSFalconService"},
    @{Name="SentinelOne"; Service="SentinelAgent"},
    @{Name="Carbon Black"; Service="CbDefense"},
    @{Name="Microsoft Defender for Endpoint"; Service="Sense"},
    @{Name="Sophos"; Service="Sophos Endpoint Defense Service"},
    @{Name="ESET"; Service="ekrn"},
    @{Name="Trend Micro"; Service="ds_agent"},
    @{Name="Cylance"; Service="CylanceSvc"},
    @{Name="Wazuh"; Service="WazuhSvc"},
    @{Name="Palo Alto Cortex XDR"; Service="CortexXDR"}
)
foreach ($edr in $edrServices) {
    $svc = Get-Service -Name $edr.Service -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        $Global:EdrFound = $true
        $Global:EdrProducts += $edr.Name
        Print-Compliant "EDR active: $($edr.Name)" "§164.308(a)(1)(ii)(B)"
    }
}
if (-not $Global:EdrFound) {
    Print-NonCompliant "No EDR/endpoint protection detected" "§164.308(a)(1)(ii)(B)" "Endpoints not protected against advanced threats" "Deploy EDR solution (CrowdStrike, SentinelOne, Defender for Endpoint)"
}

# ============================================================
# §164.308(a)(6) - SECURITY INCIDENT PROCEDURES
# ============================================================
Write-Host "================================================================"
Write-Host "  §164.308(a)(6) - SECURITY INCIDENT PROCEDURES"
Write-Host "  Standard: Implement policies and procedures to address"
Write-Host "  security incidents"
Write-Host "================================================================"
Write-Host ""

# Check Windows Event Forwarding (WEF) for incident detection
Write-Host "--- Incident Detection & Response ---"
$wefService = Get-Service -Name "Wecsvc" -ErrorAction SilentlyContinue
if ($wefService -and $wefService.Status -eq "Running") {
    Print-Compliant "Windows Event Forwarding (WEF) is active" "§164.308(a)(6)(ii)"
} else {
    Print-Review "Windows Event Forwarding not configured" "§164.308(a)(6)(ii)" "WEF enables centralized incident detection across endpoints"
}

# Check for SIEM agents
$siemAgents = @("SplunkForwarder", "winlogbeat", "nxlog", "filebeat", "FluentdWinSvc", "DatadogAgent", "OSSECSvc")
$SiemFound = $false
foreach ($agent in $siemAgents) {
    $svc = Get-Service -Name $agent -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") {
        $SiemFound = $true
        Print-Compliant "SIEM agent running: $agent" "§164.308(a)(6)(ii)"
    }
}
if (-not $SiemFound) {
    Print-NonCompliant "No SIEM/log forwarding agent detected" "§164.308(a)(6)(ii)" "Cannot centralize incident detection" "Deploy SIEM agent (Splunk UF, Winlogbeat, Elastic Agent)"
}

# Check for IR plan documentation
Write-Host "--- Incident Response Plan ---"
$irPaths = @("$env:ProgramData", "$env:SystemDrive\Policies", "$env:USERPROFILE\Documents")
$irFound = $false
foreach ($path in $irPaths) {
    if (Test-Path $path) {
        $irDocs = Get-ChildItem -Path $path -Recurse -Include "*incident*response*", "*ir*plan*", "*security*incident*" -ErrorAction SilentlyContinue | Select-Object -First 3
        if ($irDocs) {
            $irFound = $true
            Print-Compliant "Incident response documentation found" "§164.308(a)(6)(i)"
            break
        }
    }
}
if (-not $irFound) {
    Print-NonCompliant "No incident response plan found on system" "§164.308(a)(6)(i)" "No IR documentation detected" "Develop and maintain an incident response plan accessible on managed systems"
}

# ============================================================
# §164.308(a)(8) - EVALUATION
# ============================================================
Write-Host "================================================================"
Write-Host "  §164.308(a)(8) - EVALUATION"
Write-Host "  Standard: Perform periodic technical and nontechnical"
Write-Host "  evaluation of security controls"
Write-Host "================================================================"
Write-Host ""

# Check Windows Update history for patch management evaluation
Write-Host "--- Patch Management Evaluation ---"
try {
    $lastUpdate = (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1).InstalledOn
    $daysSinceUpdate = (New-TimeSpan -Start $lastUpdate -End (Get-Date)).Days
    if ($daysSinceUpdate -le 30) {
        Print-Compliant "Last patch installed $daysSinceUpdate days ago" "§164.308(a)(8)"
    } elseif ($daysSinceUpdate -le 90) {
        Print-Review "Last patch installed $daysSinceUpdate days ago" "§164.308(a)(8)" "Consider more frequent patching schedule"
    } else {
        Print-NonCompliant "Last patch installed $daysSinceUpdate days ago" "§164.308(a)(8)" "System not receiving regular security updates" "Enable Windows Update and establish monthly patching schedule"
    }
} catch {
    Print-Review "Unable to determine patch status" "§164.308(a)(8)" "Verify Windows Update is configured and patches are applied regularly"
}

# Check for Group Policy refresh
Write-Host "--- Group Policy Evaluation ---"
try {
    $gpResult = gpresult /R 2>$null
    if ($gpResult) {
        Print-Compliant "Group Policy is applied to this system" "§164.308(a)(8)"
    }
} catch {
    Print-Review "Group Policy status" "§164.308(a)(8)" "Verify Group Policy is configured for security baselines"
}

# ============================================================
# §164.530(j) - DATA RETENTION & DISPOSAL
# ============================================================
Write-Host "================================================================"
Write-Host "  §164.530(j) - DATA RETENTION & DISPOSAL"
Write-Host "  Standard: Retain documentation for 6 years; implement"
Write-Host "  secure data disposal procedures"
Write-Host "================================================================"
Write-Host ""

# Check BitLocker for secure disposal capability
Write-Host "--- Secure Data Disposal ---"
$bitlockerStatus = Get-BitLockerVolume -ErrorAction SilentlyContinue
if ($bitlockerStatus) {
    $encryptedVols = $bitlockerStatus | Where-Object { $_.ProtectionStatus -eq "On" }
    if ($encryptedVols) {
        Print-Compliant "BitLocker encryption enables crypto-erase for secure disposal" "§164.530(j)"
    } else {
        Print-Review "BitLocker present but not all volumes encrypted" "§164.530(j)" "Enable BitLocker on all volumes for crypto-erase capability"
    }
} else {
    Print-Review "BitLocker status unavailable" "§164.530(j)" "Verify disk encryption is active for secure data disposal"
}

# Check for secure delete capability
$sdeleteExists = Get-Command sdelete -ErrorAction SilentlyContinue
if ($sdeleteExists) {
    Print-Compliant "SDelete secure deletion tool available" "§164.530(j)"
} else {
    Print-Review "SDelete not found" "§164.530(j)" "Install Sysinternals SDelete for secure file disposal"
}

# Check Recycle Bin auto-purge
$storageSense = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -ErrorAction SilentlyContinue
if ($storageSense -and $storageSense."08" -eq 1) {
    Print-Compliant "Storage Sense auto-purges deleted files" "§164.530(j)"
} else {
    Print-Review "Storage Sense auto-purge" "§164.530(j)" "Enable Storage Sense to automatically purge Recycle Bin contents"
}

# ============================================================
# SENSITIVE DATA SCAN & CLASSIFICATION
# ============================================================
Write-Host "================================================================"
Write-Host "  SENSITIVE DATA SCAN & CLASSIFICATION"
Write-Host "  Scanning for potential ePHI/PII in common locations"
Write-Host "================================================================"
Write-Host ""
Write-Host "  Note: Lightweight pattern-based scan - not exhaustive."
Write-Host ""

# SSN patterns
Write-Host "--- Social Security Number Patterns ---"
$ssnPaths = @("$env:USERPROFILE\Documents", "$env:USERPROFILE\Desktop", "$env:PUBLIC\Documents")
$ssnFilesFound = 0
foreach ($searchPath in $ssnPaths) {
    if (Test-Path $searchPath) {
        $files = Get-ChildItem -Path $searchPath -Include "*.csv","*.txt","*.xlsx","*.json","*.xml" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 50
        foreach ($file in $files) {
            try {
                $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -match "\b\d{3}-\d{2}-\d{4}\b") {
                    $ssnFilesFound++
                    if ($ssnFilesFound -le 5) {
                        Write-Host "    FOUND: $($file.FullName)" -ForegroundColor Red
                    }
                }
            } catch {}
        }
    }
}
if ($ssnFilesFound -gt 0) {
    Print-NonCompliant "Files with potential SSN patterns ($ssnFilesFound)" "§164.312(a)(1)" "ePHI/PII may be stored unprotected" "Encrypt, access-control, or remove files containing SSNs"
} else {
    Print-Compliant "No SSN patterns detected in common locations" "§164.312(a)(1)"
}

# Medical record indicators
Write-Host "--- Medical Record Number Indicators ---"
$mrnFilesFound = 0
foreach ($searchPath in $ssnPaths) {
    if (Test-Path $searchPath) {
        $files = Get-ChildItem -Path $searchPath -Include "*.csv","*.txt","*.json","*.xml" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 50
        foreach ($file in $files) {
            try {
                $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -match "MRN|medical.record|patient.id|health.record") {
                    $mrnFilesFound++
                }
            } catch {}
        }
    }
}
if ($mrnFilesFound -gt 0) {
    Print-NonCompliant "Files with potential medical record indicators ($mrnFilesFound)" "§164.312(a)(1)" "ePHI storage detected" "Apply access controls, encryption, and audit logging"
} else {
    Print-Compliant "No medical record indicators detected" "§164.312(a)(1)"
}

# Database files
Write-Host "--- Unencrypted Database Files ---"
$dbFiles = Get-ChildItem -Path @("$env:USERPROFILE", "$env:ProgramData") -Include "*.db","*.sqlite","*.sqlite3","*.mdb","*.accdb" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 15
if ($dbFiles) {
    Print-Review "Unencrypted database files found ($($dbFiles.Count))" "§164.312(a)(2)(iv)" "Verify databases do not contain ePHI, or are properly encrypted and access-controlled"
}

# ============================================================
# WORKFORCE SECURITY - §164.308(a)(3)
# ============================================================
Write-Host "================================================================"
Write-Host "  §164.308(a)(3) - WORKFORCE SECURITY"
Write-Host "  Standard: Implement procedures for authorization and"
Write-Host "  supervision of workforce members with ePHI access"
Write-Host "================================================================"
Write-Host ""

# Check for disabled/inactive accounts
Write-Host "--- Account Lifecycle ---"
try {
    $localUsers = Get-LocalUser -ErrorAction SilentlyContinue
    $disabledAccounts = $localUsers | Where-Object { $_.Enabled -eq $false }
    if ($disabledAccounts) {
        $count = ($disabledAccounts | Measure-Object).Count
        Print-Compliant "$count disabled account(s) properly locked" "§164.308(a)(3)(ii)(C)"
    }
    
    $neverLoggedIn = $localUsers | Where-Object { $_.Enabled -eq $true -and $null -eq $_.LastLogon }
    if ($neverLoggedIn) {
        $names = ($neverLoggedIn | ForEach-Object { $_.Name }) -join ", "
        Print-NonCompliant "Active accounts that never logged in: $names" "§164.308(a)(3)(ii)(C)" "Potentially orphaned accounts with system access" "Review and disable unnecessary accounts"
    } else {
        Print-Compliant "No orphaned active accounts detected" "§164.308(a)(3)(ii)(C)"
    }
} catch {
    Print-Review "Account lifecycle check" "§164.308(a)(3)(ii)(C)" "Unable to enumerate local accounts — verify in AD/domain management"
}

# Check for admin accounts
Write-Host "--- Administrative Access Control ---"
try {
    $adminGroup = Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue
    $adminCount = ($adminGroup | Measure-Object).Count
    if ($adminCount -le 3) {
        Print-Compliant "Administrative accounts limited ($adminCount)" "§164.308(a)(3)(ii)(A)"
    } else {
        Print-NonCompliant "Excessive admin accounts ($adminCount)" "§164.308(a)(3)(ii)(A)" "Too many accounts with full system access" "Reduce to minimum necessary admin accounts"
    }
} catch {
    Print-Review "Admin account enumeration" "§164.308(a)(3)(ii)(A)" "Verify admin account count manually"
}

# ============================================================
# CYBER INSURANCE & HIPAA ALIGNMENT
# ============================================================
Write-Host "================================================================"
Write-Host "  CYBER INSURANCE & HIPAA ALIGNMENT"
Write-Host "  Common cyber insurance requirements mapped to HIPAA controls"
Write-Host "================================================================"
Write-Host ""

$Global:CiPass = 0
$Global:CiFail = 0
$Global:CiReview = 0

function CI-Pass { param($msg); $Global:CiPass++; Write-Host "  [INSURABLE] $msg" -ForegroundColor Green; Write-Host "" }
function CI-Fail { param($msg, $impact); $Global:CiFail++; Write-Host "  [GAP] $msg" -ForegroundColor Red; Write-Host "    Insurance Impact: $impact"; Write-Host "" }
function CI-Review { param($msg, $note); $Global:CiReview++; Write-Host "  [VERIFY] $msg" -ForegroundColor Yellow; Write-Host "    Note: $note"; Write-Host "" }

Write-Host "--- MFA (Required by HIPAA §164.312(d) & most insurers) ---"
$mfaRegistry = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "legalnoticecaption" -ErrorAction SilentlyContinue
$wh4b = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\PassportForWork" -ErrorAction SilentlyContinue
$duoInstalled = Get-Service -Name "DuoAuthProxy" -ErrorAction SilentlyContinue
$okta = Get-Service -Name "OktaVerifyService" -ErrorAction SilentlyContinue
if ($wh4b -or $duoInstalled -or $okta) {
    CI-Pass "MFA configured - meets HIPAA authentication and insurer MFA requirements"
} else {
    CI-Fail "No MFA detected" "MFA is a prerequisite for most cyber insurance policies; also required by HIPAA §164.312(d)"
}

Write-Host "--- EDR (Required by most insurers; supports HIPAA §164.308(a)(5)(ii)(B)) ---"
if ($Global:EdrFound) {
    CI-Pass "EDR deployed ($($Global:EdrProducts -join ', ')) - meets insurer endpoint protection requirements"
} else {
    CI-Fail "No EDR solution" "EDR is required by most insurers; strengthens HIPAA malware protection"
}

Write-Host "--- Email Security (Insurers require DMARC) ---"
$domain = (Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue).Domain
if ($domain -and $domain -ne "WORKGROUP") {
    try {
        $dmarc = Resolve-DnsName -Name "_dmarc.$domain" -Type TXT -ErrorAction SilentlyContinue
        if ($dmarc -and ($dmarc.Strings -match "p=reject|p=quarantine")) {
            CI-Pass "DMARC enforcement active - meets insurer email security requirements"
        } else {
            CI-Fail "DMARC not enforcing" "Most insurers require DMARC at p=quarantine or p=reject"
        }
    } catch {
        CI-Review "Email security (DMARC)" "Could not resolve DMARC record - verify manually"
    }
} else {
    CI-Review "Email security (DMARC)" "System not domain-joined - verify email authentication manually"
}

Write-Host "--- Backup (Required by HIPAA §164.308(a)(7) & insurers) ---"
$backupFound = $false
$wbadmin = Get-Command wbadmin -ErrorAction SilentlyContinue
$vss = (vssadmin list shadows 2>$null) -match "Shadow Copy"
$backupServices = @("wbengine", "VeeamBackupSvc", "BackupExecAgentBrowser", "AcronisCyberProtectionService")
foreach ($bsvc in $backupServices) {
    $svc = Get-Service -Name $bsvc -ErrorAction SilentlyContinue
    if ($svc -and $svc.Status -eq "Running") { $backupFound = $true }
}
if ($vss) { $backupFound = $true }
if ($backupFound) {
    CI-Pass "Backup solutions deployed - meets contingency plan and insurer requirements"
} else {
    CI-Fail "No backup solutions detected" "Insurers require tested, encrypted, offline/immutable backups; HIPAA §164.308(a)(7) requires contingency plan"
}

Write-Host "--- Encryption (Required by HIPAA §164.312(a)(2)(iv) & insurers) ---"
$blVolumes = Get-BitLockerVolume -ErrorAction SilentlyContinue
$encryptedVols = $blVolumes | Where-Object { $_.ProtectionStatus -eq "On" }
if ($encryptedVols) {
    CI-Pass "Disk encryption (BitLocker) active - meets HIPAA and insurer encryption requirements"
} else {
    CI-Fail "No disk encryption" "HIPAA requires encryption for ePHI; insurers require encryption at rest on all endpoints"
}

Write-Host "--- Security Logging (Required by HIPAA §164.312(b) & insurers) ---"
if ($SiemFound) {
    CI-Pass "Centralized logging/SIEM - meets audit control and insurer monitoring requirements"
} else {
    CI-Fail "No SIEM/centralized logging" "Both HIPAA §164.312(b) and insurers require centralized security monitoring"
}

Write-Host ""
Write-Host "  --- Cyber Insurance / HIPAA Alignment Summary ---"
Write-Host "  Requirements Met:       $Global:CiPass"
Write-Host "  Gaps Found:             $Global:CiFail"
Write-Host "  Needs Verification:     $Global:CiReview"
Write-Host ""

# ============================================================
# SUMMARY
# ============================================================
Write-Host ""
Write-Host "========================================================================"
Write-Host "  HIPAA COMPLIANCE ASSESSMENT SUMMARY"
Write-Host "========================================================================"
Write-Host ""
Write-Host "  Compliant Controls:     $Global:Compliant"
Write-Host "  Non-Compliant Controls: $Global:NonCompliant"
Write-Host "  Needs Review:           $Global:NeedsReview"
Write-Host "  Total Controls Checked: $($Global:Compliant + $Global:NonCompliant + $Global:NeedsReview)"
Write-Host ""
Write-Host "  Cyber Insurance Alignment: $Global:CiPass/$($Global:CiPass + $Global:CiFail + $Global:CiReview) requirements met"
Write-Host ""
if ($Global:NonCompliant -gt 0) {
    Write-Host "  STATUS: NON-COMPLIANT - $($Global:NonCompliant) control(s) require remediation" -ForegroundColor Red
    Write-Host ""
    Write-Host "  IMPORTANT: This scan covers technical safeguards only."
    Write-Host "  HIPAA compliance also requires Administrative and Physical"
    Write-Host "  Safeguards, as well as organizational policies, BAAs, risk"
    Write-Host "  analyses, and workforce training."
} elseif ($Global:NeedsReview -gt 0) {
    Write-Host "  STATUS: REVIEW REQUIRED - $($Global:NeedsReview) control(s) need manual verification" -ForegroundColor Yellow
} else {
    Write-Host "  STATUS: ALL TECHNICAL CONTROLS COMPLIANT" -ForegroundColor Green
}
Write-Host ""
Write-Host "  DISCLAIMER: This automated scan is not a substitute for a"
Write-Host "  comprehensive HIPAA risk analysis. Consult a qualified HIPAA"
Write-Host "  compliance professional for a complete assessment."
Write-Host ""
Write-Host "  Report generated: $ReportDate"
Write-Host "  Host: $Hostname"
Write-Host "========================================================================"
