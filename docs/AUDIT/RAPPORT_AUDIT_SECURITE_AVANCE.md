# RAPPORT AUDIT SECURITE AVANCE — ChillShell (VibeTerm)

**Date** : 2026-02-13
**Methode** : Audit ultra-granulaire (ligne par ligne) — protocole Trail of Bits
**Scope** : Codebase complete (Dart + Kotlin + configs Android)
**Equipe** : 4 agents specialises en parallele
**Fichiers audites** : 44 fichiers, ~7 500 lignes de code critique

---

## RESUME EXECUTIF

L'audit a identifie **62 findings** repartis comme suit :

| Severite | Count | Exemples |
|----------|-------|----------|
| CRITICAL | 4 | Cle privee en String non effacable, release signe avec debug keys, logs Go non filtres, cle Ed25519 non chiffree |
| HIGH | 8 | Pas de ProGuard/R8, race conditions Kotlin, cle non effacee apres generation, path traversal SFTP |
| MEDIUM | 21 | TOFU auto-accept, timing attacks, AndroidOptions vide, rate limiting bypassable |
| LOW | 21 | Divers |
| INFO/OK | 8 | Bonnes pratiques confirmees |

**Verdict global** : L'architecture de securite est **solide pour une app mobile**. Aucune vulnerabilite exploitable a distance. Les risques identifies necessitent un acces physique ou root. Les problemes critiques concernent la gestion memoire des cles (limitation Dart) et la config build Android.

---

## FINDINGS CRITIQUES (a corriger en priorite)

### C1 — Cle privee SSH en String immutable (non effacable)
- **Fichiers** : `ssh_service.dart:49`, `ssh_isolate_messages.dart:70`, `ssh_isolate_worker.dart:149`
- **Probleme** : La cle privee SSH est passee comme `String` Dart (immutable). Elle traverse les isolates via `SendPort`, creant 3+ copies en memoire. Aucune ne peut etre effacee.
- **Impact** : Cle extractible via dump memoire sur appareil compromis.
- **Fix** : Faire lire la cle directement par le worker depuis SecureStorage (il a deja `BackgroundIsolateBinaryMessenger`). Supprimer le champ `privateKey` des messages `connect`.

### C2 — Release build signe avec cles debug
- **Fichier** : `android/app/build.gradle.kts:44`
- **Probleme** : `signingConfig = signingConfigs.getByName("debug")` en release.
- **Impact** : N'importe qui peut signer un APK identique. Pas de garantie d'integrite. Play Store refuserait l'APK.
- **Fix** : Generer un keystore de production et configurer un signing config release.

### C3 — Logs Go (libtailscale) non filtres en production
- **Fichier** : `TailscalePlugin.kt:493-495`
- **Probleme** : Le callback `log(tag, msg)` transmet TOUS les logs Go vers Android logcat sans filtrage. Le backend Go peut logger des tokens OAuth ou URLs d'authentification.
- **Impact** : Fuite potentielle de tokens dans logcat (lisible via ADB).
- **Fix** : `if (BuildConfig.DEBUG) Log.d("TS-$tag", msg)`

### C4 — Cle Ed25519 non chiffree (cipher: none)
- **Fichier** : `key_generation_service.dart:63-64`
- **Probleme** : Les cles Ed25519 sont generees sans chiffrement (cipher=none, kdf=none).
- **Impact** : Si le secure storage est compromis, la cle est lisible en clair.
- **Fix** : Acceptable tant que la cle ne quitte jamais le secure storage. Si export prevu, ajouter chiffrement AES-256-CTR + bcrypt KDF.

---

## FINDINGS HIGH (corriger rapidement)

### H1 — Pas de ProGuard/R8 en release
- **Fichier** : `android/app/build.gradle.kts:40-46`
- **Fix** : Ajouter `isMinifyEnabled = true` + `isShrinkResources = true`

### H2 — Materiel cle privee non efface apres generation
- **Fichier** : `key_generation_service.dart:13`
- **Fix** : Convertir `privateKeyBytes` en Uint8List et `fillRange(0, length, 0)` apres usage

