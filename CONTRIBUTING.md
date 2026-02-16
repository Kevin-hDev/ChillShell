# Guide de Contribution

Merci de vouloir contribuer à ChillShell ! 🎉

## 📜 Code de Conduite

En contribuant, vous acceptez de respecter notre [Code de Conduite](CODE_OF_CONDUCT.md).

## 🐛 Signaler un Bug

1. **Vérifiez** que le bug n'est pas déjà signalé dans [Issues](https://github.com/Kevin-hdev/ChillShell/issues)
2. **Utilisez** le template de bug report
3. **Incluez** :
   - Version de ChillShell
   - Version d'Android
   - Étapes de reproduction
   - Comportement attendu vs. observé
   - Logs/screenshots si possible

## 💡 Proposer une Fonctionnalité

1. **Ouvrez** une Discussion GitHub d'abord (pas une Issue)
2. **Décrivez** le problème que ça résout
3. **Expliquez** votre solution proposée
4. **Attendez** les retours avant de coder

## 🔐 Signaler une Vulnérabilité de Sécurité

**N'OUVREZ PAS d'issue publique !**

⚠️ **LISEZ D'ABORD** : [⚠️\_READ\_THIS\_FIRST.md](⚠️_READ_THIS_FIRST.md) pour comprendre le contexte sécurité

Suivez la procédure dans [SECURITY.md](SECURITY.md) :
- Email à : Chill_app@outlook.fr
- Sujet : `[SECURITY] Vulnérabilité dans ChillShell`

**Documentation sécurité complète** :
- [SECURITY.md](SECURITY.md) - Mesures implémentées, audits réalisés, procédure de signalement
- [⚠️\_READ\_THIS\_FIRST.md](⚠️_READ_THIS_FIRST.md) - Avertissements, surface d'attaque, bonnes pratiques

## 🛠️ Contribuer du Code

### Setup de Développement

```bash
# 1. Fork et clone
git clone https://github.com/VOTRE-USERNAME/ChillShell.git
cd ChillShell

# 2. Installer Flutter SDK (3.x)
# Voir : https://flutter.dev/docs/get-started/install

# 3. Installer les dépendances
flutter pub get

# 4. Lancer les tests
flutter test

# 5. Lancer l'app
flutter run
```

### Workflow Git

```bash
# 1. Créer une branche
git checkout -b feature/ma-fonctionnalite

# 2. Faire vos changements
# ...

# 3. Tester
flutter test
flutter analyze

# 4. Commit (messages en français ou anglais OK)
git commit -m "feat: ajoute support pour X"

# 5. Push
git push origin feature/ma-fonctionnalite

# 6. Ouvrir une Pull Request
```

### Convention de Commits

Utilisez les préfixes :
- `feat:` - Nouvelle fonctionnalité
- `fix:` - Correction de bug
- `docs:` - Documentation uniquement
- `style:` - Formatage (pas de changement de code)
- `refactor:` - Refactoring
- `test:` - Ajout de tests
- `chore:` - Maintenance (build, config, etc.)
- `security:` - Correctif de sécurité

### Règles de Code

1. **Tests** : Tout nouveau code doit avoir des tests
2. **Analyse** : `flutter analyze` doit passer à 0 erreurs
3. **Format** : `dart format lib/` avant commit
4. **Documentation** : Documentez les fonctions publiques
5. **i18n** : Toutes les strings utilisateur doivent utiliser l10n
6. **Sécurité** : Validez TOUTES les entrées utilisateur

### Checklist Pull Request

- [ ] Tests ajoutés et passent (`flutter test`)
- [ ] `flutter analyze` passe à 0 erreurs
- [ ] Code formaté (`dart format lib/`)
- [ ] Documentation ajoutée
- [ ] CHANGELOG.md mis à jour
- [ ] Pas de secrets/clés dans le code
- [ ] Screenshots ajoutés si changement UI
- [ ] **Si changement sécurité** : SECURITY.md mis à jour si nécessaire

## 🌍 Traduction (i18n)

Pour ajouter une nouvelle langue :

1. Créez `lib/l10n/app_XX.arb` (XX = code langue)
2. Traduisez toutes les clés depuis `app_en.arb`
3. Lancez `flutter gen-l10n`
4. Testez avec `flutter run --locale=XX`

## 📝 Documentation

- **README** : Vue d'ensemble, installation
- **Wiki** : Guides détaillés, tutoriels
- **Code** : Commentaires pour code complexe
- **API** : Dartdoc pour fonctions publiques

## 🔍 Revue de Code

Toutes les PRs passent par revue :
- ✅ Code quality
- ✅ Tests coverage
- ✅ Security implications
- ✅ Performance impact
- ✅ Documentation

**Soyez patient** - c'est un projet bénévole, la revue peut prendre du temps.

## 📞 Questions ?

- 💬 [GitHub Discussions](https://github.com/Kevin-hdev/ChillShell/discussions)
- 🐛 [GitHub Issues](https://github.com/Kevin-hdev/ChillShell/issues)

Merci de contribuer ! 🙏
