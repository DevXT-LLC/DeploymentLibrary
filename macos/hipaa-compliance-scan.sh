#!/bin/bash
# HIPAA Compliance Scan (macOS)
# Assesses system configuration against HIPAA Security Rule requirements
# Covers Administrative, Physical, and Technical Safeguards
# Reference: 45 CFR Part 164 - Security and Privacy

set -euo pipefail

REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
OS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "Unknown")

echo "========================================================================"
echo "  HIPAA COMPLIANCE ASSESSMENT REPORT"
echo "  Host: $HOSTNAME"
echo "  Date: $REPORT_DATE"
echo "  OS: macOS $OS_VERSION"
echo "  Framework: HIPAA Security Rule (45 CFR 164.312)"
echo "========================================================================"
echo ""

COMPLIANT=0
NON_COMPLIANT=0
NEEDS_REVIEW=0

print_compliant() {
    COMPLIANT=$((COMPLIANT + 1))
    echo "[COMPLIANT] $1"
    echo "  HIPAA Ref: $2"
    echo ""
}

print_non_compliant() {
    NON_COMPLIANT=$((NON_COMPLIANT + 1))
    echo "[NON-COMPLIANT] $1"
    echo "  HIPAA Ref: $2"
    echo "  Finding: $3"
    echo "  Required Action: $4"
    echo ""
}

print_review() {
    NEEDS_REVIEW=$((NEEDS_REVIEW + 1))
    echo "[NEEDS REVIEW] $1"
    echo "  HIPAA Ref: $2"
    echo "  Details: $3"
    echo ""
}

# ============================================================
# §164.312(a)(1) - ACCESS CONTROL
# ============================================================
echo "================================================================"
echo "  §164.312(a)(1) - ACCESS CONTROL"
echo "  Standard: Implement technical policies and procedures for"
echo "  electronic information systems that maintain ePHI"
echo "================================================================"
echo ""

# (i) Unique User Identification (Required)
echo "--- §164.312(a)(2)(i) - Unique User Identification [REQUIRED] ---"
echo ""

# List all user accounts
echo "  Local user accounts:"
dscl . -list /Users UniqueID 2>/dev/null | awk '$2 >= 500 { printf "    %-20s UID: %s\n", $1, $2 }' || true
echo ""

# Check for duplicate UIDs
DUP_UIDS=$(dscl . -list /Users UniqueID 2>/dev/null | awk '{print $2}' | sort | uniq -d || true)
if [ -n "$DUP_UIDS" ]; then
    print_non_compliant "Duplicate UIDs detected" "§164.312(a)(2)(i)" "UIDs: $DUP_UIDS" "Ensure each user has a unique UID"
else
    print_compliant "All users have unique UIDs" "§164.312(a)(2)(i)"
fi

# Check for guest account
GUEST_ENABLED=$(defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>/dev/null || echo "0")
if [ "$GUEST_ENABLED" = "1" ]; then
    print_non_compliant "Guest account is enabled" "§164.312(a)(2)(i)" "Unauthenticated access possible" "Disable in System Preferences > Users & Groups"
else
    print_compliant "Guest account is disabled" "§164.312(a)(2)(i)"
fi

# Check admin users
ADMIN_USERS=$(dscl . -read /Groups/admin GroupMembership 2>/dev/null | sed 's/GroupMembership: //' || true)
ADMIN_COUNT=$(echo "$ADMIN_USERS" | wc -w | tr -d ' ')
echo "  Admin users ($ADMIN_COUNT): $ADMIN_USERS"
echo ""
if [ "$ADMIN_COUNT" -gt 3 ]; then
    print_non_compliant "Excessive admin users ($ADMIN_COUNT)" "§164.312(a)(2)(i)" "Too many administrative accounts" "Reduce admin membership — principle of least privilege"
else
    print_compliant "Admin user count is reasonable ($ADMIN_COUNT)" "§164.312(a)(2)(i)"
fi

# (iii) Automatic Logoff (Addressable)
echo "--- §164.312(a)(2)(iii) - Automatic Logoff [ADDRESSABLE] ---"
echo ""

# Check screen saver lock
SS_PASSWORD=$(defaults read com.apple.screensaver askForPassword 2>/dev/null || echo "unknown")
SS_DELAY=$(defaults read com.apple.screensaver askForPasswordDelay 2>/dev/null || echo "unknown")
SS_IDLE=$(defaults -currentHost read com.apple.screensaver idleTime 2>/dev/null || echo "unknown")

echo "  Screen saver password required: $SS_PASSWORD"
echo "  Password delay (seconds): $SS_DELAY"
echo "  Idle time before screen saver: $SS_IDLE"
echo ""

if [ "$SS_PASSWORD" = "1" ]; then
    if [ "$SS_DELAY" != "unknown" ] && [ "$SS_DELAY" -le 5 ] 2>/dev/null; then
        print_compliant "Screen lock with immediate password is configured" "§164.312(a)(2)(iii)"
    elif [ "$SS_DELAY" != "unknown" ] && [ "$SS_DELAY" -le 60 ] 2>/dev/null; then
        print_compliant "Screen lock with $SS_DELAY second password delay" "§164.312(a)(2)(iii)"
    else
        print_non_compliant "Screen lock password delay is too long ($SS_DELAY sec)" "§164.312(a)(2)(iii)" "Delay allows unauthorized access" "Set: defaults write com.apple.screensaver askForPasswordDelay -int 5"
    fi
else
    print_non_compliant "Screen saver password is NOT required" "§164.312(a)(2)(iii)" "Unattended Mac can be accessed without password" "Enable: defaults write com.apple.screensaver askForPassword -int 1"
fi

# Check auto-login
AUTO_LOGIN=$(defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || echo "none")
if [ "$AUTO_LOGIN" != "none" ]; then
    print_non_compliant "Auto-login is enabled for: $AUTO_LOGIN" "§164.312(a)(2)(iii)" "System bypasses authentication on boot" "Disable in System Preferences > Users & Groups > Login Options"
else
    print_compliant "Auto-login is disabled" "§164.312(a)(2)(iii)"
fi

