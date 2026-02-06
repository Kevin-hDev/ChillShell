# Mises à jour à appliquer plus tard

> Dernière vérification: 6 Février 2026

Ce fichier liste les mises à jour de dépendances à faire quand on aura le temps.

---

## ✅ Migration Riverpod 3 (FAIT - 6 Fév 2026)

| Package | Avant | Après | Notes |
|---------|-------|-------|-------|
| `flutter_riverpod` | 2.6.1 | 3.2.1 | StateNotifier → Notifier (6 fichiers providers + 3 fichiers UI) |
| `riverpod_annotation` | 2.6.1 | — | Supprimé (pas utilisé dans le code) |
| `riverpod_generator` | 2.4.0 | — | Supprimé (pas utilisé dans le code, aucun @riverpod) |
| `build_runner` | 2.4.13 | — | Supprimé (plus nécessaire sans riverpod_generator) |
| `custom_lint` | 0.5.11 | — | Supprimé (conflit analyzer avec Riverpod 3) |

---

## ✅ Mises à jour moyennes (FAIT - 6 Fév 2026)

| Package | Avant | Après | Notes |
|---------|-------|-------|-------|
| `flutter_secure_storage` | 9.2.4 | 10.0.0 | Supprimé `encryptedSharedPreferences` (4 fichiers) |
| `local_auth` | 2.3.0 | 3.0.0 | Migré `AuthenticationOptions` → params individuels |
| `google_fonts` | 6.3.3 | 8.0.1 | Aucun changement de code |
| `file_picker` | 8.3.7 | 10.3.10 | Aucun changement de code |
| `flutter_lints` | 3.0.2 | 6.0.0 | Corrigé 4 nouveaux warnings lint |

---

## ⏳ Mises à jour bloquées

| Package | Actuel | Dernière | Raison |
|---------|--------|----------|--------|
| `pointycastle` | 3.9.1 | 4.0.0 | Bloqué par dartssh2 (contrainte `^3.7.3`) |

## 🗑️ Supprimé (6 Fév 2026)

| Package | Notes |
|---------|-------|
| `permission_handler` | Inutilisé - aucun import dans le code |
| `riverpod_annotation` | Pas utilisé (aucun @riverpod dans le code) |
| `riverpod_generator` | Pas utilisé (aucun .g.dart généré) |
| `build_runner` | Plus nécessaire sans riverpod_generator |
| `custom_lint` | Incompatible avec Riverpod 3 (conflit analyzer) |

---

## 🗑️ Packages dépréciés

Ces packages sont marqués comme "discontinued" par leurs auteurs.

| Package | Remplacement |
|---------|--------------|
| `js` | Utiliser `dart:js_interop` |
| `build_resolvers` | Intégré dans build_runner |
| `build_runner_core` | Intégré dans build_runner |

---

## Commandes utiles

```bash
# Voir les packages outdated
flutter pub outdated

# Mettre à jour les packages mineurs (safe)
flutter pub upgrade

# Mettre à jour avec les majeures (attention!)
flutter pub upgrade --major-versions

# Vérifier que tout compile
flutter analyze lib/
flutter build apk --debug
```

---

## Notes

- **Ne jamais faire de mise à jour majeure avant un test important**
- **Toujours créer une branche pour les mises à jour majeures**
- **Tester sur Android ET iOS après chaque mise à jour**
