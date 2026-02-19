# Security Policy — ChillShell

**Last updated:** February 2026
**Version:** 3.0

---

## 🔒 Security Work Completed

ChillShell has undergone a **thorough internal security review** before publication.

### Security Audits Conducted

**Four successive internal audits:**

1. **White-box Security Audit** (Version 1.5.1)
   - Initial security assessment of the codebase
   - 9 critical fixes applied
   - Security score (self-assessed): **6.5 → 8.5/10**

2. **STRIDE Threat Modeling**
   - 22 threats identified and analyzed
   - 8 risks validated
   - **12 mitigations implemented at 100%**

3. **Ultra-Granular Security Audit** (Trail of Bits methodology)
   - **4 specialized AI agents in parallel** (Claude Opus 4.6, Gemini 3 PRO, Kimi K2.5)
   - 44 files analyzed (~7,500 lines of critical code)
   - **62 findings:** 4 Critical, 8 High, 21 Medium, 21 Low, 8 confirmations
   - **Verdict: 0 remotely exploitable vulnerability identified**

4. **Red Team + Full Defensive Hardening** (February 2026)
   - Offensive simulation: 25 attack vectors identified and analyzed
   - **26 security modules created** (`lib/core/security/`)
   - **738 automated tests** — 0 regressions
   - **30 existing files hardened**

### What This Means

- ✅ Professional security methodology applied (Trail of Bits protocol)
- ✅ No remotely exploitable vulnerability found
- ✅ All identified issues fixed or documented
- ✅ Automated test suite: **738 tests passing**
- ✅ Internal security score (self-assessed): **8.5/10**

---

## 🛡️ Security Measures Implemented

### Secure Storage

All sensitive data is stored via **Flutter Secure Storage**:
- **Android:** AES-GCM encryption via Android Keystore (hardware-backed)
- **iOS:** iOS Keychain with hardware protection

**Protected data:**
- SSH private keys (encrypted at rest)
- PIN code (hashed with PBKDF2-HMAC-SHA256, 100,000 iterations + 32-byte random salt)
- SSH server fingerprints (for TOFU verification)
- Audit log (encrypted)
- Wake-on-LAN configurations
- Command history (after sensitive command filtering)

**Zero hardcoded secrets** in source code (verified by full codebase scan).

---

### Local Authentication

**PIN Code:**
- Minimum 8 digits (100 million combinations)
- Hashed with **PBKDF2-HMAC-SHA256** (100,000 iterations)
- **Constant-time comparison** (XOR byte-by-byte) — prevents timing attacks
- **Rate limiting:** 5 attempts → lockout with exponential backoff (30s → 300s max)
- PIN length is never stored separately (reduces information surface)
- Never stored in plaintext, never kept in memory beyond processing time

**Biometric Authentication:**
- Native system API (fingerprint, Face ID)
- Biometric data never leaves the device
- Strict mode: biometrics only (no fallback to system PIN)
- Required for critical and irreversible actions
- Auto-invalidated when the app goes to background

**Auto-Lock:**
- Configurable timeout: 5, 10, 15, or 30 minutes
- Triggered when the app remains in background beyond the chosen delay
- Re-authentication required if the app stays in background for more than 2 minutes

---

### SSH Connection Security

**TOFU (Trust On First Use) — Hardened:**
- SHA-256 server fingerprint displayed on first connection
- Manual user confirmation required
- Fingerprint stored in secure storage
- **Constant-time comparison** on subsequent connections
- **Red alert** if fingerprint changes (Man-in-the-Middle warning)

**Protocol & Algorithms:**
- SSH2 protocol only (dartssh2 library, version locked)
- Preferred key algorithm: **Ed25519**
- **16 weak SSH algorithms blocked** at software level (SHA-1, CBC, arcfour, 3DES, etc.)
- End-to-end encrypted communications via WireGuard (Tailscale)

**Key Management in Memory:**
- Private keys loaded into a dedicated **SecureKeyHolder** (byte array, not String)
- **Explicit zeroing** after use (limits memory exposure window)
- SSH worker does not retain keys between connections
- Cryptographic operations executed in a **separate Dart isolate** (thread isolation)

**Key Generation:**
- Ed25519 keys generated locally on the device
- Private key bytes **wiped from memory** after storage
- Public key separated from private key in the data model
- JSON serialization **explicitly excludes the private key**