# Check SSH timeout
if [ -f /etc/ssh/sshd_config ]; then
    CLIENT_ALIVE=$(grep -i "^ClientAliveInterval\|^ClientAliveCountMax" /etc/ssh/sshd_config 2>/dev/null || true)
    if [ -n "$CLIENT_ALIVE" ]; then
        print_compliant "SSH session timeout is configured" "§164.312(a)(2)(iii)"
    else
        SSH_ENABLED=$(systemsetup -getremotelogin 2>/dev/null || true)
        if echo "$SSH_ENABLED" | grep -qi "On"; then
            print_non_compliant "SSH enabled without session timeout" "§164.312(a)(2)(iii)" "SSH sessions remain open indefinitely" "Set ClientAliveInterval 300 in /etc/ssh/sshd_config"
        fi
    fi
fi

# (iv) Encryption and Decryption (Addressable)
echo "--- §164.312(a)(2)(iv) - Encryption and Decryption [ADDRESSABLE] ---"
echo ""

# Check FileVault
FV_STATUS=$(fdesetup status 2>/dev/null || echo "unknown")
echo "  FileVault: $FV_STATUS"
echo ""
if echo "$FV_STATUS" | grep -qi "On"; then
    print_compliant "FileVault full-disk encryption is ON" "§164.312(a)(2)(iv)"
    
    # Check encryption type
    FV_TYPE=$(diskutil apfs list 2>/dev/null | grep -i "FileVault" | head -1 || true)
    if [ -n "$FV_TYPE" ]; then
        echo "  Encryption details: $FV_TYPE"
        echo ""
    fi
else
    print_non_compliant "FileVault disk encryption is OFF" "§164.312(a)(2)(iv)" "ePHI on disk is not encrypted" "Enable: sudo fdesetup enable"
fi

# Check for encrypted backups (Time Machine)
TM_ENCRYPTED=$(defaults read /Library/Preferences/com.apple.TimeMachine LastKnownEncryptionState 2>/dev/null || echo "unknown")
TM_DEST=$(tmutil destinationinfo 2>/dev/null | grep "Name" | head -1 || true)
if [ -n "$TM_DEST" ]; then
    echo "  Time Machine destination: $TM_DEST"
    if echo "$TM_ENCRYPTED" | grep -qi "Encrypted"; then
        print_compliant "Time Machine backups are encrypted" "§164.312(a)(2)(iv)"
    else
        print_non_compliant "Time Machine backups may not be encrypted" "§164.312(a)(2)(iv)" "Backup data containing ePHI should be encrypted" "Enable encrypted backups in Time Machine preferences"
    fi
else
    print_review "Time Machine backup configuration" "§164.312(a)(2)(iv)" "Verify backup encryption if Time Machine or other backup is in use"
fi

# ============================================================
# §164.312(b) - AUDIT CONTROLS
# ============================================================
echo "================================================================"
echo "  §164.312(b) - AUDIT CONTROLS"
echo "  Standard: Implement mechanisms to record and examine"
echo "  activity in systems containing or using ePHI"
echo "================================================================"
echo ""

# Check Unified Logging
echo "--- System Logging ---"
if command -v log &>/dev/null; then
    print_compliant "macOS Unified Logging system is available" "§164.312(b)"
    
    # Check log level
    LOG_CONFIG=$(log config --status 2>/dev/null | head -10 || true)
    if [ -n "$LOG_CONFIG" ]; then
        echo "  Log configuration:"
        echo "$LOG_CONFIG" | sed 's/^/    /'
        echo ""
    fi
else
    print_non_compliant "Unified Logging not available" "§164.312(b)" "Cannot verify logging framework" "Ensure macOS logging system is functional"
fi

# Check install.log for audit trail
if [ -f /var/log/install.log ]; then
    LOG_SIZE=$(du -h /var/log/install.log 2>/dev/null | awk '{print $1}')
    echo "  install.log size: $LOG_SIZE"
    print_compliant "Install log is present" "§164.312(b)"
else
    print_review "Install.log not found" "§164.312(b)" "Verify system maintains adequate installation audit trail"
fi

# Check if OpenBSM audit is enabled
echo "--- OpenBSM Audit ---"
if [ -f /etc/security/audit_control ]; then
    AUDIT_FLAGS=$(grep "^flags:" /etc/security/audit_control 2>/dev/null || true)
    echo "  Audit control flags: $AUDIT_FLAGS"
    echo ""
    if [ -n "$AUDIT_FLAGS" ]; then
        # Check for login/logout auditing
        if echo "$AUDIT_FLAGS" | grep -q "lo\|aa\|ad"; then
            print_compliant "OpenBSM audit logging includes authentication events" "§164.312(b)"
        else
            print_non_compliant "OpenBSM audit missing authentication flags" "§164.312(b)" "Login/logout not being audited" "Add 'lo' flag to /etc/security/audit_control"
        fi
    fi
else
    print_non_compliant "OpenBSM audit_control not found" "§164.312(b)" "System auditing may not be configured" "Configure /etc/security/audit_control"
fi

# Check audit log retention
echo "--- Log Retention ---"
if [ -f /etc/security/audit_control ]; then
    EXPIRE_AFTER=$(grep "^expire-after:" /etc/security/audit_control 2>/dev/null || true)
    echo "  Audit expiry: $EXPIRE_AFTER"
    print_review "Verify audit log retention meets HIPAA 6-year requirement" "§164.312(b)" "Current setting: $EXPIRE_AFTER — HIPAA requires 6 years"
fi

# Check for centralized logging
echo "--- Centralized Logging ---"
if [ -f /etc/syslog.conf ]; then
    REMOTE_SYSLOG=$(grep -v "^#" /etc/syslog.conf 2>/dev/null | grep "@" || true)
    if [ -n "$REMOTE_SYSLOG" ]; then
        print_compliant "Remote syslog forwarding is configured" "§164.312(b)"
    else
        print_review "No remote syslog forwarding detected" "§164.312(b)" "Consider forwarding logs to a central SIEM"
    fi
else
    print_review "No syslog.conf found" "§164.312(b)" "Consider centralized log collection for ePHI monitoring"
fi

# ============================================================
# §164.312(c)(1) - INTEGRITY
# ============================================================
echo "================================================================"
echo "  §164.312(c)(1) - INTEGRITY CONTROLS"
echo "  Standard: Protect ePHI from improper alteration"
echo "================================================================"
echo ""

# Check System Integrity Protection
SIP_STATUS=$(csrutil status 2>/dev/null || echo "unknown")
if echo "$SIP_STATUS" | grep -qi "enabled"; then
    print_compliant "System Integrity Protection (SIP) is enabled" "§164.312(c)(2)"
else
    print_non_compliant "System Integrity Protection is DISABLED" "§164.312(c)(2)" "System files can be modified" "Re-enable from Recovery Mode: csrutil enable"
