#!/bin/bash
# HIPAA Compliance Scan (Linux)
# Assesses system configuration against HIPAA Security Rule requirements
# Covers Administrative, Physical, and Technical Safeguards
# Reference: 45 CFR Part 164 - Security and Privacy

set -euo pipefail

REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)

echo "========================================================================"
echo "  HIPAA COMPLIANCE ASSESSMENT REPORT"
echo "  Host: $HOSTNAME"
echo "  Date: $REPORT_DATE"
echo "  OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' || uname -s)"
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
# Check that all users have unique UIDs
DUPLICATE_UIDS=$(awk -F: '{print $3}' /etc/passwd | sort | uniq -d || true)
if [ -n "$DUPLICATE_UIDS" ]; then
    print_non_compliant "Duplicate UIDs detected" "§164.312(a)(2)(i)" "UIDs: $DUPLICATE_UIDS" "Ensure each user has a unique UID"
else
    print_compliant "All users have unique UIDs" "§164.312(a)(2)(i)"
fi

# Check for shared/generic accounts
GENERIC_ACCOUNTS=$(awk -F: '$3 >= 1000 && $3 < 60000 { print $1 }' /etc/passwd | grep -iE "^(shared|generic|temp|test|guest|admin|service|user[0-9])" || true)
if [ -n "$GENERIC_ACCOUNTS" ]; then
    print_non_compliant "Potential shared/generic accounts found" "§164.312(a)(2)(i)" "Accounts: $GENERIC_ACCOUNTS" "Replace with individually-assigned user accounts"
else
    print_compliant "No shared/generic accounts detected" "§164.312(a)(2)(i)"
fi

# Total user listing
echo "  Active user accounts:"
awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /nologin|false/ { printf "    %-20s UID: %-6s Shell: %s\n", $1, $3, $7 }' /etc/passwd
echo ""

# (ii) Emergency Access Procedure (Required)
echo "--- §164.312(a)(2)(ii) - Emergency Access Procedure [REQUIRED] ---"
echo ""
# Check for break-glass / emergency access mechanisms
if [ -r /etc/sudoers ]; then
    EMERGENCY_ACCESS=$(grep -r "NOPASSWD\|EMERGENCY\|break.glass" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v "^#" || true)
    if [ -n "$EMERGENCY_ACCESS" ]; then
        print_review "Emergency access entries found in sudoers" "§164.312(a)(2)(ii)" "Review: $EMERGENCY_ACCESS"
    else
        print_review "No documented emergency access procedure in system config" "§164.312(a)(2)(ii)" "Ensure emergency access procedures exist in organizational policy"
    fi
fi

# (iii) Automatic Logoff (Addressable)
echo "--- §164.312(a)(2)(iii) - Automatic Logoff [ADDRESSABLE] ---"
echo ""
# Check for session timeout settings
TMOUT_SET=$(grep -r "^TMOUT\|^export TMOUT\|^readonly TMOUT" /etc/profile /etc/profile.d/ /etc/bash.bashrc /etc/bashrc 2>/dev/null || true)
if [ -n "$TMOUT_SET" ]; then
    print_compliant "Shell session timeout (TMOUT) is configured" "§164.312(a)(2)(iii)"
    echo "  Configuration: $TMOUT_SET"
    echo ""
else
    print_non_compliant "No automatic session timeout configured" "§164.312(a)(2)(iii)" "Shell sessions do not auto-terminate" "Set TMOUT=900 in /etc/profile (15 minutes)"
fi

# Check SSH timeout
if [ -f /etc/ssh/sshd_config ]; then
    CLIENT_ALIVE=$(grep -i "^ClientAliveInterval\|^ClientAliveCountMax" /etc/ssh/sshd_config 2>/dev/null || true)
    if [ -n "$CLIENT_ALIVE" ]; then
        print_compliant "SSH session timeout is configured" "§164.312(a)(2)(iii)"
        echo "  $CLIENT_ALIVE"
        echo ""
    else
        print_non_compliant "SSH session timeout not configured" "§164.312(a)(2)(iii)" "SSH sessions remain open indefinitely" "Set ClientAliveInterval 300 and ClientAliveCountMax 3 in sshd_config"
    fi
fi

# (iv) Encryption and Decryption (Addressable)
echo "--- §164.312(a)(2)(iv) - Encryption and Decryption [ADDRESSABLE] ---"
echo ""
# Check disk encryption
echo "  Checking disk encryption status..."
LUKS_FOUND=false
if command -v lsblk &>/dev/null; then
    ENCRYPTED_PARTS=$(lsblk -o NAME,TYPE,FSTYPE 2>/dev/null | grep -i "crypt\|luks" || true)
    if [ -n "$ENCRYPTED_PARTS" ]; then
        LUKS_FOUND=true
        print_compliant "Disk encryption (LUKS) detected" "§164.312(a)(2)(iv)"
        echo "$ENCRYPTED_PARTS" | sed 's/^/  /'
        echo ""
    fi
fi

if command -v dmsetup &>/dev/null; then
    DM_CRYPT=$(dmsetup ls --target crypt 2>/dev/null || true)
    if [ -n "$DM_CRYPT" ] && echo "$DM_CRYPT" | grep -qv "No devices found"; then
        LUKS_FOUND=true
        echo "  dm-crypt devices: $DM_CRYPT"
    fi
fi

