# Security Policy

## 🔒 Security Work Performed

ChillShell has undergone **extensive internal security validation** before public release.

### Security Audits Conducted

**Three successive internal audits + quality audit:**

1. **White-box Security Audit** (Version 1.5.1)
   - Initial security assessment
   - 9 critical fixes applied
   - Security score improved (self-assessed): **6.5 → 8.5/10**

2. **STRIDE Threat Modeling**
   - 22 threats identified
   - 8 validated risks
   - **12 mitigations implemented at 100%**

3. **Ultra-Granular Security Audit** (Trail of Bits methodology)
   - **4 specialized AI agents in parallel** (Claude Opus 4.6, Gemini 3 PRO, Kimi K2.5)
   - 44 files analyzed (~7,500 critical lines of code)
   - **62 findings:** 4 Critical, 8 High, 21 Medium, 21 Low, 8 confirmations
   - **Verdict: 0 remotely exploitable vulnerabilities identified**

4. **Codebase Quality Audit**
   - 83 files (~24,000 lines of code)
   - 4 critical bugs fixed
   - Dead code removed
   - Refactoring applied
   - **92 unit tests passing**

### What This Means

- ✅ Professional security methodology applied (Trail of Bits protocol)
- ✅ No remotely exploitable vulnerabilities found
- ✅ All identified issues corrected or documented
- ✅ Internal security score (self-assessed): **8.5/10**

---

## 🛡️ Security Measures Implemented

### Secure Storage

All sensitive data is stored via **Flutter Secure Storage**:
- **Android:** AES-CBC encryption via Android Keystore
- **iOS:** iOS Keychain with hardware protection

**Protected data:**
- SSH private keys (encrypted at rest)
- PIN code (hashed with PBKDF2-HMAC-SHA256, 100,000 iterations + 32-byte random salt)
- SSH server fingerprints (for TOFU verification)
- Audit log (encrypted)
- Wake-on-LAN configurations
- Command history (after filtering sensitive commands)

**Zero hardcoded secrets** in source code (verified by full codebase scan).

---

### Local Authentication

**PIN Code:**
- Minimum 8 digits (100 million combinations)
- Hashed with **PBKDF2-HMAC-SHA256** (100,000 iterations)
- **Constant-time comparison** (XOR bit-by-bit) prevents timing attacks
- **Rate limiting:** 5 attempts → 30s lockout, exponential backoff (max 300s)
- Never stored in plaintext, never kept in memory beyond processing time

**Biometric Authentication:**
- Native system API (fingerprint, Face ID)
- Biometric data never leaves the device
- Strict mode: biometric only (no fallback to system PIN)
- Auto-invalidated when app goes to background

**Auto-lock:**
- Configurable timeout: 5, 10, 15, or 30 minutes
- Triggered when app stays in background beyond chosen delay
- Loading screen at startup prevents temporary bypass

---

### SSH Connection Security

**TOFU (Trust On First Use) - Hardened:**
- SHA-256 server fingerprint displayed on first connection
- Manual user confirmation required
- Fingerprint stored in secure storage
- **Constant-time comparison** on subsequent connections
- **Red alert** if fingerprint changes (MITM warning)

**Protocol & Encryption:**
- SSH2 protocol (dartssh2 library)
- Preferred key algorithm: **Ed25519**
- End-to-end encrypted communications

**Key Management in Memory:**
- Private keys loaded into dedicated **SecureBuffer**
- **Explicit zeroing** after use (limits exposure window)
- SSH worker doesn't retain keys between connections
- Cryptographic operations run in **separate Dart isolate** (background thread isolation)

**Key Generation:**
- Ed25519 keys generated locally on device
- Private key bytes **zeroed from memory** after storage
- Public key separated from private key in data model
- JSON serialization **explicitly excludes private key**

---

### Data Leak Protection

**Command History Filtering:**
- Automatic regex filtering excludes secrets from history:
  - AWS keys, JWT/Bearer tokens, API keys
  - Passwords in command line
  - Variables containing sensitive keywords (SECRET, TOKEN, KEY, PASSWORD)