fi

# Check Gatekeeper
GK_STATUS=$(spctl --status 2>/dev/null || echo "unknown")
if echo "$GK_STATUS" | grep -qi "enabled"; then
    print_compliant "Gatekeeper is enabled" "§164.312(c)(2)"
else
    print_non_compliant "Gatekeeper is DISABLED" "§164.312(c)(2)" "Unsigned apps can be installed" "Enable: sudo spctl --master-enable"
fi

# Check XProtect
echo "--- XProtect (Built-in Malware Protection) ---"
XPROTECT_V=$(defaults read /System/Library/CoreServices/XProtect.bundle/Contents/Info.plist CFBundleShortVersionString 2>/dev/null || echo "unknown")
echo "  XProtect version: $XPROTECT_V"
echo ""
if [ "$XPROTECT_V" != "unknown" ]; then
    print_compliant "XProtect malware protection is present (v$XPROTECT_V)" "§164.312(c)(2)"
else
    print_review "XProtect version could not be determined" "§164.312(c)(2)" "Verify malware protection is active"
fi

# Check for file integrity monitoring tools
echo "--- File Integrity Monitoring ---"
FIM_FOUND=false
for tool in aide tripwire osquery; do
    if command -v "$tool" &>/dev/null; then
        FIM_FOUND=true
        print_compliant "File integrity monitoring tool installed: $tool" "§164.312(c)(2)"
    fi
done
if [ "$FIM_FOUND" = false ]; then
    print_non_compliant "No file integrity monitoring tool detected" "§164.312(c)(2)" "Cannot verify ePHI files haven't been tampered with" "Install osquery or AIDE for file integrity monitoring"
fi

# ============================================================
# §164.312(d) - PERSON OR ENTITY AUTHENTICATION
# ============================================================
echo "================================================================"
echo "  §164.312(d) - PERSON OR ENTITY AUTHENTICATION"
echo "  Standard: Verify identity of persons seeking ePHI access"
echo "================================================================"
echo ""

# Check password policy
echo "--- Password Policy ---"
PW_POLICY=$(pwpolicy -getaccountpolicies 2>/dev/null || true)

# Check password content requirements
if [ -n "$PW_POLICY" ] && echo "$PW_POLICY" | grep -qi "policyContent\|minChars\|requiresAlpha"; then
    print_compliant "Password policy is configured" "§164.312(d)"
    
    # Try to extract details
    MIN_LEN=$(echo "$PW_POLICY" | grep -o "minChars[^<]*" | head -1 || true)
    echo "  Policy details: $MIN_LEN"
    echo ""
else
    print_non_compliant "No custom password policy configured" "§164.312(d)" "Default password requirements may be insufficient" "Configure password policy via Profiles or pwpolicy command"
fi

# Check for Touch ID / biometric authentication
echo "--- Biometric / Multi-Factor Authentication ---"
BIOMETRIC=$(bioutil -r 2>/dev/null | grep -c "fingerprint" || echo "0")
if [ "$BIOMETRIC" -gt 0 ]; then
    print_compliant "Touch ID biometric authentication is enrolled" "§164.312(d)"
else
    print_review "Touch ID not enrolled or not available" "§164.312(d)" "Consider enabling biometric MFA for ePHI access"
fi

# Check for smart card / PIV support
SMARTCARD_REQUIRED=$(defaults read /Library/Preferences/com.apple.security.smartcard enforceSmartCard 2>/dev/null || echo "0")
if [ "$SMARTCARD_REQUIRED" = "1" ]; then
    print_compliant "Smart card authentication is enforced" "§164.312(d)"
else
    print_review "Smart card authentication not enforced" "§164.312(d)" "Consider smart card/PIV for high-security ePHI environments"
fi

# Check Keychain auto-lock
KEYCHAIN_TIMEOUT=$(security show-keychain-info login.keychain 2>&1 | grep "timeout" || true)
echo "  Keychain: $KEYCHAIN_TIMEOUT"
echo ""
if [ -n "$KEYCHAIN_TIMEOUT" ]; then
    print_compliant "Keychain auto-lock is configured" "§164.312(d)"
else
    print_review "Keychain auto-lock settings could not be verified" "§164.312(d)" "Verify Keychain locks after inactivity"
fi

# Check password aging / Account policies
echo "--- Account Security ---"
# Check if root is disabled
ROOT_STATUS=$(dscl . -read /Users/root AuthenticationAuthority 2>/dev/null || echo "disabled")
if echo "$ROOT_STATUS" | grep -qi "DisabledUser\|No such key"; then
    print_compliant "Root user account is disabled" "§164.312(d)"
else
    print_non_compliant "Root user account may be enabled" "§164.312(d)" "Direct root login possible" "Disable: dsenableroot -d"
fi

# ============================================================
# §164.312(e)(1) - TRANSMISSION SECURITY
# ============================================================
echo "================================================================"
echo "  §164.312(e)(1) - TRANSMISSION SECURITY"
echo "  Standard: Guard against unauthorized access to ePHI"
echo "  being transmitted over electronic communications"
echo "================================================================"
echo ""

# Check Application Firewall
echo "--- Firewall ---"
FW_STATE=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null || echo "unknown")
if echo "$FW_STATE" | grep -qi "enabled"; then
    print_compliant "Application Firewall is enabled" "§164.312(e)(1)"
else
    print_non_compliant "Application Firewall is DISABLED" "§164.312(e)(1)" "Network traffic is not being filtered" "Enable: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on"
fi

# Check stealth mode
STEALTH=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null || echo "unknown")
if echo "$STEALTH" | grep -qi "enabled"; then
    print_compliant "Firewall stealth mode is enabled" "§164.312(e)(1)"
else
    print_non_compliant "Firewall stealth mode is disabled" "§164.312(e)(1)" "System responds to probe packets" "Enable: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on"
fi

# Check for block all incoming
BLOCK_ALL=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getblockall 2>/dev/null || echo "unknown")
echo "  Block all incoming: $BLOCK_ALL"
echo ""