if [ "$LUKS_FOUND" = false ]; then
    print_non_compliant "No disk encryption detected" "§164.312(a)(2)(iv)" "ePHI on disk may be unencrypted" "Enable LUKS full-disk encryption or encrypt ePHI partitions"
fi

# ============================================================
# §164.312(b) - AUDIT CONTROLS
# ============================================================
echo "================================================================"
echo "  §164.312(b) - AUDIT CONTROLS"
echo "  Standard: Implement hardware, software, and/or procedural"
echo "  mechanisms that record and examine activity in systems"
echo "  containing or using ePHI"
echo "================================================================"
echo ""

# Check if auditd is installed and running
echo "--- System Audit Daemon ---"
if command -v auditctl &>/dev/null; then
    if systemctl is-active auditd &>/dev/null 2>&1; then
        print_compliant "auditd is installed and running" "§164.312(b)"
        
        # Check audit rules
        AUDIT_RULES=$(auditctl -l 2>/dev/null || true)
        RULE_COUNT=$(echo "$AUDIT_RULES" | grep -c . || echo "0")
        echo "  Active audit rules: $RULE_COUNT"
        echo ""
        
        # Check for critical file monitoring
        CRITICAL_MONITORED=true
        for file in /etc/passwd /etc/shadow /etc/group /etc/sudoers; do
            if ! echo "$AUDIT_RULES" | grep -q "$file"; then
                CRITICAL_MONITORED=false
            fi
        done
        
        if [ "$CRITICAL_MONITORED" = true ]; then
            print_compliant "Critical files are monitored by audit rules" "§164.312(b)"
        else
            print_non_compliant "Critical files not fully monitored by auditd" "§164.312(b)" "Missing audit rules for /etc/passwd, /etc/shadow, etc." "Add rules: auditctl -w /etc/passwd -p wa -k identity"
        fi
    else
        print_non_compliant "auditd is installed but NOT running" "§164.312(b)" "Audit daemon is inactive" "Start: systemctl start auditd && systemctl enable auditd"
    fi
else
    print_non_compliant "auditd is not installed" "§164.312(b)" "No system-level audit framework" "Install: apt install auditd (Debian) or yum install audit (RHEL)"
fi

# Check syslog/journald
echo "--- System Logging ---"
if systemctl is-active rsyslog &>/dev/null 2>&1 || systemctl is-active syslog-ng &>/dev/null 2>&1 || systemctl is-active systemd-journald &>/dev/null 2>&1; then
    print_compliant "System logging service is active" "§164.312(b)"
else
    print_non_compliant "No system logging service active" "§164.312(b)" "System events are not being logged" "Enable rsyslog or journald"
fi

# Check log retention
echo "--- Log Retention ---"
if [ -f /etc/logrotate.conf ]; then
    ROTATE_WEEKS=$(grep -i "^rotate" /etc/logrotate.conf 2>/dev/null | awk '{print $2}' || true)
    ROTATE_PERIOD=$(grep -iE "^(weekly|monthly|daily)" /etc/logrotate.conf 2>/dev/null || true)
    echo "  Log rotation: $ROTATE_PERIOD, keep $ROTATE_WEEKS rotations"
    # HIPAA requires 6-year retention for audit logs
    print_review "Log retention period needs verification" "§164.312(b)" "HIPAA requires audit logs be retained for 6 years — verify archive/backup of logs"
else
    print_non_compliant "No logrotate configuration found" "§164.312(b)" "Log rotation may not be configured" "Configure /etc/logrotate.conf with appropriate retention"
fi

# Check for centralized logging
echo "--- Centralized Logging ---"
REMOTE_LOG=$(grep -r "^[^#].*@@\|^[^#].*action.*type=\"omfwd\"" /etc/rsyslog.conf /etc/rsyslog.d/ 2>/dev/null || true)
if [ -n "$REMOTE_LOG" ]; then
    print_compliant "Remote/centralized logging is configured" "§164.312(b)"
else
    print_review "No centralized logging detected" "§164.312(b)" "Consider forwarding logs to a central SIEM for ePHI access monitoring"
fi

# ============================================================
# §164.312(c)(1) - INTEGRITY
# ============================================================
echo "================================================================"
echo "  §164.312(c)(1) - INTEGRITY CONTROLS"
echo "  Standard: Implement policies and procedures to protect"
echo "  ePHI from improper alteration or destruction"
echo "================================================================"
echo ""

# Check file integrity monitoring
echo "--- File Integrity Monitoring ---"
FIM_FOUND=false
if command -v aide &>/dev/null; then
    FIM_FOUND=true
    print_compliant "AIDE file integrity monitoring is installed" "§164.312(c)(2)"
elif command -v tripwire &>/dev/null; then
    FIM_FOUND=true
    print_compliant "Tripwire file integrity monitoring is installed" "§164.312(c)(2)"
elif command -v osquery &>/dev/null; then
    FIM_FOUND=true
    print_compliant "osquery is installed (can provide FIM)" "§164.312(c)(2)"
fi

if [ "$FIM_FOUND" = false ]; then
    print_non_compliant "No file integrity monitoring (FIM) tool detected" "§164.312(c)(2)" "Cannot verify ePHI has not been improperly altered" "Install AIDE: apt install aide && aide --init"
fi

