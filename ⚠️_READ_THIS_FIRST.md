# ⚠️ SECURITY WARNING - READ THIS BEFORE INSTALLING

## 🔒 Security: Serious Work Has Been Done

**BEFORE you get alarmed**, know that ChillShell has undergone **thorough security work**:

- ✅ 3 successive internal audits + quality audit
- ✅ Security score according to us **8.5/10** (improved from 6.5)
- ✅ **62 findings corrected** (4 Critical, 8 High, 21 Medium, 21 Low)
- ✅ **0 remotely exploitable vulnerabilities identified**
- ✅ 92 unit tests passing

**📖 See [SECURITY.md](SECURITY.md) for ALL implemented security measures.**

---

## ⚠️ BUT This Project Remains in ALPHA Phase

### What Has NOT Been Done

Despite the work accomplished, this project **HAS NOT received**:

- ❌ Professional external paid security audit
- ❌ Penetration testing (pentest) by experts
- ❌ Code review by professional security experts
- ❌ Security certification
- ❌ Fuzzing of parsers (SSH, terminal)
- ❌ Load / DoS testing

### How This Project Was Created

- 🤖 Developed with assistance from Claude Code Opus 4.6 AI, and Gemini 3 PRO & Kimi K2.5 on support
- 👨‍💻 By a **non-professional developer** (former manager)
- 🔍 **Internal** security audit (not external)

---

## 🎯 Attack Surface and Risks

This application provides **full remote SSH access** to your computer via the **ChillShell** mobile app that connects to the **Chill** desktop application.

### Security Architecture

```
┌──────────────────┐         SSH         ┌──────────────────┐
│  ChillShell      │ ◄──────────────────► │  Chill Desktop   │
│  (Mobile)        │   Encrypted via      │  (PC)            │
│                  │   Tailscale VPN      │                  │
│  Vectors:        │                      │  Vectors:        │
│  • Android App   │                      │  • SSH Server    │
│  • Key Storage   │                      │  • Tailscale     │
│  • SSH Parser    │                      │  • Wake-on-LAN   │
│  • Terminal UI   │                      │  • Config Files  │
└──────────────────┘                      └──────────────────┘
```

### Threat Scenarios (If Our Protections Were Bypassed)

These scenarios represent what COULD happen **IF** an attacker discovered a vulnerability **AND** managed to bypass our protections. Each requires overcoming multiple security layers:

#### 🔐 SSH Private Key Theft
**What would be needed:**
- Bypass Android Keystore AES-CBC encryption
- Extract memory from a rooted device
- Overcome SecureBuffer zeroing and memory isolation (Dart isolate)

**Our protections:** Flutter Secure Storage (AES/Keychain), explicit memory zeroing, keys never cached between connections

#### 📦 Command Injection
**What would be needed:**
- Bypass input validation and path sanitization
- Exploit the SSH/terminal parser
- Circumvent sensitive command filtering (AWS keys, tokens, passwords)

**Our protections:** Input validation, path traversal detection, command history filtering with regex

#### 🔓 PIN Brute Force
**What would be needed:**
- Bypass rate limiting (5 attempts → 30s lockout, exponential backoff max 300s)
- Crack PBKDF2 offline (100,000 iterations)
- Overcome constant-time comparison

**Our protections:** PBKDF2-HMAC-SHA256 (100k iterations) + unique 32-byte salt, rate limiting, constant-time XOR comparison

#### 🎭 SSH Man-in-the-Middle Attack
**What would be needed:**
- User must ignore the red alert for fingerprint change
- Bypass constant-time fingerprint comparison
- Compromise the TOFU (Trust On First Use) mechanism

**Our protections:** Hardened TOFU with manual confirmation, red MITM warning, constant-time comparison, stored fingerprints in secure storage

#### 🗂️ Path Traversal (Folder Navigation)
**What would be needed:**
- Bypass remote path validation
- Exploit the folder navigator to access `../../etc/passwd`

**Our protections:** Path validation, `..` detection in SFTP uploads

#### 🔍 Root/Jailbreak Exploit
**What would be needed:**
- Bypass detection (possible with Magisk Hide)
- User must ignore the warning banner
- Exploit the compromised device to extract data

**Our protections:** Startup detection (su, Superuser.apk, Cydia.app), warning banner (informative, not blocking)

#### 🌐 Tailscale/Supply Chain Compromise
**What would be needed:**
- Compromise Tailscale infrastructure OR
- Malicious dependency update (dartssh2, xterm) via pub.dev OR
- Incorrect ACL configuration by user

**Our protections:** Tailscale OAuth URL filtering, dependency version pinning, ACL documentation in README

---