# Check Wi-Fi security
echo "--- Wi-Fi Security ---"
WIFI_INFO=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null || true)
if [ -n "$WIFI_INFO" ]; then
    WIFI_SEC=$(echo "$WIFI_INFO" | grep "link auth" | awk '{print $NF}' || true)
    WIFI_SSID=$(echo "$WIFI_INFO" | grep " SSID" | awk '{print $NF}' || true)
    echo "  Network: $WIFI_SSID"
    echo "  Security: $WIFI_SEC"
    echo ""
    if echo "$WIFI_SEC" | grep -qi "wep\|none\|open"; then
        print_non_compliant "Weak or no Wi-Fi encryption" "§164.312(e)(2)(ii)" "Security: $WIFI_SEC" "Connect to WPA2/WPA3 encrypted network"
    elif echo "$WIFI_SEC" | grep -qi "wpa2\|wpa3"; then
        print_compliant "Wi-Fi uses strong encryption ($WIFI_SEC)" "§164.312(e)(2)(ii)"
    else
        print_review "Wi-Fi security type: $WIFI_SEC" "§164.312(e)(2)(ii)" "Verify encryption is adequate for ePHI transmission"
    fi
fi

# Check SSH configuration for encryption
echo "--- SSH Encryption ---"
REMOTE_LOGIN=$(systemsetup -getremotelogin 2>/dev/null || echo "unknown")
if echo "$REMOTE_LOGIN" | grep -qi "On"; then
    if [ -f /etc/ssh/sshd_config ]; then
        SSH_CIPHERS=$(grep -i "^Ciphers" /etc/ssh/sshd_config 2>/dev/null || true)
        WEAK_SSH=false
        if echo "$SSH_CIPHERS" | grep -qi "3des\|arcfour\|blowfish\|des-cbc"; then
            WEAK_SSH=true
        fi
        if [ "$WEAK_SSH" = true ]; then
            print_non_compliant "Weak SSH ciphers configured" "§164.312(e)(2)(ii)" "Ciphers: $SSH_CIPHERS" "Configure strong ciphers only"
        else
            print_compliant "SSH encryption configuration is acceptable" "§164.312(e)(2)(ii)"
        fi
        
        # Check SSH root login
        if grep -qi "^PermitRootLogin\s*yes" /etc/ssh/sshd_config 2>/dev/null; then
            print_non_compliant "SSH root login is permitted" "§164.312(e)(1)" "Root can login directly via SSH" "Set PermitRootLogin no in /etc/ssh/sshd_config"
        else
            print_compliant "SSH root login is restricted" "§164.312(e)(1)"
        fi
    fi
else
    print_compliant "Remote Login (SSH) is disabled" "§164.312(e)(1)"
fi

# Check for VPN
echo "--- VPN Configuration ---"
VPN_CONFIGS=$(scutil --nc list 2>/dev/null || true)
if [ -n "$VPN_CONFIGS" ] && echo "$VPN_CONFIGS" | grep -qi "IPSec\|VPN\|L2TP\|IKE"; then
    echo "$VPN_CONFIGS" | head -5
    print_compliant "VPN configuration(s) found" "§164.312(e)(1)"
else
    print_review "No VPN configurations detected" "§164.312(e)(1)" "Verify encrypted tunnels are used for remote ePHI access"
fi

# Check AirDrop (data leakage risk)
echo "--- AirDrop ---"
AIRDROP_DISABLED=$(defaults read com.apple.NetworkBrowser DisableAirDrop 2>/dev/null || echo "0")
if [ "$AIRDROP_DISABLED" = "1" ]; then
    print_compliant "AirDrop is disabled" "§164.312(e)(1)"
else
    print_non_compliant "AirDrop is enabled" "§164.312(e)(1)" "ePHI could be shared via AirDrop" "Disable: defaults write com.apple.NetworkBrowser DisableAirDrop -bool YES"
fi

# ============================================================
# §164.310 - PHYSICAL SAFEGUARDS (System-level)
# ============================================================
echo "================================================================"
echo "  §164.310 - PHYSICAL SAFEGUARDS (System-level)"
echo "================================================================"
echo ""

# Check Find My Mac
echo "--- Device Tracking ---"
FINDMY=$(defaults read ~/Library/Preferences/com.apple.icloud.fmfd 2>/dev/null || true)
print_review "Find My Mac status" "§164.310(d)(2)(iii)" "Verify Find My Mac is enabled for device tracking and remote wipe capability"

# Check Secure Boot (Apple Silicon / T2)
echo "--- Secure Boot ---"
SECURE_BOOT=$(csrutil authenticated-root status 2>/dev/null || echo "unknown")
echo "  Authenticated root: $SECURE_BOOT"
echo ""
if echo "$SECURE_BOOT" | grep -qi "enabled"; then
    print_compliant "Authenticated root is enabled (SSV)" "§164.310(d)(1)"
fi

# Check firmware password (Intel Macs) / Recovery Lock (Apple Silicon)
print_review "Firmware/Recovery password" "§164.310(d)(1)" "Verify firmware password (Intel) or Recovery Lock (Apple Silicon) is set to prevent boot-level access"

# Check removable media
echo "--- External Storage ---"
EXTERNAL_DISKS=$(diskutil list external 2>/dev/null || true)
if [ -n "$EXTERNAL_DISKS" ]; then
    echo "$EXTERNAL_DISKS" | head -10
    print_review "External storage devices attached" "§164.310(d)(1)" "Verify external drives containing ePHI are encrypted"
else
    echo "  No external storage detected"
    echo ""
fi

# Check Bluetooth
BT_POWER=$(defaults read /Library/Preferences/com.apple.Bluetooth ControllerPowerState 2>/dev/null || echo "unknown")
echo "  Bluetooth power state: $BT_POWER"
if [ "$BT_POWER" = "0" ]; then
    print_compliant "Bluetooth is disabled" "§164.310(d)(1)"
else
    print_review "Bluetooth is enabled" "§164.310(d)(1)" "Ensure Bluetooth is secured and not set to discoverable in ePHI environments"
fi

# ============================================================
# §164.308 - ADMINISTRATIVE SAFEGUARDS (System-level)
# ============================================================
echo "================================================================"
echo "  §164.308 - ADMINISTRATIVE SAFEGUARDS (System-level)"
echo "================================================================"
echo ""

# §164.308(a)(5)(ii)(C) - Login Monitoring
echo "--- §164.308(a)(5)(ii)(C) - Login Monitoring ---"

# Check authentication logs
AUTH_EVENTS=$(log show --predicate 'category == "authentication"' --style syslog --last 24h 2>/dev/null | grep -c "Authentication" || echo "0")
echo "  Authentication events (last 24h): $AUTH_EVENTS"
echo ""