**Session Timeout:**
- Inactive SSH sessions automatically disconnected (15 minutes, configurable)

---

### Data Leak Prevention

**Command History Filtering:**
- Automatic regex filtering excludes secrets from history:
  - AWS keys, JWT/Bearer tokens, API keys
  - Passwords in command-line arguments
  - Variables containing sensitive keywords (SECRET, TOKEN, KEY, PASSWORD)
- **Limit:** 500 entries maximum with automatic rotation
- **Expiry:** entries older than 30 days automatically deleted
- User can manually clear the entire history

**Sensitive Command Warnings:**
- The app detects potentially dangerous shell commands
- A warning is displayed before execution (the user remains in control)

**Production Logs:**
- All debug calls conditioned by Flutter debug mode
- **In production (release APK): zero logs emitted**
- No hostname, IP address, or identifier in production logs
- Tailscale Go engine logs also filtered (OAuth tokens, auth URLs)

**Clipboard:**
- **Auto-cleared** after copying sensitive data (configurable delay: 3s, 5s, 10s, 15s)
- **Silently cleared** when the app goes to background
- Native API used (no "Clipboard cleared" system notification)

---

### Screen Protection

**Android:**
- **FLAG_SECURE** enabled by default
- Blocks screenshots and screen recording
- App does not appear in the recents screen (black screen shown)
- User-configurable in settings

**iOS:**
- Masking screen automatically displayed in background
- Prevents content capture in app switcher
- User-configurable in settings

---

### Anti-Tampering (freeRASP / Talsec)

Integration of **freeRASP 6.12.0** (Talsec Security) — detection of 12 threat types:

| Threat | Detection |
|--------|-----------|
| Android Root / iOS Jailbreak | ✅ |
| Attached debugger | ✅ |
| Hooks (Frida, Xposed) | ✅ |
| Emulator | ✅ |
| APK tampering | ✅ |
| Unofficial store installation | ✅ |
| Missing obfuscation | ✅ |
| No device screen lock | ✅ |
| Developer mode active | ✅ |
| ADB connected | ✅ |

**Behavior:**
- **Warn mode:** recorded in the encrypted audit log
- **Block mode:** blocking alert screen
- Automatically disabled in debug mode (avoids false positives)
- User-configurable in settings (Security section)

---

### Supply Chain Security

- **6 critical packages locked** to exact versions (no `^` that would allow automatic updates):

| Package | Locked Version | Role |
|---------|---------------|------|
| dartssh2 | 2.13.0 | SSH library |
| cryptography | 2.9.0 | Cryptographic primitives |
| pointycastle | 3.9.1 | Cryptographic primitives |
| flutter_secure_storage | 10.0.0 | Secure storage |
| local_auth | 3.0.0 | Biometrics |
| freerasp | 6.12.0 | Anti-tampering |

- Mandatory APK signing for release (build fails without production keystore)
- Code obfuscation enabled on every release build (`--obfuscate --split-debug-info`)

---

### Tamper-Evident Audit Log

**Security events automatically recorded:**
- SSH connection (success or failure)
- SSH disconnection / reconnection
- Authentication failure
- SSH key import / deletion
- PIN creation / deletion
- Server fingerprint change
- Repeated connection attempts (rate limiting)

**Log integrity:**
- Each entry is chained with a SHA-256 hash of the previous entry
- Tampering with any entry invalidates all subsequent entries
- `verifyIntegrity()` method available to check chain integrity

**Storage:**
- Encrypted in secure storage
- Limited to 500 entries with automatic rotation

---

### Wake-on-LAN

- WOL routed preferentially via **Tailscale (encrypted WireGuard)**
- Avoids exposing magic UDP packets in plaintext on the local network
- Fallback to UDP broadcast only if Tailscale is not configured

---

### SFTP File Transfers

- **30 MB maximum per file**
- Streaming transfer (chunks) — prevents memory exhaustion attacks
- Remote path validation — detects directory traversal attempts (`../`)

---

### SSH Key Import

- Format validation before import
- **16 KB limit** (a normal SSH key is under 5 KB)
- Abnormally large files blocked (prevents injections)
- Imported key immediately transferred to secure storage

---

### Tailscale Integration

