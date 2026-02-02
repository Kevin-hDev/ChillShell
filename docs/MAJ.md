# Mises à jour à appliquer plus tard

> Dernière vérification: 2 Février 2026

Ce fichier liste les mises à jour de dépendances à faire quand on aura le temps.

---

## ⚠️ Mises à jour majeures (Breaking Changes potentiels)

Ces packages nécessitent une refactorisation du code.

| Package | Actuel | Dernière | Notes |
|---------|--------|----------|-------|
| `flutter_riverpod` | 2.6.1 | 3.2.0 | **Grosse refacto** - API changée, tous les providers à revoir |
| `riverpod_annotation` | 2.6.1 | 4.0.1 | Lié à flutter_riverpod |
| `riverpod_generator` | 2.4.0 | 4.0.2 | Lié à flutter_riverpod |

### Plan de migration Riverpod 3.x

1. Créer une branche `upgrade-riverpod-3`
2. Lire le guide de migration : https://riverpod.dev/docs/migration/from_riverpod_2_to_3
3. Mettre à jour les packages
4. Refactoriser tous les providers
5. Tester l'app complètement
6. Merger si OK

---

## 🔄 Mises à jour moyennes

Changements d'API possibles mais généralement rétrocompatibles.

| Package | Actuel | Dernière | Notes |
|---------|--------|----------|-------|
| `flutter_secure_storage` | 9.2.4 | 10.0.0 | Vérifier les breaking changes |
| `local_auth` | 2.3.0 | 3.0.0 | Biométrie - tester FaceID/TouchID |
| `google_fonts` | 6.3.3 | 8.0.0 | Probablement safe |

---

## ✅ Mises à jour mineures (Safe)

Ces packages peuvent être mis à jour sans risque.

| Package | Actuel | Dernière | Notes |
|---------|--------|----------|-------|
| `permission_handler` | 11.4.0 | 12.0.1 | |
| `pointycastle` | 3.9.1 | 4.0.0 | Cryptographie RSA |

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