- Automatic expiration: entries older than 90 days deleted
- User can manually clear entire history

**Production Logs:**
- All debug calls conditional on Flutter debug mode
- **In production (release APK): zero logs emitted**
- No hostnames, IP addresses, or identifiers in production logs
- Audit confirmed 188 log occurrences are all protected
- Tailscale Go engine logs also filtered (OAuth tokens, auth URLs)

**Clipboard:**
- **Auto-cleared 30 seconds** after copying sensitive data
- **Silently cleared** when app goes to background (prevents malicious apps from reading)

---

### Screen Protection

**Android:**
- **FLAG_SECURE** enabled by default
- Blocks screenshots and screen recording
- App doesn't appear in recent apps switcher (black screen shown)
- User-disablable in app settings

**iOS:**
- Masking screen automatically displayed when app goes to background
- Prevents content capture in app switcher
- User-disablable in app settings

---

### Compromised Device Detection

- Startup check for rooted (Android) or jailbroken (iOS) devices
- Searches for characteristic paths/files (su, Superuser.apk, Cydia.app, etc.)
- **Warning banner** if detected (informative, not blocking)
- User can choose to continue with full knowledge

---

### Audit Log

**Automatically recorded security events:**
- SSH connection (success or failure)
- SSH disconnection/reconnection
- Authentication failure
- SSH key import/deletion
- PIN creation/deletion
- Server fingerprint change

**Storage:**
- Encrypted in secure storage
- Compact JSON format with timestamps
- Limited to 500 entries with automatic rotation

---

### SFTP File Transfers

- **30 MB maximum per file**
- Streaming transfer (chunks, no full load in memory) prevents memory saturation attacks
- Remote path validation detects directory traversal attempts

---

### SSH Key Import

- Format validation before import
- **16 KB size limit** (normal SSH key < 5 KB)
- Abnormally large files blocked (prevents injections)
- Imported key immediately transferred to secure storage

---

### Tailscale Integration

Security-specific measures:
- **OAuth URLs:** never logged in plaintext (only length logged in debug)
- **Public keys:** truncated in logs (first 16 characters only)
- **Error messages:** generic, don't disclose technical details
- **URL validation:** only HTTPS scheme accepted
- **Dead code removed:** all Dart-side Tailscale token storage code deleted

---

### Permissions

**Android:**
- Minimal permissions requested (network, biometric sensor, local storage)
- **ADB backup disabled** (allowBackup=false) prevents data extraction
- Services marked as non-exported
- Tailscale VPN service protected by system permissions

**iOS:**
- Sensitive data in iOS Keychain (hardware protection)
- Privacy screen auto-enabled in background

---

### Isolate Architecture

- SSH cryptographic operations run in **separate Dart isolate**
- Benefits: UI stays responsive, key processing isolated from rest of app
- Request IDs use **cryptographically random UUID v4** (unpredictable)

---

### Internationalization

- All error messages and UI translated to 5 languages (FR, EN, ES, DE, ZH)
- No hardcoded sensitive strings in source code
- SSH error messages use translated codes in UI

---

## ⚠️ Known Limitations (Documented and Accepted)

| Limitation | Explanation | Impact |
|------------|-------------|--------|
| **Private key in Dart String** | Dart String type is immutable. Private key may remain temporarily in memory until garbage collection. | **Low.** Requires rooted device with memory access. Mitigated by reading from secure storage on each connection. |
| **SecureBuffer and GC** | Dart garbage collector may create temporary copies of data in memory. | **Low.** Same prerequisite as above. |
| **Root detection bypassable** | Tools like Magisk Hide can mask device root. | **Low.** Measure is informative, not preventive. |
| **Ed25519 key not encrypted at rest** | Generated keys use cipher=none in their format. | **Acceptable** as long as key stays in secure storage (encrypted by AES/Keychain). If export planned in future, AES-256-CTR encryption will be added. |
| **SharedPreferences for PIN** | PIN hash and salt in SharedPreferences (accessible without root but protected by PBKDF2). | **Mitigated.** Offline brute force made impractical by 100,000 PBKDF2 iterations. |