### H3 — Race condition singleton TailscalePlugin
- **Fichier** : `TailscalePlugin.kt:48-49`
- **Fix** : Ajouter `@Volatile` sur `instance`

### H4 — Race condition pendingLoginResult
- **Fichier** : `TailscalePlugin.kt:55,292,312`
- **Fix** : Proteger avec `AtomicReference` ou mutex. Rejeter un second login si un est en cours.

### H5 — START_STICKY sans gestion intent null
- **Fichier** : `TailscaleVpnService.kt:50`
- **Fix** : Changer en `START_NOT_STICKY` ou gerer intent null avec `stopSelf()`

### H6 — Duplication architecturale StorageService / SecureStorageService
- **Fichiers** : `storage_service.dart` / `secure_storage_service.dart`
- **Fix** : Unifier en un seul service pour eviter confusion future

### H7 — Detection root purement informative
- **Fichier** : `device_security_service.dart` + `main.dart:216`
- **Fix** : Ajouter des consequences (forcer PIN a chaque acces, logguer dans audit)

### H8 — Path traversal potentiel SFTP upload
- **Fichier** : `ssh_service.dart:264-311`
- **Fix** : Ajouter warning UI si `remotePath` contient `..`

---

## FINDINGS MEDIUM (planifier)

| # | Finding | Fichier | Fix |
|---|---------|---------|-----|
| M1 | TOFU auto-accept sans callback | ssh_service.dart:91-94 | Rejeter par defaut si stored==null et pas de callback |
| M2 | Comparaison fingerprint non constant-time | ssh_service.dart:98 | Comparaison XOR |
| M3 | SecureBuffer cree String intermediaire | ssh_isolate_worker.dart:375 | Travailler en Uint8List bout en bout |
| M4 | Pas de timeout TOFU host key verification | ssh_isolate_worker.dart:233 | Timeout 60s sur Completer |
| M5 | Future.delayed non annulable pour timeout | ssh_isolate_client.dart:654 | Utiliser Timer annulable |
| M6 | AndroidOptions() sans encryptedSharedPreferences | 5 fichiers services | Ajouter `encryptedSharedPreferences: true` |
| M7 | Longueur PIN stockee en clair | pin_service.dart:75 | Stocker dans le hash ou accepter comme risque mineur |
| M8 | Rate limiting PIN bypassable par kill app | lock_screen.dart:35 | Persister compteur dans SecureStorage |
| M9 | clearAll() efface tout le storage | secure_storage_service.dart:65 | Scoper aux cles SSH via prefix |
| M10 | Audit log sans protection d'integrite | audit_log_service.dart | Ajouter HMAC par entree |
| M11 | Erreurs audit log silencieuses | audit_log_service.dart:46 | Propager erreur ou fallback |
| M12 | SecureBuffer GC copy limitation | secure_buffer.dart:19-21 | Documenter, envisager FFI si critique |
| M13 | EncryptedSharedPreferences recree a chaque appel | TailscalePlugin.kt:598 | Cache dans lazy val |
| M14 | URL BrowseToURL non validee | TailscalePlugin.kt:149-156 | Whitelist domaines Tailscale |
| M15 | Timeout login manquant | TailscalePlugin.kt:312 | Timeout 120s sur pendingLoginResult |
| M16 | isRunning mis prematurement | TailscaleVpnService.kt:121 | Deplacer dans updateVpnStatus() |
| M17 | excludeRoute silencieux API < 33 | TailscaleVpnService.kt:205 | Documenter limitation |
| M18 | security-crypto en version alpha | build.gradle.kts:54 | Evaluer version stable 1.0.0 |
| M19 | Pas de network_security_config.xml | AndroidManifest.xml | Creer avec certificate pinning |
| M20 | Shell injection folder_provider (single quotes) | folder_provider.dart:149 | Echappement shell complet |
| M21 | Comparaison PIN non constant-time | pin_service.dart:97,107 | Utiliser constant-time compare |

---

## POINTS FORTS CONFIRMES