FAILED_AUTH=$(log show --predicate 'category == "authentication" AND eventMessage CONTAINS "failure"' --style syslog --last 24h 2>/dev/null | head -10 || true)
if [ -n "$FAILED_AUTH" ]; then
    FAIL_COUNT=$(echo "$FAILED_AUTH" | grep -c "failure" || echo "0")
    if [ "$FAIL_COUNT" -gt 20 ]; then
        print_non_compliant "High number of failed authentication attempts ($FAIL_COUNT)" "§164.308(a)(5)(ii)(C)" "Possible brute force or unauthorized access attempt" "Investigate source of failed authentications"
    else
        print_compliant "Login monitoring functional — $FAIL_COUNT failed attempts in 24h" "§164.308(a)(5)(ii)(C)"
    fi
else
    print_compliant "No suspicious authentication failures detected" "§164.308(a)(5)(ii)(C)"
fi

# §164.308(a)(5)(ii)(B) - Malware Protection
echo "--- §164.308(a)(5)(ii)(B) - Malware Protection ---"

# Check XProtect
if [ -d /System/Library/CoreServices/XProtect.bundle ]; then
    print_compliant "XProtect malware protection is present" "§164.308(a)(5)(ii)(B)"
else
    print_non_compliant "XProtect not found" "§164.308(a)(5)(ii)(B)" "Built-in malware protection missing" "Verify macOS installation integrity"
fi

# Check MRT
if [ -d "/System/Library/CoreServices/MRT.app" ] || [ -d "/Library/Apple/System/Library/CoreServices/MRT.app" ]; then
    print_compliant "Malware Removal Tool (MRT) is present" "§164.308(a)(5)(ii)(B)"
else
    print_review "MRT not found at expected location" "§164.308(a)(5)(ii)(B)" "MRT may have been superseded in newer macOS versions"
fi

# Check for third-party AV
AV_FOUND=false
for av_app in "Sophos" "CrowdStrike" "Carbon Black" "Malwarebytes" "Symantec" "McAfee" "Kaspersky" "ESET" "Sentinel"; do
    if ls /Applications/ 2>/dev/null | grep -qi "$av_app"; then
        AV_FOUND=true
        print_compliant "Third-party antivirus found: $av_app" "§164.308(a)(5)(ii)(B)"
    fi
done
if [ "$AV_FOUND" = false ]; then
    print_review "No third-party antivirus detected" "§164.308(a)(5)(ii)(B)" "Built-in XProtect provides basic protection — consider enterprise AV for ePHI environments"
fi

# §164.308(a)(7) - Contingency Plan
echo "--- §164.308(a)(7) - Contingency Plan (Backup) ---"

# Check Time Machine
TM_STATUS=$(tmutil status 2>/dev/null || true)
TM_DEST=$(tmutil destinationinfo 2>/dev/null || true)
if [ -n "$TM_DEST" ] && echo "$TM_DEST" | grep -qi "Name"; then
    echo "  Time Machine destination:"
    echo "$TM_DEST" | head -5 | sed 's/^/    /'
    echo ""
    
    LAST_BACKUP=$(tmutil latestbackup 2>/dev/null || echo "unknown")
    echo "  Last backup: $LAST_BACKUP"
    echo ""
    
    if [ "$LAST_BACKUP" != "unknown" ]; then
        print_compliant "Time Machine backups are configured" "§164.308(a)(7)"
    else
        print_non_compliant "Time Machine configured but no backups found" "§164.308(a)(7)" "Backup may have failed" "Verify Time Machine backup is completing successfully"
    fi
else
    print_non_compliant "Time Machine is not configured" "§164.308(a)(7)" "No automated backup in place" "Enable Time Machine or configure alternative backup for ePHI data"
fi

# ============================================================
# ADDITIONAL CHECKS
# ============================================================
echo "================================================================"
echo "  ADDITIONAL TECHNICAL SAFEGUARD CHECKS"
echo "================================================================"
echo ""

# Check NTP
echo "--- Time Synchronization ---"
NTP_ENABLED=$(systemsetup -getusingnetworktime 2>/dev/null || echo "unknown")
echo "  Network Time: $NTP_ENABLED"
if echo "$NTP_ENABLED" | grep -qi "On"; then
    print_compliant "Network time synchronization is enabled" "§164.312(b)"
else
    print_non_compliant "Network time synchronization is OFF" "§164.312(b)" "Audit timestamps may be inaccurate" "Enable: sudo systemsetup -setusingnetworktime on"
fi

# Check sharing services
echo "--- Sharing Services ---"
SHARING_PREFS=$(defaults read /Library/Preferences/com.apple.RemoteManagement 2>/dev/null || true)
SCREEN_SHARING=$(launchctl list 2>/dev/null | grep -c "screensharing" || echo "0")
FILE_SHARING=$(launchctl list 2>/dev/null | grep -c "smbd\|AppleFileServer" || echo "0")
REMOTE_MGMT=$(launchctl list 2>/dev/null | grep -c "ARDAgent" || echo "0")

echo "  Screen Sharing: $([ "$SCREEN_SHARING" -gt 0 ] && echo "ENABLED" || echo "disabled")"
echo "  File Sharing: $([ "$FILE_SHARING" -gt 0 ] && echo "ENABLED" || echo "disabled")"
echo "  Remote Management: $([ "$REMOTE_MGMT" -gt 0 ] && echo "ENABLED" || echo "disabled")"
echo ""

TOTAL_SHARING=$((SCREEN_SHARING + FILE_SHARING + REMOTE_MGMT))
if [ "$TOTAL_SHARING" -gt 0 ]; then
    print_review "Sharing services are enabled ($TOTAL_SHARING services)" "§164.312(e)(1)" "Verify sharing services are necessary and properly secured"
else
    print_compliant "No sharing services are enabled" "§164.312(e)(1)"
fi

# Check login banner
echo "--- Login Banner ---"
LOGIN_TEXT=$(defaults read /Library/Preferences/com.apple.loginwindow LoginwindowText 2>/dev/null || echo "none")
if [ "$LOGIN_TEXT" != "none" ] && [ -n "$LOGIN_TEXT" ]; then
    print_compliant "Login warning banner is configured" "§164.312(a)(1)"
    echo "  Banner text: $LOGIN_TEXT"
    echo ""
else
    print_non_compliant "No login warning banner configured" "§164.312(a)(1)" "No warning about authorized use" "Set: sudo defaults write /Library/Preferences/com.apple.loginwindow LoginwindowText 'Authorized users only. Activity is monitored.'"