---

## 🚨 Reporting a Vulnerability

**We take security seriously, but please understand our limits as a volunteer project.**

### Responsible Disclosure Procedure

**If you discover a security vulnerability:**

1. **🚫 DO NOT open a public GitHub issue**
   - This would immediately endanger all users
   - Attackers could exploit the flaw before a fix is available

2. **📧 Send a private email to:**
   - **Chill_app@outlook.fr**
   - Subject: `[SECURITY] Vulnerability in ChillShell`

3. **📋 Include in your email:**
   - **Description:** Nature of the vulnerability
   - **Reproduction:** Detailed steps to reproduce (PoC)
   - **Impact:** Severity and potential consequences (CVSS score if possible)
   - **Proof of concept:** Code or demonstration (if applicable)
   - **Environment:** Affected versions (ChillShell version, Android version)
   - **Suggestions:** Proposed fix (optional but appreciated)
   - **Credit:** How you wish to be credited (see below)

### Timelines and Expectations

**What you can expect:**
- ⏱️ **Acknowledgment:** 48-72 hours (best effort)
- 🔍 **Initial analysis:** 2-6 days
- 🛠️ **Fix:** Depending on severity and complexity
  - **Critical:** 1-2 days
  - **High:** 3-4 days
  - **Medium/Low:** 1 week
- 📢 **Public disclosure:** Coordinated with you after fix

**What you CANNOT expect:**
- 💰 **Bug bounty:** No budget (free open source project)
- ⚡ **Guaranteed SLAs:** Volunteer project, no contractual deadlines
- 👔 **Professional support:** Limited security team (1 person)

### Credit and Public Recognition

**What is "credit"?**

If you find a vulnerability and report it responsibly, we will thank you publicly (if you wish).

**Options:**

**Option 1: Public Recognition** (default)
- ✅ Your name/pseudonym mentioned in:
  - SECURITY.md (Hall of Fame)
  - CHANGELOG.md
  - Release notes of the fix
  - Potentially on social media
- ✅ Good for your professional reputation
- ✅ Can be added to your CV/LinkedIn

**Option 2: Anonymous**
- ✅ Vulnerability fixed without public mention of who found it
- ✅ Your identity remains private

**Choose your preferred option in your email.**

### Coordinated Disclosure

We follow **coordinated disclosure**:

1. You report the vulnerability to us privately
2. We work on a fix
3. We keep you updated on progress
4. Once fix is deployed and users notified
5. We publish vulnerability details (CVE if applicable)
6. You are publicly credited (if desired)

**Standard timeline:** 90 days maximum between discovery and public disclosure (following Google Project Zero practices).

---

## 🏆 Hall of Fame - Security Researchers

These people helped secure ChillShell by responsibly reporting vulnerabilities:

*(No contributions yet - be the first!)*

**Format:**
- **Name/Pseudonym** - Vulnerability description - Severity (Critical/High/Medium/Low) - Date - CVE (if applicable)

**Example:**
- **John Doe** - SQL Injection in connection manager - High - 2026-03-15 - CVE-2026-12345

---

## 📚 Security Resources

### SSH Security:
- [Official OpenSSH Guide](https://www.openssh.com/security.html)
- [SSH Hardening Guide](https://www.ssh.com/academy/ssh/security)
- [NIST Guide to SSH](https://nvlpubs.nist.gov/nistpubs/ir/2015/NIST.IR.7966.pdf)

### Tailscale Security:
- [Tailscale Security Model](https://tailscale.com/security)
- [Tailscale ACL Guide](https://tailscale.com/kb/1018/acls/)
- [Tailscale Encryption](https://tailscale.com/blog/how-tailscale-works/)

### Android Security:
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Android Security Best Practices](https://developer.android.com/topic/security/best-practices)
- [Android Keystore System](https://developer.android.com/training/articles/keystore)

### Flutter/Dart Security:
- [Flutter Security Best Practices](https://flutter.dev/docs/deployment/security)
- [Dart Security](https://dart.dev/guides/security)

---

**Last updated:** February 2026  
**Policy version:** 2.0