# Check filesystem mount options for data partitions
echo "--- Filesystem Integrity Options ---"
MOUNT_INFO=$(mount | grep -E "^\/" || true)
echo "$MOUNT_INFO" | head -10
echo ""
print_review "Review mount options for ePHI storage locations" "§164.312(c)(1)" "Ensure data partitions use appropriate mount options (e.g., noexec, nosuid on data-only mounts)"

# ============================================================
# §164.312(d) - PERSON OR ENTITY AUTHENTICATION
# ============================================================
echo "================================================================"
echo "  §164.312(d) - PERSON OR ENTITY AUTHENTICATION"
echo "  Standard: Implement procedures to verify that a person"
echo "  or entity seeking access to ePHI is who they claim to be"
echo "================================================================"
echo ""

# Check PAM configuration for multi-factor
echo "--- Multi-Factor Authentication ---"
MFA_CONFIGURED=false
if grep -rq "pam_google_authenticator\|pam_yubico\|pam_duo\|pam_u2f\|pam_oath" /etc/pam.d/ 2>/dev/null; then
    MFA_CONFIGURED=true
    print_compliant "Multi-factor authentication PAM module detected" "§164.312(d)"
fi
if [ "$MFA_CONFIGURED" = false ]; then
    print_non_compliant "No multi-factor authentication detected" "§164.312(d)" "Single-factor authentication only" "Implement MFA using pam_google_authenticator, Duo, or FIDO2 keys"
fi

# Check password strength requirements
echo "--- Password Strength Requirements ---"
if [ -f /etc/pam.d/common-password ]; then
    PW_QUALITY=$(grep "pam_pwquality\|pam_cracklib" /etc/pam.d/common-password 2>/dev/null || true)
elif [ -f /etc/pam.d/system-auth ]; then
    PW_QUALITY=$(grep "pam_pwquality\|pam_cracklib" /etc/pam.d/system-auth 2>/dev/null || true)
else
    PW_QUALITY=""
fi

if [ -n "$PW_QUALITY" ]; then
    print_compliant "Password complexity requirements configured" "§164.312(d)"
    echo "  Config: $PW_QUALITY"
    echo ""
    
    # Check minimum length
    MIN_LEN=$(echo "$PW_QUALITY" | grep -o "minlen=[0-9]*" | head -1 | cut -d= -f2 || true)
    if [ -n "$MIN_LEN" ] && [ "$MIN_LEN" -ge 12 ] 2>/dev/null; then
        print_compliant "Minimum password length >= 12 characters" "§164.312(d)"
    elif [ -n "$MIN_LEN" ]; then
        print_non_compliant "Minimum password length is only $MIN_LEN characters" "§164.312(d)" "HIPAA recommends strong passwords" "Set minlen=12 or higher in PAM config"
    fi
else
    print_non_compliant "No password complexity enforcement" "§164.312(d)" "No pam_pwquality or pam_cracklib configured" "Install and configure pam_pwquality with minlen=12, dcredit=-1, ucredit=-1, lcredit=-1, ocredit=-1"
fi

# Check password aging
echo "--- Password Aging Policy ---"
if [ -f /etc/login.defs ]; then
    PASS_MAX_DAYS=$(grep "^PASS_MAX_DAYS" /etc/login.defs 2>/dev/null | awk '{print $2}' || true)
    PASS_MIN_DAYS=$(grep "^PASS_MIN_DAYS" /etc/login.defs 2>/dev/null | awk '{print $2}' || true)
    PASS_WARN_AGE=$(grep "^PASS_WARN_AGE" /etc/login.defs 2>/dev/null | awk '{print $2}' || true)
    
    echo "  PASS_MAX_DAYS: ${PASS_MAX_DAYS:-not set}"
    echo "  PASS_MIN_DAYS: ${PASS_MIN_DAYS:-not set}"
    echo "  PASS_WARN_AGE: ${PASS_WARN_AGE:-not set}"
    echo ""
    
    if [ -n "$PASS_MAX_DAYS" ] && [ "$PASS_MAX_DAYS" -le 90 ] 2>/dev/null; then
        print_compliant "Password maximum age is set to $PASS_MAX_DAYS days" "§164.312(d)"
    elif [ -n "$PASS_MAX_DAYS" ] && [ "$PASS_MAX_DAYS" -gt 90 ] 2>/dev/null; then
        print_non_compliant "Password maximum age is $PASS_MAX_DAYS days" "§164.312(d)" "Exceeds recommended 90-day rotation" "Set PASS_MAX_DAYS to 90 in /etc/login.defs"
    fi
fi

# Check account lockout
echo "--- Account Lockout Policy ---"
FAILLOCK=$(grep -r "pam_faillock\|pam_tally2" /etc/pam.d/ 2>/dev/null | grep -v "^#" || true)
if [ -n "$FAILLOCK" ]; then
    print_compliant "Account lockout mechanism is configured" "§164.312(d)"
    echo "  Config: $FAILLOCK"
    echo ""
else
    print_non_compliant "No account lockout mechanism configured" "§164.312(d)" "Unlimited authentication attempts allowed" "Configure pam_faillock with deny=5 unlock_time=900"
fi

# ============================================================
# §164.312(e)(1) - TRANSMISSION SECURITY
# ============================================================
echo "================================================================"
echo "  §164.312(e)(1) - TRANSMISSION SECURITY"
echo "  Standard: Implement technical security measures to guard"
echo "  against unauthorized access to ePHI being transmitted"
echo "================================================================"
echo ""