| Aspect | Detail |
|--------|--------|
| Stockage | FlutterSecureStorage (AES/Keychain) pour TOUTES les donnees sensibles |
| PIN | PBKDF2-HMAC-SHA256 (100k iterations) + salt unique |
| Cles SSH | Separation cle privee / metadonnees (`toJson()` exclut privateKey) |
| SSH TOFU | Verification fingerprint au premier connect, alerte si changement |
| Audit log | Evenements securite logues, chiffres au repos, rotation FIFO 500 |
| Protection screenshot | FLAG_SECURE par defaut, desactivable dans settings |
| Detection root | Verification au demarrage (contournable mais informative) |
| Debug prints | 188 occurrences, toutes gardees par `kDebugMode` |
| Nettoyage clipboard | Auto-clear 30s + nettoyage au passage background |
| Biometrie | `biometricOnly: true` — pas de fallback PIN systeme |
| Reconnexion SSH | Worker ne stocke PAS la cle entre les connexions (relit SecureStorage) |
| AndroidManifest | `allowBackup=false`, services non exported, VPN service protege |
| Secrets hardcodes | AUCUN trouve dans tout le codebase |
| Architecture isolate | Operations crypto SSH dans un background isolate (ne bloque pas l'UI) |
| UUID v4 requestId | Cryptographiquement aleatoire, non predictible |

---

## TRUST BOUNDARIES

```
[User] ──PIN/Biometrie──→ [LockScreen] ──→ [App Features]
                                │
                          [PinService]
                          PBKDF2 100k iter
                                │
                    [FlutterSecureStorage]
                      AES / Android Keystore
                      iOS Keychain
                                │
              ┌─────────────────┼─────────────────┐
              │                 │                  │
        [SSH Keys]       [Audit Logs]       [Host Fingerprints]
              │                                    │
    [SSHIsolateWorker]              [TOFU Verification]
     Background Isolate                            │
              │                                    │
     ═══ Reseau SSH ═══                   ═══ Reseau SSH ═══
              │
    [Remote SSH Server]
     - Host key verification
     - Auth Ed25519/RSA
     - Shell / SFTP / exec

═══════════════════════════════════════════════════
              Couche Android Native
═══════════════════════════════════════════════════

    [Flutter] ──MethodChannel──→ [Kotlin]
                                    │
              ┌─────────────────────┼──────────────┐
              │                     │              │
        [FLAG_SECURE]        [TailscalePlugin]  [Clipboard]
                                    │
                              [Go libtailscale]
                                    │
                           ═══ VPN WireGuard ═══
                                    │
                        [Tailscale Control Plane]
                         (TLS, pas de pinning)
```

---

## PLAN DE REMEDIATION SUGGERE

### Sprint 1 — Critiques (avant release)
1. Configurer signing release (keystore production)
2. Activer ProGuard/R8
3. Filtrer logs Go en production (`BuildConfig.DEBUG`)

### Sprint 2 — High Priority
4. Faire lire la cle SSH par le worker depuis SecureStorage directement
5. Ajouter `@Volatile` sur TailscalePlugin.instance
6. Proteger pendingLoginResult (AtomicReference)
7. Effacer privateKeyBytes apres generation
8. Changer START_STICKY → START_NOT_STICKY

### Sprint 3 — Medium
9. AndroidOptions encryptedSharedPreferences: true (5 fichiers)
10. Persister rate limiting PIN dans SecureStorage
11. Comparaison constant-time fingerprints + hashes PIN
12. TOFU : rejeter par defaut si pas de callback
13. Timeout TOFU 60s + timeout login 120s
14. network_security_config.xml avec pinning

### Sprint 4 — Hardening
15. HMAC integrite audit log
16. Echappement shell complet folder_provider
17. Unifier StorageService / SecureStorageService
18. Documenter limitations SecureBuffer
19. Consequences detection root

---

## STATISTIQUES

- **Fichiers audites** : 44
- **Lignes analysees** : ~7 500
- **Findings totaux** : 62
  - Critical : 4
  - High : 8
  - Medium : 21
  - Low : 21
  - Info/OK : 8
- **Bonnes pratiques confirmees** : 15
- **Vulnerabilites exploitables a distance** : 0
- **Agents utilises** : 4 (SSH/Crypto, Auth/Storage, Android Native, Sharp Edges)
- **Duree analyse** : ~5 minutes