fi

# Check for MDM enrollment
echo "--- Mobile Device Management ---"
MDM_STATUS=$(profiles status -type enrollment 2>/dev/null || true)
if [ -n "$MDM_STATUS" ] && echo "$MDM_STATUS" | grep -qi "Yes"; then
    print_compliant "Device is enrolled in MDM" "§164.308(a)(1)"
else
    print_review "MDM enrollment status" "§164.308(a)(1)" "Consider enrolling in MDM for centralized security policy enforcement"
fi

# ============================================================
# §164.308(a)(1) - RISK ANALYSIS & RISK MANAGEMENT
# ============================================================
echo "================================================================"
echo "  §164.308(a)(1) - RISK ANALYSIS & RISK MANAGEMENT"
echo "  Standard: Conduct accurate and thorough assessment of"
echo "  potential risks and vulnerabilities to ePHI"
echo "================================================================"
echo ""

# Check for vulnerability scanning / security tools
echo "--- Risk Analysis Tools ---"
VULN_TOOLS_FOUND=false
for tool in nmap nikto lynis trivy grype; do
    if command -v "$tool" &>/dev/null; then
        VULN_TOOLS_FOUND=true
        print_compliant "Vulnerability scanning tool available: $tool" "§164.308(a)(1)(ii)(A)"
    fi
done
# macOS built-in XProtect / MRT
if [ -d "/Library/Apple/System/Library/CoreServices/XProtect.bundle" ] || [ -d "/System/Library/CoreServices/XProtect.app" ]; then
    VULN_TOOLS_FOUND=true
    print_compliant "Apple XProtect malware scanning available" "§164.308(a)(1)(ii)(A)"
fi
if [ "$VULN_TOOLS_FOUND" = false ]; then
    print_non_compliant "No vulnerability scanning tools detected" "§164.308(a)(1)(ii)(A)" "Cannot perform automated risk assessments" "Install security scanning tools (lynis, nmap, trivy)"
fi

# Check EDR/endpoint security
echo "--- Endpoint Protection (Risk Mitigation) ---"
EDR_FOUND=false
EDR_PRODUCTS=""
# CrowdStrike
if pgrep -f "falcond" &>/dev/null || [ -d "/Library/CS" ] || [ -d "/Applications/Falcon.app" ]; then
    EDR_FOUND=true; EDR_PRODUCTS="$EDR_PRODUCTS CrowdStrike"
fi
# SentinelOne
if pgrep -f "sentineld" &>/dev/null || [ -d "/Library/Sentinel" ]; then
    EDR_FOUND=true; EDR_PRODUCTS="$EDR_PRODUCTS SentinelOne"
fi
# Carbon Black
if pgrep -f "CbOsxSensorService" &>/dev/null; then
    EDR_FOUND=true; EDR_PRODUCTS="$EDR_PRODUCTS CarbonBlack"
fi
# Microsoft Defender
if [ -d "/Applications/Microsoft Defender.app" ] || pgrep -f "wdavdaemon" &>/dev/null; then
    EDR_FOUND=true; EDR_PRODUCTS="$EDR_PRODUCTS MicrosoftDefender"
fi
# Sophos
if [ -d "/Library/Sophos Anti-Virus" ] || pgrep -f "SophosScanD" &>/dev/null; then
    EDR_FOUND=true; EDR_PRODUCTS="$EDR_PRODUCTS Sophos"
fi
# Jamf Protect
if [ -d "/Library/Application Support/JamfProtect" ] || pgrep -f "JamfProtect" &>/dev/null; then
    EDR_FOUND=true; EDR_PRODUCTS="$EDR_PRODUCTS JamfProtect"
fi
# Malwarebytes
if [ -d "/Library/Application Support/Malwarebytes" ]; then
    EDR_FOUND=true; EDR_PRODUCTS="$EDR_PRODUCTS Malwarebytes"
fi
if [ "$EDR_FOUND" = true ]; then
    print_compliant "EDR/endpoint protection active:$EDR_PRODUCTS" "§164.308(a)(1)(ii)(B)"
else
    print_non_compliant "No EDR/endpoint protection detected" "§164.308(a)(1)(ii)(B)" "Endpoints not protected against advanced threats" "Deploy EDR solution (CrowdStrike, SentinelOne, Defender, Jamf Protect)"
fi

# ============================================================
# §164.308(a)(6) - SECURITY INCIDENT PROCEDURES
# ============================================================
echo "================================================================"
echo "  §164.308(a)(6) - SECURITY INCIDENT PROCEDURES"
echo "  Standard: Implement policies and procedures to address"
echo "  security incidents"
echo "================================================================"
echo ""

# Check for incident response documentation
echo "--- Incident Response Plan ---"
IR_DOCS=$(find /Users /opt -maxdepth 4 \( -iname "*incident*response*" -o -iname "*ir*plan*" -o -iname "*security*incident*" -o -iname "*breach*notification*" \) 2>/dev/null | grep -v "node_modules\|\.git\|Library/Caches" | head -5 || true)
if [ -n "$IR_DOCS" ]; then
    echo "  Found:"
    echo "$IR_DOCS" | sed 's/^/    /'
    echo ""
    print_compliant "Incident response documentation found" "§164.308(a)(6)(i)"
else
    print_non_compliant "No incident response plan found on system" "§164.308(a)(6)(i)" "No IR documentation detected" "Develop and maintain an incident response plan; store a copy on managed systems"
fi

# Check for log collection agents (SIEM)
echo "--- SIEM / Log Forwarding ---"
SIEM_FOUND=false
for agent in splunkd filebeat fluentd osqueryd; do
    if pgrep -f "$agent" &>/dev/null; then
        SIEM_FOUND=true
        print_compliant "SIEM/log agent running: $agent" "§164.308(a)(6)(ii)"
    fi
done
# Check for Jamf Protect (also acts as endpoint telemetry)
if pgrep -f "JamfProtect" &>/dev/null; then
    SIEM_FOUND=true
    print_compliant "Jamf Protect endpoint telemetry active" "§164.308(a)(6)(ii)"
fi
if [ "$SIEM_FOUND" = false ]; then
    print_non_compliant "No SIEM/log forwarding agent detected" "§164.308(a)(6)(ii)" "Cannot centralize incident detection" "Deploy SIEM agent (Splunk UF, Elastic Agent, osquery)"
fi