# Check SSH encryption
echo "--- SSH Encryption Configuration ---"
if [ -f /etc/ssh/sshd_config ]; then
    SSH_CIPHERS=$(grep -i "^Ciphers" /etc/ssh/sshd_config 2>/dev/null || true)
    SSH_MACS=$(grep -i "^MACs" /etc/ssh/sshd_config 2>/dev/null || true)
    SSH_KEX=$(grep -i "^KexAlgorithms" /etc/ssh/sshd_config 2>/dev/null || true)
    
    WEAK_CIPHER=false
    if echo "$SSH_CIPHERS" | grep -qi "3des\|arcfour\|blowfish\|cast128\|des-cbc"; then
        WEAK_CIPHER=true
    fi
    if echo "$SSH_MACS" | grep -qi "md5\|hmac-sha1-96"; then
        WEAK_CIPHER=true
    fi
    
    if [ "$WEAK_CIPHER" = true ]; then
        print_non_compliant "Weak SSH ciphers or MACs configured" "§164.312(e)(2)(ii)" "Weak cryptographic algorithms in use" "Configure strong ciphers only: chacha20-poly1305, aes256-gcm, aes128-gcm"
    else
        print_compliant "SSH uses acceptable encryption" "§164.312(e)(2)(ii)"
    fi
fi

# Check TLS configuration
echo "--- TLS/SSL Configuration ---"
if command -v openssl &>/dev/null; then
    OPENSSL_VER=$(openssl version 2>/dev/null || true)
    echo "  OpenSSL version: $OPENSSL_VER"
    
    # Check for SSLv2/SSLv3 support
    if openssl s_client -ssl2 -connect localhost:443 </dev/null &>/dev/null 2>&1; then
        print_non_compliant "SSLv2 is supported on port 443" "§164.312(e)(2)(ii)" "SSLv2 is cryptographically broken" "Disable SSLv2 in all TLS-enabled services"
    fi
    if openssl s_client -ssl3 -connect localhost:443 </dev/null &>/dev/null 2>&1; then
        print_non_compliant "SSLv3 is supported on port 443" "§164.312(e)(2)(ii)" "SSLv3 is vulnerable to POODLE" "Disable SSLv3 in all TLS-enabled services"
    fi
    echo ""
fi

# Check for unencrypted services
echo "--- Unencrypted Service Check ---"
INSECURE_PORTS=""
for port in 21 23 25 80 110 143 161; do
    if ss -tlnp 2>/dev/null | grep -q ":$port "; then
        case $port in
            21) INSECURE_PORTS="$INSECURE_PORTS FTP(:21)" ;;
            23) INSECURE_PORTS="$INSECURE_PORTS Telnet(:23)" ;;
            25) INSECURE_PORTS="$INSECURE_PORTS SMTP(:25)" ;;
            80) INSECURE_PORTS="$INSECURE_PORTS HTTP(:80)" ;;
            110) INSECURE_PORTS="$INSECURE_PORTS POP3(:110)" ;;
            143) INSECURE_PORTS="$INSECURE_PORTS IMAP(:143)" ;;
            161) INSECURE_PORTS="$INSECURE_PORTS SNMP(:161)" ;;
        esac
    fi
done

if [ -n "$INSECURE_PORTS" ]; then
    print_non_compliant "Potentially unencrypted services detected" "§164.312(e)(1)" "Services:$INSECURE_PORTS" "Replace with encrypted alternatives (SFTP, SSH, SMTPS, HTTPS, IMAPS, SNMPv3)"
else
    print_compliant "No common unencrypted services detected on standard ports" "§164.312(e)(1)"
fi

# Check IPsec / VPN
echo "--- VPN / IPsec ---"
VPN_FOUND=false
if command -v ipsec &>/dev/null; then
    IPSEC_STATUS=$(ipsec status 2>/dev/null | head -5 || true)
    if [ -n "$IPSEC_STATUS" ]; then
        VPN_FOUND=true
        echo "  IPsec: Active"
    fi
fi
if command -v wg &>/dev/null; then
    WG_STATUS=$(wg show 2>/dev/null | head -5 || true)
    if [ -n "$WG_STATUS" ]; then
        VPN_FOUND=true
        echo "  WireGuard: Active"
    fi
fi
if command -v openvpn &>/dev/null; then
    VPN_FOUND=true
    echo "  OpenVPN: Installed"
fi
echo ""
print_review "VPN / encrypted tunnel availability" "§164.312(e)(1)" "Verify all remote ePHI access uses encrypted tunnels (VPN, SSH tunnel, TLS)"

# ============================================================
# §164.310 - PHYSICAL SAFEGUARDS (System-level checks)
# ============================================================
echo "================================================================"
echo "  §164.310 - PHYSICAL SAFEGUARDS (System-level)"
echo "  Standard: Physical measures to protect electronic"
echo "  information systems and equipment"
echo "================================================================"
echo ""

# Check USB storage restrictions
echo "--- USB Storage Policy ---"
USB_DISABLED=$(grep -r "install usb-storage /bin/true\|blacklist usb-storage" /etc/modprobe.d/ 2>/dev/null || true)
if [ -n "$USB_DISABLED" ]; then
    print_compliant "USB storage is restricted" "§164.310(d)(1)"