- **OAuth URLs:** never logged in plaintext
- **Public keys:** truncated in logs (first 16 characters only)
- **Error messages:** generic, do not reveal technical details
- **URL validation:** HTTPS scheme only
- **Dead code removed:** all Tailscale token storage code on the Dart side removed

---

### Permissions

**Android:**
- Minimal permissions requested (network, biometric sensor, local storage)
- **ADB backup disabled** (`allowBackup=false`) — prevents data extraction
- Services marked as non-exported
- Tailscale VPN service protected by system permissions

**iOS:**
- Sensitive data in iOS Keychain (hardware protection)
- Privacy screen auto-activated in background

---

### Secure Architecture

- All SSH operations executed in a **separate Dart isolate** (thread isolation)
- Request IDs: **cryptographically random UUID v4** (unpredictable)
- Zero `debugPrint` in production — all logs go through **SecureLogger** which automatically filters secrets and produces nothing in release builds
- **Post-quantum roadmap** documented (X25519-Kyber768 migration planned when dartssh2 supports it)

---

## ⚠️ Known Limitations (Documented and Accepted)

| Limitation | Explanation | Impact |
|------------|-------------|--------|
| **Dart GC and memory** | The Dart garbage collector may retain temporary copies of data in memory. | **Low.** Requires a rooted device with direct memory access. Mitigated by SecureKeyHolder (Uint8List + zeroing). |
| **Root detection can be bypassed** | Tools like Magisk Hide can hide root from freeRASP. | **Low.** The measure is informative. freeRASP detects the most common vectors. |
| **Ed25519 key not encrypted at rest** | Generated keys use `cipher=none` in their PEM format. | **Acceptable** as long as the key remains in the encrypted secure storage. |

---

## 🚨 Reporting a Vulnerability

**We take security seriously, but please understand our limitations as a volunteer project.**

### Responsible Disclosure Procedure

**If you discover a security vulnerability:**

1. **🚫 DO NOT open a public issue on GitHub**
   - This would immediately put all users at risk
   - Attackers could exploit the flaw before a fix is deployed

2. **📧 Send a private email to:**
   - **Chill_app@outlook.fr**
   - Subject: `[SECURITY] Vulnerability in ChillShell`

3. **📋 Include in your email:**
   - **Description:** Nature of the vulnerability
   - **Reproduction:** Detailed steps to reproduce (PoC)
   - **Impact:** Severity and possible consequences (CVSS score if possible)
   - **Proof of concept:** Code or demonstration (if applicable)
   - **Environment:** Affected versions (ChillShell version, Android/iOS version)
   - **Suggestions:** Proposed fix (optional but appreciated)
   - **Credit:** How you wish to be credited

### Timelines and Expectations

| Step | Estimated Timeline |
|------|--------------------|
| Acknowledgment | 48–72 hours |
| Initial analysis | 2–6 days |
| Critical fix | 1–2 days |
| High fix | 3–4 days |
| Medium/Low fix | 1 week |
| Public disclosure | Coordinated after fix (max 90 days) |

**What you CANNOT expect:**
- 💰 **Bug bounty:** Free open source project, no budget
- ⚡ **Guaranteed SLA:** Volunteer team
- 👔 **Professional support:** 1 developer

### Credit and Public Recognition

If you report a vulnerability responsibly, you will be publicly thanked (if you wish) in:
- This file (Hall of Fame below)
- The CHANGELOG
- The fix's release notes

---

## 🏆 Hall of Fame — Security Researchers

These people helped secure ChillShell by responsibly disclosing vulnerabilities:

*(No contributions yet — be the first!)*

**Format:**
- **Name/Handle** — Description — Severity — Date — CVE (if applicable)

---

## 📚 Security Resources

### SSH Security:
- [Official OpenSSH Guide](https://www.openssh.com/security.html)
- [SSH Hardening Guide](https://www.ssh.com/academy/ssh/security)

### Tailscale Security:
- [Tailscale Security Model](https://tailscale.com/security)
- [Tailscale Encryption (WireGuard)](https://tailscale.com/blog/how-tailscale-works/)

### Mobile Security:
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Android Security Best Practices](https://developer.android.com/topic/security/best-practices)
- [Android Keystore System](https://developer.android.com/training/articles/keystore)