# ============================================================
# §164.308(a)(8) - EVALUATION
# ============================================================
echo "================================================================"
echo "  §164.308(a)(8) - EVALUATION"
echo "  Standard: Perform periodic technical and nontechnical"
echo "  evaluation of security controls"
echo "================================================================"
echo ""

# Check macOS software update history
echo "--- Patch Management Evaluation ---"
LAST_UPDATE=$(softwareupdate --history 2>/dev/null | tail -5 || true)
if [ -n "$LAST_UPDATE" ]; then
    print_compliant "Software update history available" "§164.308(a)(8)"
    echo "  Recent updates:"
    echo "$LAST_UPDATE" | sed 's/^/    /'
    echo ""
else
    print_review "Software update history" "§164.308(a)(8)" "Unable to read update history — verify macOS is up to date"
fi

# Check MDM enrollment (managed configuration)
echo "--- Configuration Management ---"
MDM_ENROLLED=$(profiles status -type enrollment 2>/dev/null || true)
if echo "$MDM_ENROLLED" | grep -qi "enrolled"; then
    print_compliant "System enrolled in MDM (managed configuration)" "§164.308(a)(8)"
else
    print_review "MDM enrollment" "§164.308(a)(8)" "No MDM detected — consider Jamf, Mosyle, or Kandji for standardized security baselines"
fi

# ============================================================
# §164.530(j) - DATA RETENTION & DISPOSAL
# ============================================================
echo "================================================================"
echo "  §164.530(j) - DATA RETENTION & DISPOSAL"
echo "  Standard: Retain documentation for 6 years; implement"
echo "  secure data disposal procedures"
echo "================================================================"
echo ""

# Check for secure deletion capability
echo "--- Secure Data Disposal ---"
if command -v srm &>/dev/null; then
    print_compliant "Secure removal tool (srm) available" "§164.530(j)"
elif command -v gshred &>/dev/null; then
    print_compliant "GNU shred available via Homebrew" "§164.530(j)"
else
    print_review "No secure deletion tool found" "§164.530(j)" "On APFS (SSD), secure erase occurs via FileVault crypto-erase; for HDD, install: brew install coreutils (provides gshred)"
fi

# FileVault provides crypto-erase capability
FV_STATUS=$(fdesetup status 2>/dev/null || true)
if echo "$FV_STATUS" | grep -qi "On"; then
    print_compliant "FileVault encryption enables crypto-erase for secure disposal" "§164.530(j)"
else
    print_review "FileVault disabled" "§164.530(j)" "Without FileVault, secure data disposal on APFS SSDs is difficult"
fi

# ============================================================
# SENSITIVE DATA SCAN & CLASSIFICATION
# ============================================================
echo "================================================================"
echo "  SENSITIVE DATA SCAN & CLASSIFICATION"
echo "  Scanning for potential ePHI/PII in common locations"
echo "================================================================"
echo ""

echo "  Note: Lightweight pattern-based scan — not exhaustive."
echo ""

# SSN patterns
echo "--- Social Security Number Patterns ---"
SSN_FILES=$(grep -rlE "\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b" /Users --include="*.csv" --include="*.txt" --include="*.json" --include="*.xml" 2>/dev/null | grep -v "Library\|\.Trash\|node_modules\|\.git" | head -10 || true)
if [ -n "$SSN_FILES" ]; then
    SSN_COUNT=$(echo "$SSN_FILES" | wc -l | tr -d ' ')
    print_non_compliant "Files with potential SSN patterns ($SSN_COUNT)" "§164.312(a)(1)" "ePHI/PII may be stored unprotected" "Encrypt, access-control, or remove files containing SSNs"
else
    print_compliant "No SSN patterns detected in common locations" "§164.312(a)(1)"
fi

# Medical record indicators
echo "--- Medical Record Number Indicators ---"
MRN_FILES=$(grep -rlE "MRN|medical.record|patient.id|health.record" /Users --include="*.csv" --include="*.txt" --include="*.json" --include="*.xml" 2>/dev/null | grep -v "Library\|\.Trash\|node_modules\|\.git" | head -10 || true)
if [ -n "$MRN_FILES" ]; then
    print_non_compliant "Files with potential medical record indicators" "§164.312(a)(1)" "ePHI storage detected" "Apply access controls, encryption, and audit logging"
else
    print_compliant "No medical record indicators detected" "§164.312(a)(1)"
fi

# Database files
echo "--- Unencrypted Database Files ---"
DB_FILES=$(find /Users -maxdepth 4 \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \) -type f 2>/dev/null | grep -v "Library\|\.Trash" | head -15 || true)
if [ -n "$DB_FILES" ]; then
    DB_COUNT=$(echo "$DB_FILES" | wc -l | tr -d ' ')
    print_review "Unencrypted database files found ($DB_COUNT)" "§164.312(a)(2)(iv)" "Verify databases do not contain ePHI, or are properly encrypted and access-controlled"
fi

# ============================================================
# WORKFORCE SECURITY - §164.308(a)(3)
# ============================================================
echo "================================================================"
echo "  §164.308(a)(3) - WORKFORCE SECURITY"
echo "  Standard: Implement procedures for authorization and"
echo "  supervision of workforce members with ePHI access"
echo "================================================================"
echo ""

# Check for admin accounts
echo "--- Administrative Access Control ---"
ADMIN_USERS=$(dscl . -read /Groups/admin GroupMembership 2>/dev/null | sed 's/GroupMembership: //' || true)
ADMIN_COUNT=$(echo "$ADMIN_USERS" | wc -w | tr -d ' ')
if [ "$ADMIN_COUNT" -le 3 ]; then
    print_compliant "Administrative accounts limited ($ADMIN_COUNT): $ADMIN_USERS" "§164.308(a)(3)(ii)(A)"
else
    print_non_compliant "Excessive admin accounts ($ADMIN_COUNT): $ADMIN_USERS" "§164.308(a)(3)(ii)(A)" "Too many accounts with full system access" "Reduce to minimum necessary admin accounts"
fi

# Check for guest account
echo "--- Guest Account ---"
GUEST_STATUS=$(defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled 2>/dev/null || echo "0")
if [ "$GUEST_STATUS" = "0" ]; then
    print_compliant "Guest account is disabled" "§164.308(a)(3)(ii)(A)"
else
    print_non_compliant "Guest account is enabled" "§164.308(a)(3)(ii)(A)" "Uncontrolled guest access to system" "Disable: System Preferences > Users & Groups > Guest User > off"
fi