else
    USB_LOADED=$(lsmod 2>/dev/null | grep usb_storage || true)
    if [ -n "$USB_LOADED" ]; then
        print_non_compliant "USB storage module is loaded and unrestricted" "§164.310(d)(1)" "Data exfiltration risk via removable media" "Blacklist: echo 'blacklist usb-storage' > /etc/modprobe.d/usb-storage.conf"
    else
        print_review "USB storage module status" "§164.310(d)(1)" "Module not currently loaded but not explicitly blacklisted"
    fi
fi

# Check screen lock
echo "--- Screen Lock ---"
if command -v gsettings &>/dev/null; then
    LOCK_ENABLED=$(gsettings get org.gnome.desktop.screensaver lock-enabled 2>/dev/null || true)
    LOCK_DELAY=$(gsettings get org.gnome.desktop.screensaver lock-delay 2>/dev/null || true)
    IDLE_DELAY=$(gsettings get org.gnome.desktop.session idle-delay 2>/dev/null || true)
    echo "  Screen lock enabled: $LOCK_ENABLED"
    echo "  Lock delay: $LOCK_DELAY"
    echo "  Idle delay: $IDLE_DELAY"
    echo ""
    if [ "$LOCK_ENABLED" = "true" ]; then
        print_compliant "Screen lock is enabled" "§164.310(b)"
    else
        print_non_compliant "Screen lock is not enabled" "§164.310(b)" "Unattended workstation access risk" "Enable: gsettings set org.gnome.desktop.screensaver lock-enabled true"
    fi
fi

# ============================================================
# §164.308 - ADMINISTRATIVE SAFEGUARDS (System-level checks)
# ============================================================
echo "================================================================"
echo "  §164.308 - ADMINISTRATIVE SAFEGUARDS (System-level)"
echo "  Standard: Administrative actions, policies, and procedures"
echo "================================================================"
echo ""

# §164.308(a)(5)(ii)(C) - Log-in Monitoring
echo "--- §164.308(a)(5)(ii)(C) - Login Monitoring ---"
if [ -f /var/log/auth.log ] || [ -f /var/log/secure ]; then
    print_compliant "Authentication logs are present" "§164.308(a)(5)(ii)(C)"
    
    AUTH_LOG="/var/log/auth.log"
    [ -f /var/log/secure ] && AUTH_LOG="/var/log/secure"
    
    FAILED_TODAY=$(grep -c "Failed password\|authentication failure" "$AUTH_LOG" 2>/dev/null || echo "0")
    echo "  Failed authentication attempts in current log: $FAILED_TODAY"
    echo ""
    
    if [ "$FAILED_TODAY" -gt 50 ]; then
        print_non_compliant "High number of failed login attempts: $FAILED_TODAY" "§164.308(a)(5)(ii)(C)" "Possible brute force attack" "Investigate failed login sources and consider fail2ban"
    fi
else
    print_non_compliant "Authentication logs not found" "§164.308(a)(5)(ii)(C)" "Cannot monitor login activity" "Ensure rsyslog or journald captures auth events"
fi

# Check fail2ban or similar
echo "--- Intrusion Prevention ---"
if command -v fail2ban-client &>/dev/null; then
    F2B_STATUS=$(fail2ban-client status 2>/dev/null || true)
    if echo "$F2B_STATUS" | grep -qi "running\|active"; then
        print_compliant "fail2ban is installed and running" "§164.308(a)(5)(ii)(C)"
    else
        print_non_compliant "fail2ban is installed but not running" "§164.308(a)(5)(ii)(C)" "Intrusion prevention not active" "Start: systemctl start fail2ban"
    fi
else
    print_review "No automated intrusion prevention tool (fail2ban) detected" "§164.308(a)(5)(ii)(C)" "Consider installing fail2ban for automated login monitoring"
fi

# §164.308(a)(7) - Contingency Plan (backup verification)
echo "--- §164.308(a)(7) - Contingency Plan (Backup Checks) ---"
echo ""
# Check for backup tools
BACKUP_TOOL=false
for tool in rsync borgbackup restic duplicity bacula amanda; do
    if command -v "$tool" &>/dev/null; then
        BACKUP_TOOL=true
        echo "  Backup tool found: $tool"
    fi
done
echo ""
if [ "$BACKUP_TOOL" = true ]; then
    print_review "Backup tools detected" "§164.308(a)(7)" "Verify backup schedules include all ePHI data and test restores regularly"
else
    print_non_compliant "No backup tools detected" "§164.308(a)(7)" "No backup mechanism found on system" "Install and configure backup solution (e.g., rsync, borgbackup, restic)"
fi

# Check cron for scheduled backups
BACKUP_CRONS=$(crontab -l 2>/dev/null | grep -i "backup\|rsync\|borg\|restic\|duplicity" || true)
if [ -n "$BACKUP_CRONS" ]; then
    print_compliant "Scheduled backup jobs found in crontab" "§164.308(a)(7)"
    echo "  Jobs: $BACKUP_CRONS"
    echo ""
else
    print_review "No scheduled backup cron jobs found for current user" "§164.308(a)(7)" "Verify backup scheduling via other mechanisms (systemd timers, external tools)"
fi

# ============================================================
# ADDITIONAL HIPAA TECHNICAL SAFEGUARD CHECKS
# ============================================================
echo "================================================================"
echo "  ADDITIONAL TECHNICAL SAFEGUARD CHECKS"
echo "================================================================"
echo ""

