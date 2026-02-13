# ChillShell — Sécurité

Document récapitulatif de toutes les protections de sécurité en place dans ChillShell.
Dernière mise à jour : 8 février 2026.

---

## Méthodologie

La sécurité de ChillShell a été validée par :
1. **Audit white-box** (V1.5.1) — 9 correctifs initiaux
2. **Analyse STRIDE** — Modélisation des menaces (22 menaces, 8 risques validés, 12 mitigations)

---

## Stockage des données sensibles

| Donnée | Méthode de stockage | Chiffrement |
|--------|---------------------|-------------|
| Clés SSH privées | `flutter_secure_storage` | AES-CBC (Android Keystore) / Keychain (iOS) |
| Code PIN | Hash PBKDF2-HMAC-SHA256 (100k itérations) + salt aléatoire | Jamais stocké en clair |
| Fingerprints SSH | `flutter_secure_storage` | AES-CBC / Keychain |
| Journal d'audit | `flutter_secure_storage` (JSON) | AES-CBC / Keychain |
| Configurations WOL | `flutter_secure_storage` | AES-CBC / Keychain |
| Historique commandes | `flutter_secure_storage` | AES-CBC / Keychain |

Aucun secret n'est stocké en clair. Aucune clé API, mot de passe ou credential n'est hardcodé dans le code source.

---

## Connexion SSH

### Vérification TOFU (Trust On First Use)
- A la première connexion, l'empreinte (fingerprint SHA-256) du serveur est affichée
- L'utilisateur doit confirmer manuellement avant de se connecter
- L'empreinte est stockée et vérifiée automatiquement pour les connexions suivantes
- Si l'empreinte change : **alerte rouge** avec explication du risque MITM

### Protocole
- Connexion via `dartssh2` (protocole SSH2 standard)
- Algorithme de clé préféré : Ed25519
- Toutes les communications sont chiffrées de bout en bout par le protocole SSH

### Gestion des clés en mémoire
- Les clés privées sont chargées dans un `SecureBuffer` (wrapper `Uint8List`)
- Après utilisation, la mémoire est explicitement remplie de zéros (`dispose()`)
- Limite la fenêtre d'exposition en mémoire

---

## Authentification locale

### Code PIN
- Minimum **8 chiffres** (100 millions de combinaisons possibles)
- Hashé avec **PBKDF2-HMAC-SHA256** (100 000 itérations) + salt aléatoire 32 octets
- Verrouillage temporaire après tentatives échouées (délai croissant)
- Le PIN en clair n'est jamais stocké

### Biométrie (empreinte digitale / Face ID)
- Utilise l'API système (`local_auth`) — les données biométriques restent sur l'appareil
- L'authentification biométrique est invalidée dès que l'app passe en arrière-plan
- Ré-authentification obligatoire au retour

### Verrouillage automatique
- Configurable : 5, 10, 15 ou 30 minutes
- Se déclenche quand l'app reste en arrière-plan au-delà du délai choisi

---

## Protection contre les fuites de données

### Historique des commandes
- **Filtrage automatique des secrets** par regex :
  - Clés AWS (`AKIA...`)
  - Tokens (JWT, Bearer, API keys)
  - Mots de passe en ligne de commande (`--password=`, `-p`)
  - Variables sensibles (`SECRET`, `TOKEN`, `KEY`, `PASSWORD`)
- Les commandes contenant des secrets sont **exclues** de l'historique
- **Expiration automatique** : les entrées de plus de 90 jours sont supprimées
- Possibilité d'effacer tout l'historique manuellement

### Logs de debug
- Tous les `debugPrint` sont conditionnés par `kDebugMode`
- En production (APK release) : **aucun log** n'est émis
- Aucun hostname, IP, ou identifiant n'apparaît dans les logs de production

### Clipboard
- Le clipboard est **vidé silencieusement** quand l'app passe en arrière-plan
- Utilise l'API native Android (`clearPrimaryClip()`)
- Empêche les apps malveillantes de lire des données copiées

---

## Protection d'écran

### Android
- `FLAG_SECURE` activé par défaut : bloque les screenshots et l'enregistrement d'écran
- L'app n'apparaît pas dans le sélecteur d'apps récentes (écran noir)
- Désactivable dans Settings > Sécurité si besoin (toggle "Captures d'écran")

### iOS
- Écran de masquage (privacy screen) quand l'app passe en arrière-plan
- Empêche la capture du contenu dans le sélecteur d'apps
- Désactivable via le même toggle dans les réglages

---

## Détection d'appareil compromis

- Au démarrage, l'app vérifie si l'appareil est rooté (Android) ou jailbreaké (iOS)
- Vérification des chemins connus (`su`, `Superuser.apk`, `Cydia.app`, etc.)
- Si détecté : **bannière d'avertissement** informant que la sécurité des clés SSH peut être compromise
- Non-bloquant : l'utilisateur peut continuer (choix assumé)

---

## Journal d'audit

- Événements enregistrés automatiquement :
  - Connexion SSH (succès/échec)
  - Déconnexion SSH
  - Reconnexion SSH
  - Échec d'authentification
  - Import / suppression de clé SSH
  - Création / suppression de PIN
  - Changement de fingerprint serveur
- Stocké chiffré dans `flutter_secure_storage`
- Maximum 500 entrées (rotation FIFO automatique)
- Format compact JSON avec horodatage

---

## Transferts de fichiers (SFTP)

- Limite de taille : **30 Mo maximum** par fichier
- Transfert par streaming (chunks) : pas de chargement complet en mémoire
- Empêche les attaques par saturation mémoire (DoS/OOM)

---

## Import de clés SSH

- Validation du format avant import
- Limite de taille : **16 Ko maximum** (une clé SSH normale fait < 5 Ko)
- Bloque les fichiers anormalement gros (protection anti-injection)
- La clé est stockée immédiatement dans le stockage sécurisé

---

## Internationalisation

- Tous les messages d'erreur et d'interface sont traduits en **5 langues** (FR, EN, ES, DE, ZH)
- Aucune chaîne sensible n'est hardcodée dans le code source
- Les messages d'erreur SSH utilisent des codes traduits côté UI

---

## Permissions

### Android
- `android:allowBackup="false"` — empêche l'extraction des données via ADB backup
- Permissions demandées uniquement celles nécessaires (réseau, stockage local, biométrie)

### iOS
- Données sensibles stockées dans le Keychain iOS (protection matérielle)
- Privacy screen automatique en arrière-plan

---

## Limitations connues

| Limitation | Explication | Impact |
|-----------|-------------|--------|
| SecureBuffer et GC Dart | Le garbage collector peut créer des copies temporaires des clés en mémoire | Faible — nécessite un appareil rooté + accès mémoire |
| Détection root contournable | Des outils comme Magisk Hide peuvent masquer le root | Faible — mesure informative, pas préventive |
| PIN en String pendant la saisie | La String Dart est immutable, reste en mémoire jusqu'au GC | Très faible — fenêtre d'exposition de quelques millisecondes |

---

## Résumé des audits

| Audit | Date | Score | Résultat |
|-------|------|-------|----------|
| Audit white-box V1.5.1 | Fév. 2026 | 6.5 → 8.5/10 | 9 correctifs appliqués |
| Analyse STRIDE complète | Fév. 2026 | 22 menaces → 8 risques → 12 mitigations | 100% implémentées |

----------------------------------

Tu en penses quoi ? ça rend tout de suite beaucoup mieux ! on
  dirais une cascade de smartphone en 3D c'est propre
  Est ce que tu sais juste pourquoi la qualité des images se dégrade
  ?