**Key takeaway:** Each scenario requires multiple layers to be bypassed. Our architecture implements defense in depth, but no system is 100% secure. Always follow the security best practices below.

### Potential Impact of a Flaw

If a vulnerability is exploited, an attacker could:

- 💀 **Complete system access**: Full control of your computer
- 📁 **File theft**: All your documents, photos, videos
- 🔑 **Credential theft**: Passwords, SSH keys, tokens, session cookies
- 💳 **Banking data**: If stored on PC
- 🎥 **Surveillance**: Activate webcam, microphone, keylogger
- 💾 **Ransomware**: Encrypt your data and demand ransom
- 🗑️ **Destruction**: Delete all your files
- 🌐 **Pivot**: Use your PC to attack other systems on your network
- 🔓 **Persistent backdoor**: Install permanent access

---

## 🛡️ MANDATORY Security Best Practices

### For Users

**BEFORE installing:**

1. ✅ **Understand the risks** - Reread all warnings in the README
2. ✅ **Review the code** - Or have someone competent review it
3. ✅ **Backup everything** - Full system and important data
4. ✅ **Prepare a plan B** - How to recover if things go wrong

**SECURE configuration:**

5. ✅ **Use Chill Desktop** - Secure Tailscale + SSH + WOL package
6. ✅ **ED25519 keys ONLY** - NEVER SSH passwords
   ```bash
   # Generate a key from ChillShell or your PC
   ssh-keygen -t ed25519 -C "ChillShell"
   ```
7. ✅ **Hardened SSH configuration**:
   ```bash
   # /etc/ssh/sshd_config
   PermitRootLogin no
   PasswordAuthentication no
   PubkeyAuthentication yes
   MaxAuthTries 3
   LoginGraceTime 30
   X11Forwarding no
   ```
8. ✅ **Restrictive Tailscale ACLs** - Limit who can connect:
   ```json
   {
     "acls": [
       {
         "action": "accept",
         "src": ["tag:mobile"],
         "dst": ["tag:desktop:22"]
       }
     ]
   }
   ```
9. ✅ **Active firewall** - Even with Tailscale (defense in depth)
10. ✅ **Dedicated user** - Not your main account
    ```bash
    sudo useradd -m -s /bin/bash chillshell
    # Don't add to sudo unless strictly necessary
    ```

**ACTIVE monitoring:**

11. ✅ **Monitor SSH logs** regularly
    ```bash
    sudo tail -f /var/log/auth.log  # Linux
    log show --predicate 'process == "sshd"' --info  # macOS
    ```
12. ✅ **Check active connections**
    ```bash
    who       # Connected users
    last      # Connection history
    ss -tnp   # Active TCP connections
    ```
13. ✅ **Automatic alerts** - Configure notifications for:
    - Successful SSH connections
    - Repeated failed attempts (> 3 in 5 min)
    - System file modifications (auditd)
14. ✅ **Regular audits**:
    ```bash
    sudo aureport -au  # Authentication events (Linux)
    sudo fail2ban-client status sshd  # Active bans
    ```

**MANDATORY updates:**

15. ✅ **Keep up to date**:
    - ChillShell (check GitHub regularly)
    - Chill Desktop
    - Tailscale
    - OpenSSH
    - Android operating system
    - PC operating system
16. ✅ **Monitor security advisories**:
    - [ChillShell Releases](https://github.com/Kevin-hdev/ChillShell/releases)
    - [GitHub Security Advisories](https://github.com/Kevin-hdev/ChillShell/security/advisories)

**TEST in SAFE environment:**

17. ✅ **Start on a test system**:
    - Not your main PC
    - No sensitive data
    - Isolated environment (VM recommended)
18. ✅ **Only move to production if**:
    - No problems after 2+ weeks of testing
    - You fully understand how it works
    - You have an incident response plan

---

## ⚖️ Legal Disclaimer

**THIS SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.**

The authors and contributors:
- ❌ Do NOT guarantee that the software is free from bugs or vulnerabilities
- ❌ Are NOT responsible for damages, data loss, security breaches
- ❌ Offer NO warranty of support or fixes
- ❌ Cannot be held liable in case of system compromise

**BY USING THIS SOFTWARE, YOU AGREE TO ASSUME ALL RISKS.**

If you are not comfortable with this level of risk, **DO NOT USE this software.**

---

## 📖 Want to Know What Security Measures ARE in Place?

👉 **Read [SECURITY.md](SECURITY.md)** for complete details on:
- All 3 security audits performed
- Every security measure implemented
- Known limitations (documented)
- How to report vulnerabilities responsibly

---

**Last updated:** February 2026  
**Version:** 1.0