# Check NTP synchronization (important for audit log correlation)
echo "--- Time Synchronization ---"
if command -v timedatectl &>/dev/null; then
    NTP_STATUS=$(timedatectl show --property=NTPSynchronized --value 2>/dev/null || true)
    if [ "$NTP_STATUS" = "yes" ]; then
        print_compliant "NTP time synchronization is active" "§164.312(b)"
    else
        print_non_compliant "NTP time synchronization is NOT active" "§164.312(b)" "Audit log timestamps may be inaccurate" "Enable: timedatectl set-ntp true"
    fi
elif command -v ntpstat &>/dev/null; then
    if ntpstat &>/dev/null 2>&1; then
        print_compliant "NTP is synchronized" "§164.312(b)"
    fi
fi

# Check for antivirus/endpoint protection
echo "--- Endpoint Protection ---"
AV_FOUND=false
for av in clamd clamav-daemon crowdstrike falcon-sensor carbon_black; do
    if systemctl is-active "$av" &>/dev/null 2>&1 || pgrep -x "$av" &>/dev/null 2>&1; then
        AV_FOUND=true
        print_compliant "Endpoint protection active: $av" "§164.308(a)(5)(ii)(B)"
    fi
done
if command -v clamscan &>/dev/null; then
    AV_FOUND=true
    echo "  ClamAV scanner is installed"
fi
if [ "$AV_FOUND" = false ]; then
    print_non_compliant "No endpoint protection/antivirus detected" "§164.308(a)(5)(ii)(B)" "System lacks malware protection" "Install endpoint protection (ClamAV for open-source: apt install clamav)"
fi

# Check system banner (required for warning notice)
echo "--- Login Banner ---"
if [ -f /etc/issue ] && [ -s /etc/issue ]; then
    BANNER_CONTENT=$(cat /etc/issue)
    if echo "$BANNER_CONTENT" | grep -qi "authorized\|unauthorized\|monitor\|private\|warning"; then
        print_compliant "Login banner with access warning is present" "§164.312(a)(1)"
    else
        print_review "Login banner exists but may not contain required warnings" "§164.312(a)(1)" "Add warnings about unauthorized access and monitoring"
    fi
else
    print_non_compliant "No login banner configured" "§164.312(a)(1)" "/etc/issue is empty or missing" "Create /etc/issue with authorized use warning text"
fi

if [ -f /etc/motd ] && [ -s /etc/motd ]; then
    echo "  MOTD is configured"
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

# Check for vulnerability scanning tools
echo "--- Risk Analysis Tools ---"
VULN_TOOLS_FOUND=false
for tool in nessus openvas nmap nikto lynis trivy grype; do
    if command -v "$tool" &>/dev/null; then
        VULN_TOOLS_FOUND=true
        print_compliant "Vulnerability scanning tool available: $tool" "§164.308(a)(1)(ii)(A)"
    fi
done
if [ "$VULN_TOOLS_FOUND" = false ]; then
    print_non_compliant "No vulnerability scanning tools detected" "§164.308(a)(1)(ii)(A)" "Cannot perform automated risk assessments" "Install vulnerability scanning tools (lynis, nmap, trivy)"
fi

# Check for risk assessment documentation
RISK_DOCS=$(find /home /opt /var -maxdepth 4 \( -iname "*risk*assessment*" -o -iname "*risk*analysis*" -o -iname "*security*assessment*" \) 2>/dev/null | grep -v "/proc\|/sys\|node_modules\|\.git" | head -5 || true)
if [ -n "$RISK_DOCS" ]; then
    print_compliant "Risk assessment documentation found on system" "§164.308(a)(1)(ii)(A)"
else
    print_review "Risk assessment documentation" "§164.308(a)(1)(ii)(A)" "No risk assessment docs found — verify organizational risk analysis is documented and current"
fi

# Check EDR/endpoint security
echo "--- Endpoint Protection (Risk Mitigation) ---"
EDR_FOUND=false
EDR_PRODUCTS=""
for proc in falcon-sensor sentinelone sentinelctl cbagentd cbdaemon mdatp sophos wazuh-agent ossec esets_daemon ds_agent; do
    if pgrep -f "$proc" &>/dev/null; then
        EDR_FOUND=true
        EDR_PRODUCTS="$EDR_PRODUCTS $proc"
    fi
done
for dir in /opt/CrowdStrike /opt/sentinelone /opt/carbonblack /var/ossec /opt/microsoft/mdatp /opt/sophos-av /opt/eset; do
    if [ -d "$dir" ]; then
        EDR_FOUND=true
        EDR_PRODUCTS="$EDR_PRODUCTS ${dir##*/}"
    fi
done
if [ "$EDR_FOUND" = true ]; then
    print_compliant "EDR/endpoint protection active:$EDR_PRODUCTS" "§164.308(a)(1)(ii)(B)"
else
    print_non_compliant "No EDR/endpoint protection detected" "§164.308(a)(1)(ii)(B)" "Endpoints not protected against advanced threats" "Deploy EDR solution (CrowdStrike, SentinelOne, Defender for Endpoint)"
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
IR_DOCS=$(find /home /opt /var -maxdepth 4 \( -iname "*incident*response*" -o -iname "*ir*plan*" -o -iname "*security*incident*" -o -iname "*breach*notification*" \) 2>/dev/null | grep -v "/proc\|/sys\|node_modules\|\.git" | head -5 || true)
if [ -n "$IR_DOCS" ]; then
    echo "  Found:"
    echo "$IR_DOCS" | sed 's/^/    /'
    echo ""
    print_compliant "Incident response documentation found" "§164.308(a)(6)(i)"