# ============================================================
# CYBER INSURANCE & HIPAA ALIGNMENT
# ============================================================
echo "================================================================"
echo "  CYBER INSURANCE & HIPAA ALIGNMENT"
echo "  Common cyber insurance requirements mapped to HIPAA controls"
echo "================================================================"
echo ""

CI_PASS=0
CI_FAIL=0
CI_REVIEW=0

ci_pass() { CI_PASS=$((CI_PASS + 1)); echo "  [INSURABLE] $1"; echo ""; }
ci_fail() { CI_FAIL=$((CI_FAIL + 1)); echo "  [GAP] $1"; echo "    Insurance Impact: $2"; echo ""; }
ci_review() { CI_REVIEW=$((CI_REVIEW + 1)); echo "  [VERIFY] $1"; echo "    Note: $2"; echo ""; }

echo "--- MFA (Required by HIPAA §164.312(d) & most insurers) ---"
TOUCH_ID=$(bioutil -r 2>/dev/null | grep -c "fingerprint" || echo "0")
SMART_CARD=$(security list-smartcards 2>/dev/null || true)
if [ "$TOUCH_ID" -gt 0 ] || [ -n "$SMART_CARD" ]; then
    ci_pass "Biometric/Smart Card MFA available — meets HIPAA authentication and insurer MFA requirements"
else
    ci_fail "No MFA detected" "MFA is a prerequisite for most cyber insurance policies; also required by HIPAA §164.312(d)"
fi

echo "--- EDR (Required by most insurers; supports §164.308(a)(5)(ii)(B)) ---"
if [ "$EDR_FOUND" = true ]; then
    ci_pass "EDR deployed ($EDR_PRODUCTS) — meets insurer endpoint protection requirements"
else
    ci_fail "No EDR solution" "EDR is required by most insurers; strengthens HIPAA malware protection"
fi

echo "--- Email Security (Insurers require DMARC) ---"
DOMAIN_CHECK=""
if command -v dsconfigad &>/dev/null; then
    DOMAIN_CHECK=$(dsconfigad -show 2>/dev/null | grep "Active Directory Domain" | awk '{print $NF}' || true)
fi
if [ -z "$DOMAIN_CHECK" ]; then
    DOMAIN_CHECK=$(hostname -f 2>/dev/null | sed 's/^[^.]*\.//' || true)
fi
if [ -n "$DOMAIN_CHECK" ] && [ "$DOMAIN_CHECK" != "local" ] && command -v dig &>/dev/null; then
    DMARC_CI=$(dig +short TXT "_dmarc.$DOMAIN_CHECK" 2>/dev/null || true)
    if echo "$DMARC_CI" | grep -qi "p=reject\|p=quarantine"; then
        ci_pass "DMARC enforcement active — meets insurer email security requirements"
    else
        ci_fail "DMARC not enforcing" "Most insurers require DMARC at p=quarantine or p=reject to prevent BEC/phishing"
    fi
else
    ci_review "Email security (DMARC)" "Domain not detected — verify email authentication manually"
fi

echo "--- Backup (Required by HIPAA §164.308(a)(7) & insurers) ---"
TM_STATUS=$(tmutil status 2>/dev/null || true)
if echo "$TM_STATUS" | grep -qi "Running = 1\|Backup completed"; then
    ci_pass "Time Machine backups active — meets contingency plan and insurer backup requirements"
elif tmutil listbackups 2>/dev/null | head -1 | grep -q "/"; then
    ci_pass "Time Machine has backup history — meets contingency plan requirements"
else
    ci_fail "No backup solution detected" "Insurers require tested, encrypted backups; HIPAA §164.308(a)(7) requires contingency plan"
fi

echo "--- Encryption (Required by HIPAA §164.312(a)(2)(iv) & insurers) ---"
if echo "$FV_STATUS" | grep -qi "On"; then
    ci_pass "FileVault disk encryption active — meets HIPAA and insurer encryption requirements"
else
    ci_fail "No disk encryption (FileVault off)" "HIPAA requires encryption for ePHI; insurers require encryption at rest on all endpoints"
fi

echo "--- Security Logging (Required by HIPAA §164.312(b) & insurers) ---"
if [ "$SIEM_FOUND" = true ]; then
    ci_pass "Centralized logging/SIEM — meets audit control and insurer monitoring requirements"
else
    ci_fail "No SIEM/centralized logging" "Both HIPAA §164.312(b) and insurers require centralized security monitoring"
fi

echo ""
echo "  --- Cyber Insurance / HIPAA Alignment Summary ---"
echo "  Requirements Met: $CI_PASS"
echo "  Gaps Found:       $CI_FAIL"
echo "  Needs Verification: $CI_REVIEW"
echo ""

# ============================================================
# SUMMARY
# ============================================================
echo ""
echo "========================================================================"
echo "  HIPAA COMPLIANCE ASSESSMENT SUMMARY"
echo "========================================================================"
echo ""
echo "  Compliant Controls:     $COMPLIANT"
echo "  Non-Compliant Controls: $NON_COMPLIANT"
echo "  Needs Review:           $NEEDS_REVIEW"
echo "  Total Controls Checked: $((COMPLIANT + NON_COMPLIANT + NEEDS_REVIEW))"
echo ""
echo "  Cyber Insurance Alignment: $CI_PASS/$((CI_PASS + CI_FAIL + CI_REVIEW)) requirements met"
echo ""
if [ "$NON_COMPLIANT" -gt 0 ]; then
    echo "  STATUS: NON-COMPLIANT — $NON_COMPLIANT control(s) require remediation"
    echo ""
    echo "  IMPORTANT: This scan covers technical safeguards only."
    echo "  HIPAA compliance also requires Administrative and Physical"
    echo "  Safeguards, as well as organizational policies, BAAs, risk"
    echo "  analyses, and workforce training."
elif [ "$NEEDS_REVIEW" -gt 0 ]; then
    echo "  STATUS: REVIEW REQUIRED — $NEEDS_REVIEW control(s) need manual verification"
else
    echo "  STATUS: ALL TECHNICAL CONTROLS COMPLIANT"
fi
echo ""
echo "  DISCLAIMER: This automated scan is not a substitute for a"
echo "  comprehensive HIPAA risk analysis. Consult a qualified HIPAA"
echo "  compliance professional for a complete assessment."
echo ""
echo "  Report generated: $REPORT_DATE"
echo "  Host: $HOSTNAME"
echo "========================================================================"