else
    print_non_compliant "No incident response plan found on system" "§164.308(a)(6)(i)" "No IR documentation detected" "Develop and maintain an incident response plan; store a copy on managed systems"
fi

# Check for intrusion detection
echo "--- Intrusion Detection ---"
IDS_FOUND=false
if systemctl is-active fail2ban &>/dev/null 2>&1; then
    IDS_FOUND=true
    print_compliant "fail2ban intrusion prevention is active" "§164.308(a)(6)(ii)"
fi
if systemctl is-active crowdsec &>/dev/null 2>&1; then
    IDS_FOUND=true
    print_compliant "CrowdSec intrusion detection is active" "§164.308(a)(6)(ii)"
fi
if [ -d /var/ossec ] || pgrep -f "ossec\|wazuh" &>/dev/null; then
    IDS_FOUND=true
    print_compliant "OSSEC/Wazuh HIDS is active" "§164.308(a)(6)(ii)"
fi
if [ "$IDS_FOUND" = false ]; then
    print_non_compliant "No intrusion detection system found" "§164.308(a)(6)(ii)" "Cannot detect security incidents in real-time" "Deploy IDS/IPS solution (fail2ban, Wazuh, CrowdSec)"
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

# Check last system scan
echo "--- Last Security Evaluation Indicators ---"
LAST_LYNIS=$(find / -maxdepth 5 -name "lynis-report*" -mtime -90 2>/dev/null | head -1 || true)
LAST_NMAP=$(find / -maxdepth 5 -name "nmap*" -mtime -90 2>/dev/null | head -1 || true)
if [ -n "$LAST_LYNIS" ] || [ -n "$LAST_NMAP" ]; then
    print_compliant "Recent security scan results found (within 90 days)" "§164.308(a)(8)"
else
    print_review "No recent security scan results found" "§164.308(a)(8)" "HIPAA requires periodic evaluation — document regular security assessments"
fi

# Check for configuration management
echo "--- Configuration Management ---"
CM_FOUND=false
for tool in ansible puppet chef salt; do
    if command -v "$tool" &>/dev/null; then
        CM_FOUND=true
        print_compliant "Configuration management tool found: $tool" "§164.308(a)(8)"
    fi
done
if [ "$CM_FOUND" = false ]; then
    print_review "No configuration management tool detected" "§164.308(a)(8)" "Consider Ansible/Puppet/Chef for standardized security configurations"
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

# Check for secure deletion tools
echo "--- Secure Data Disposal Tools ---"
WIPE_TOOLS=false
for tool in shred srm wipe secure-delete; do
    if command -v "$tool" &>/dev/null; then
        WIPE_TOOLS=true
        print_compliant "Secure deletion tool available: $tool" "§164.530(j)"
    fi
done
if [ "$WIPE_TOOLS" = false ]; then
    print_review "No secure deletion tools found" "§164.530(j)" "Install shred or secure-delete for ePHI disposal: sudo apt install secure-delete"
fi

# Check filesystem TRIM (SSD secure erase support)
SSD_TRIM=$(systemctl is-active fstrim.timer 2>/dev/null || true)
if [ "$SSD_TRIM" = "active" ]; then
    print_compliant "SSD TRIM timer is active (supports secure erase)" "§164.530(j)"
fi

# Check for temporary file cleanup
TMPWATCH=$(systemctl is-active systemd-tmpfiles-clean.timer 2>/dev/null || true)
if [ "$TMPWATCH" = "active" ]; then
    print_compliant "Temporary file cleanup is automated" "§164.530(j)"
else
    print_review "Temporary file cleanup" "§164.530(j)" "Verify temporary files containing ePHI are regularly purged"
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
SSN_FILES=$(grep -rlE "\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b" /home /var/www /srv /opt --include="*.csv" --include="*.txt" --include="*.log" --include="*.json" --include="*.xml" --include="*.sql" 2>/dev/null | head -10 || true)
if [ -n "$SSN_FILES" ]; then
    SSN_COUNT=$(echo "$SSN_FILES" | wc -l)
    print_non_compliant "Files with potential SSN patterns ($SSN_COUNT)" "§164.312(a)(1)" "ePHI/PII may be stored unprotected" "Encrypt, access-control, or remove files containing SSNs"
else
    print_compliant "No SSN patterns detected in common locations" "§164.312(a)(1)"
fi

# Medical record number patterns (MRN - common formats)
echo "--- Medical Record Number Indicators ---"
MRN_FILES=$(grep -rlE "MRN|medical.record|patient.id|health.record" /home /var/www /srv --include="*.csv" --include="*.txt" --include="*.json" --include="*.xml" 2>/dev/null | head -10 || true)
if [ -n "$MRN_FILES" ]; then
    print_non_compliant "Files with potential medical record indicators" "§164.312(a)(1)" "ePHI storage detected" "Apply access controls, encryption, and audit logging to these files"
else
    print_compliant "No medical record number patterns detected" "§164.312(a)(1)"
fi

# Database files
echo "--- Unencrypted Database Files ---"
DB_FILES=$(find /home /var /srv /opt -maxdepth 4 \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" -o -name "*.mdb" \) -type f 2>/dev/null | head -15 || true)
if [ -n "$DB_FILES" ]; then
    DB_COUNT=$(echo "$DB_FILES" | wc -l)
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

# Check for terminated/disabled accounts that still have access
echo "--- Account Lifecycle ---"
INACTIVE_ACCOUNTS=""
while IFS=: read -r user _ uid _ _ home shell; do
    if [ "$uid" -ge 1000 ] 2>/dev/null && [ "$shell" != "/usr/sbin/nologin" ] && [ "$shell" != "/bin/false" ]; then
        LAST_LOGIN=$(lastlog -u "$user" 2>/dev/null | tail -1 || true)
        if echo "$LAST_LOGIN" | grep -qi "never"; then
            INACTIVE_ACCOUNTS="$INACTIVE_ACCOUNTS $user"
        fi
    fi
done < /etc/passwd
if [ -n "$INACTIVE_ACCOUNTS" ]; then
    print_non_compliant "Accounts that have never logged in:$INACTIVE_ACCOUNTS" "§164.308(a)(3)(ii)(C)" "Potentially orphaned accounts with system access" "Review and disable: usermod -L <user> -s /usr/sbin/nologin"
else
    print_compliant "No inactive/orphaned accounts detected" "§164.308(a)(3)(ii)(C)"
fi

# Check for shared accounts
echo "--- Shared/Generic Account Check ---"
SHARED_ACCOUNTS=""
while IFS=: read -r user _ uid _ _ _ _; do
    if [ "$uid" -ge 1000 ] 2>/dev/null; then
        case "$user" in
            shared*|generic*|temp*|test*|user[0-9]*|admin[0-9]*)
                SHARED_ACCOUNTS="$SHARED_ACCOUNTS $user" ;;
        esac
    fi
done < /etc/passwd
if [ -n "$SHARED_ACCOUNTS" ]; then
    print_non_compliant "Potential shared/generic accounts:$SHARED_ACCOUNTS" "§164.308(a)(3)(ii)(A)" "Shared accounts prevent individual accountability" "Replace with individually-assigned accounts"
else
    print_compliant "No shared/generic accounts detected" "§164.308(a)(3)(ii)(A)"
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
MFA_PAM=$(grep -rE "pam_google_authenticator|pam_duo|pam_yubico|pam_u2f|pam_oath" /etc/pam.d/ 2>/dev/null || true)
if [ -n "$MFA_PAM" ]; then
    ci_pass "MFA configured — meets HIPAA authentication and insurer MFA requirements"
else
    ci_fail "No MFA detected" "MFA is a prerequisite for most cyber insurance policies; also required by HIPAA §164.312(d)"
fi

echo "--- EDR (Required by most insurers; supports HIPAA §164.308(a)(5)(ii)(B)) ---"
if [ "$EDR_FOUND" = true ]; then
    ci_pass "EDR deployed — meets insurer endpoint protection requirements"
else
    ci_fail "No EDR solution" "EDR is required by most insurers; strengthens HIPAA malware protection (§164.308(a)(5)(ii)(B))"
fi

echo "--- Email Security (Insurers require DMARC; supports HIPAA §164.312(e)) ---"
DOMAIN_CHECK=$(hostname -d 2>/dev/null || dnsdomainname 2>/dev/null || echo "")
if [ -z "$DOMAIN_CHECK" ] || [ "$DOMAIN_CHECK" = "(none)" ]; then
    DOMAIN_CHECK=$(hostname -f 2>/dev/null | sed 's/^[^.]*\.//' || true)
fi
if [ -n "$DOMAIN_CHECK" ] && [ "$DOMAIN_CHECK" != "localdomain" ] && command -v dig &>/dev/null; then
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
BACKUP_DETECTED=false
for tool in restic borg borgmatic duplicity rsync rclone bacula bareos; do
    if command -v "$tool" &>/dev/null; then BACKUP_DETECTED=true; fi
done
if [ "$BACKUP_DETECTED" = true ]; then
    ci_pass "Backup tools deployed — meets contingency plan and insurer backup requirements"
else
    ci_fail "No backup tools detected" "Insurers require tested, encrypted, offline/immutable backups; HIPAA §164.308(a)(7) requires contingency plan"
fi

echo "--- Encryption (Required by HIPAA §164.312(a)(2)(iv) & insurers) ---"
LUKS_ACTIVE=$(lsblk -o NAME,TYPE,FSTYPE 2>/dev/null | grep -i "crypt\|luks" || dmsetup ls --target crypt 2>/dev/null || true)
if [ -n "$LUKS_ACTIVE" ]; then
    ci_pass "Disk encryption active — meets HIPAA and insurer encryption requirements"
else
    ci_fail "No disk encryption" "HIPAA requires encryption for ePHI; insurers require encryption at rest on all endpoints"
fi

echo "--- Security Logging (Required by HIPAA §164.312(b) & insurers) ---"
SIEM_FOUND=false
if [ -f /etc/rsyslog.conf ] && grep -qE "^@@|^@" /etc/rsyslog.conf 2>/dev/null; then SIEM_FOUND=true; fi
for agent in filebeat fluentd fluentbit td-agent splunkd datadog-agent; do
    if pgrep -f "$agent" &>/dev/null || systemctl is-active "$agent" &>/dev/null 2>&1; then SIEM_FOUND=true; fi
done
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
