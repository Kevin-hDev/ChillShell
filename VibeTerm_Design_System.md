# 🎨 VibeTerm Design System

> **Version** : 1.0  
> **Basé sur** : Mockup V5 validé  
> **Inspiré de** : Warp Terminal  
> **Dernière mise à jour** : 29 janvier 2026

Ce document contient TOUTES les informations nécessaires pour reproduire exactement le design validé dans Flutter.

---

## 1. Palette de Couleurs

### 1.1 Couleurs Principales (Thème Warp Dark)

```dart
class VibeTermColors {
  // Backgrounds
  static const Color bg = Color(0xFF0F0F0F);           // Fond principal
  static const Color bgBlock = Color(0xFF1A1A1A);      // Fond des blocs/cartes
  static const Color bgElevated = Color(0xFF222222);   // Fond éléments surélevés
  
  // Borders
  static const Color border = Color(0xFF333333);       // Bordures principales
  static const Color borderLight = Color(0xFF2A2A2A);  // Bordures légères (séparateurs internes)
  
  // Text
  static const Color text = Color(0xFFFFFFFF);         // Texte principal (commandes)
  static const Color textOutput = Color(0xFFCCCCCC);   // Texte output terminal
  static const Color textMuted = Color(0xFF888888);    // Texte secondaire/désactivé
  static const Color ghost = Color(0xFF555555);        // Ghost text (autocomplétion)
  
  // Accent
  static const Color accent = Color(0xFF10B981);       // Vert principal (emerald-500)
  static const Color accentDim = Color(0xFF065F46);    // Vert sombre (pour backgrounds)
  
  // Status
  static const Color success = Color(0xFF10B981);      // Succès (même que accent)
  static const Color danger = Color(0xFFEF4444);       // Danger/Suppression
  static const Color warning = Color(0xFFF59E0B);      // Warning
  
  // Spécifiques
  static const Color scrollThumb = Color(0xFF444444);  // Scrollbar
  static const Color homeIndicator = Color(0xFF444444); // Barre home iOS
}
```

### 1.2 Correspondance CSS → Flutter

| CSS Hex | Flutter | Usage |
|---------|---------|-------|
| `#0f0f0f` | `Color(0xFF0F0F0F)` | Background principal |
| `#1a1a1a` | `Color(0xFF1A1A1A)` | Blocs, cartes, input |
| `#222222` | `Color(0xFF222222)` | Éléments surélevés |
| `#333333` | `Color(0xFF333333)` | Bordures |
| `#2a2a2a` | `Color(0xFF2A2A2A)` | Séparateurs internes |
| `#ffffff` | `Color(0xFFFFFFFF)` | Texte principal |
| `#cccccc` | `Color(0xFFCCCCCC)` | Output terminal |
| `#888888` | `Color(0xFF888888)` | Texte muted |
| `#555555` | `Color(0xFF555555)` | Ghost text |
| `#10b981` | `Color(0xFF10B981)` | Accent vert |
| `#065f46` | `Color(0xFF065F46)` | Accent dim (40% opacity pour bg) |

---

## 2. Typographie

### 2.1 Police Principale

```dart
// Utiliser Google Fonts
import 'package:google_fonts/google_fonts.dart';

final terminalTextStyle = GoogleFonts.jetBrainsMono();
// Alternative: GoogleFonts.firaCode()
```

### 2.2 Tailles de Police

| Élément | Taille | Weight | Couleur |
|---------|--------|--------|---------|
| Titre app (VibeTerm) | 16px | 600 (semibold) | `text` |
| Sous-titre header | 11-12px | 400 | `accent` |
| Onglet actif | 12px | 400 | `text` |
| Onglet inactif | 12px | 400 | `textMuted` |
| Info session (tmux) | 11px | 400 | `textMuted` / `text` |
| Commande (header bloc) | 13px | 400 | `text` |
| Temps exécution | 11px | 400 | `#666666` |
| Output terminal | 12px | 400 | `textOutput` |
| Placeholder input | 14px | 400 | `textMuted` |
| Input text | 14px | 400 | `text` |
| Ghost text | 14px | 400 | `ghost` |
| Prompt (❯) | 16px | 500 | `accent` |
| Titre Settings | 20px | 600 | `text` |
| Sous-titre Settings | 13px | 400 | `textMuted` |
| Label section | 14px | 500 | `text` |
| Item liste | 13px | 500 | `text` |
| Item description | 11px | 400 | `textMuted` |
| Badge (ED25519) | 10px | 400 uppercase | `accent` |
| Toggle label | 13px | 400 | `textOutput` |

### 2.3 Line Height

```dart
// Output terminal
lineHeight: 1.5

// Texte général
lineHeight: 1.4
```

---

## 3. Spacing & Layout

### 3.1 Padding Standards

```dart
class VibeTermSpacing {
  // Padding écran global
  static const double screenPadding = 12.0;
  
  // Header
  static const double headerPaddingH = 16.0;
  static const double headerPaddingV = 12.0;
  
  // Onglets
  static const double tabBarPadding = 8.0;
  static const double tabItemPaddingH = 12.0;
  static const double tabItemPaddingV = 8.0;
  static const double tabGap = 8.0;
  
  // Blocs de commande
  static const double blockPadding = 12.0;
  static const double blockHeaderPaddingH = 12.0;
  static const double blockHeaderPaddingV = 10.0;
  static const double blockGap = 12.0;
  
  // Input zone
  static const double inputPadding = 12.0;
  static const double inputInternalGap = 8.0;
  
  // Settings
  static const double sectionGap = 24.0;
  static const double itemGap = 8.0;
  static const double cardPadding = 12.0;
}
```

### 3.2 Border Radius

```dart
class VibeTermRadius {
  static const double small = 4.0;     // Badges, petits éléments
  static const double medium = 6.0;    // Boutons, toggles
  static const double large = 8.0;     // Blocs, cartes, inputs
  static const double xl = 12.0;       // Logo, gros boutons
}
```

### 3.3 Tailles Fixes

```dart
// Header
logoSize: 40.0
buttonSize: 36.0

// Onglets
indicatorDot: 6.0
addButtonSize: 32.0

// Input
sendButtonSize: 40.0
completeButtonPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6)

// Settings
toggleWidth: 44.0
toggleHeight: 24.0
toggleThumbSize: 20.0
actionButtonSize: 32.0

// Indicateurs
statusDot: 8.0 (header) / 6.0 (onglets)
```

---

## 4. Composants

### 4.1 Header Principal

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: VibeTermColors.bg,
    border: Border(
      bottom: BorderSide(color: VibeTermColors.border, width: 1),
    ),
  ),
  child: Row(
    children: [
      // Logo
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10B981), Color(0xFF0D9488)],
          ),
        ),
        child: Center(child: Text('⌘', style: TextStyle(fontSize: 18))),
      ),
      SizedBox(width: 12),
      // Titre
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VibeTerm', style: TextStyle(
            color: VibeTermColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          )),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: VibeTermColors.accent,
                shape: BoxShape.circle,
              )),
              SizedBox(width: 6),
              Text('workstation.local', style: TextStyle(
                color: VibeTermColors.accent,
                fontSize: 11,
              )),
            ],
          ),
        ],
      ),
      Spacer(),
      // Boutons navigation
      _NavButton(icon: Icons.terminal, isActive: true),
      SizedBox(width: 8),
      _NavButton(icon: Icons.settings, isActive: false),
    ],
  ),
)
```

### 4.2 Barre d'Onglets

```dart
Container(
  padding: EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: VibeTermColors.bgBlock,
    border: Border(
      bottom: BorderSide(color: VibeTermColors.border, width: 1),
    ),
  ),
  child: Row(
    children: [
      // Zone scrollable (Expanded)
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: BouncingScrollPhysics(), // iOS-like
          // PAS DE SCROLLBAR
          child: Row(
            children: tabs.map((tab) => _TabItem(tab)).toList(),
          ),
        ),
      ),
      SizedBox(width: 8),
      // Bouton + (toujours visible, discret)
      GestureDetector(
        onTap: () => addTab(),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('+', style: TextStyle(
              color: VibeTermColors.textMuted,
              fontSize: 18,
            )),
          ),
        ),
      ),
    ],
  ),
)
```

### 4.3 Onglet Item

```dart
// Onglet actif
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    color: VibeTermColors.accentDim.withOpacity(0.25), // ~40%
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: VibeTermColors.accent, width: 1),
  ),
  child: Row(
    children: [
      Container(
        width: 6, height: 6,
        decoration: BoxDecoration(
          color: isConnected ? VibeTermColors.accent : VibeTermColors.textMuted,
          shape: BoxShape.circle,
        ),
      ),
      SizedBox(width: 6),
      Text(name, style: TextStyle(
        color: VibeTermColors.text,
        fontSize: 12,
      )),
    ],
  ),
)

// Onglet inactif
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: Colors.transparent, width: 1),
  ),
  child: Row(
    children: [
      Container(
        width: 6, height: 6,
        decoration: BoxDecoration(
          color: isConnected ? VibeTermColors.accent : VibeTermColors.textMuted,
          shape: BoxShape.circle,
        ),
      ),
      SizedBox(width: 6),
      Text(name, style: TextStyle(
        color: VibeTermColors.textMuted,
        fontSize: 12,
      )),
    ],
  ),
)
```

### 4.4 Barre Info Session

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  decoration: BoxDecoration(
    color: VibeTermColors.bg,
    border: Border(
      bottom: BorderSide(color: VibeTermColors.border, width: 1),
    ),
  ),
  child: Row(
    children: [
      Text('⚡', style: TextStyle(color: VibeTermColors.accent, fontSize: 12)),
      SizedBox(width: 8),
      Text.rich(
        TextSpan(
          style: TextStyle(color: VibeTermColors.textMuted, fontSize: 11),
          children: [
            TextSpan(text: 'tmux: '),
            TextSpan(text: 'vibe', style: TextStyle(color: VibeTermColors.text)),
            TextSpan(text: ' • workstation.local'),
          ],
        ),
      ),
      Spacer(),
      Text('Tailscale', style: TextStyle(
        color: VibeTermColors.textMuted,
        fontSize: 11,
      )),
    ],
  ),
)
```

### 4.5 Bloc de Commande

```dart
Container(
  margin: EdgeInsets.only(bottom: 12),
  decoration: BoxDecoration(
    color: VibeTermColors.bgBlock,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: VibeTermColors.border, width: 1),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Header
      Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: VibeTermColors.borderLight, width: 1),
          ),
        ),
        child: Row(
          children: [
            Text('❯', style: TextStyle(
              color: VibeTermColors.accent,
              fontSize: 14,
            )),
            SizedBox(width: 8),
            Expanded(
              child: Text(command, style: TextStyle(
                color: VibeTermColors.text,
                fontSize: 13,
                fontFamily: 'JetBrains Mono',
              )),
            ),
            Text(time, style: TextStyle(
              color: Color(0xFF666666),
              fontSize: 11,
            )),
          ],
        ),
      ),
      // Output
      Padding(
        padding: EdgeInsets.all(12),
        child: Text(output, style: TextStyle(
          color: VibeTermColors.textOutput,
          fontSize: 12,
          height: 1.5,
          fontFamily: 'JetBrains Mono',
        )),
      ),
    ],
  ),
)
```

### 4.6 Zone d'Input (Bottom)

```dart
Positioned(
  bottom: 0,
  left: 0,
  right: 0,
  child: Container(
    padding: EdgeInsets.all(12),
    paddingBottom: 32, // Pour home indicator
    decoration: BoxDecoration(
      color: VibeTermColors.bg,
      border: Border(
        top: BorderSide(color: VibeTermColors.border, width: 1),
      ),
    ),
    child: Container(
      decoration: BoxDecoration(
        color: VibeTermColors.bgBlock,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VibeTermColors.border, width: 1),
      ),
      child: Row(
        children: [
          SizedBox(width: 12),
          // Prompt
          Text('❯', style: TextStyle(
            color: VibeTermColors.accent,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          )),
          SizedBox(width: 8),
          // Input field avec ghost text
          Expanded(
            child: Stack(
              children: [
                // Ghost text layer
                Row(
                  children: [
                    Text(inputValue, style: TextStyle(
                      color: VibeTermColors.text,
                      fontSize: 14,
                    )),
                    Text(ghostText, style: TextStyle(
                      color: VibeTermColors.ghost,
                      fontSize: 14,
                    )),
                  ],
                ),
                // Real input
                TextField(
                  style: TextStyle(
                    color: VibeTermColors.text,
                    fontSize: 14,
                  ),
                  cursorColor: VibeTermColors.accent,
                  decoration: InputDecoration(
                    hintText: 'Run commands',
                    hintStyle: TextStyle(color: VibeTermColors.textMuted),
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
          // Bouton compléter (si ghost text)
          if (hasGhostText) ...[
            GestureDetector(
              onTap: acceptCompletion,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: VibeTermColors.border),
                ),
                child: Text('→', style: TextStyle(
                  color: VibeTermColors.textMuted,
                )),
              ),
            ),
            SizedBox(width: 8),
          ],
          // Bouton envoi
          GestureDetector(
            onTap: sendCommand,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: VibeTermColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.arrow_upward, color: Colors.white),
            ),
          ),
          SizedBox(width: 12),
        ],
      ),
    ),
  ),
)
```

### 4.7 Toggle Switch (Settings)

```dart
GestureDetector(
  onTap: () => toggle(),
  child: Container(
    width: 44,
    height: 24,
    padding: EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: isOn ? VibeTermColors.accent : VibeTermColors.border,
      borderRadius: BorderRadius.circular(12),
    ),
    child: AnimatedAlign(
      duration: Duration(milliseconds: 200),
      alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    ),
  ),
)
```

### 4.8 Carte Clé SSH (Settings)

```dart
Container(
  padding: EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: VibeTermColors.bgBlock,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: VibeTermColors.border),
  ),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(keyName, style: TextStyle(
                  color: VibeTermColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                )),
                SizedBox(width: 8),
                // Badge type
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: VibeTermColors.accentDim.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(keyType.toUpperCase(), style: TextStyle(
                    color: VibeTermColors.accent,
                    fontSize: 10,
                  )),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text('$host • Utilisée $lastUsed', style: TextStyle(
              color: VibeTermColors.textMuted,
              fontSize: 11,
            )),
          ],
        ),
      ),
      // Boutons action
      _ActionButton(icon: Icons.edit, onTap: edit),
      SizedBox(width: 8),
      _ActionButton(icon: Icons.delete, color: VibeTermColors.danger, onTap: delete),
    ],
  ),
)

// Action button
Container(
  width: 32,
  height: 32,
  decoration: BoxDecoration(
    color: VibeTermColors.bgElevated,
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: VibeTermColors.border),
  ),
  child: Icon(icon, size: 14, color: color ?? VibeTermColors.textMuted),
)
```

### 4.9 Sélecteur de Thème (Settings)

```dart
Row(
  children: themes.map((theme) => Expanded(
    child: GestureDetector(
      onTap: () => selectTheme(theme),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: theme.bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? VibeTermColors.accent : VibeTermColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(theme.name, style: TextStyle(
            color: Colors.white,
            fontSize: 11,
          )),
        ),
      ),
    ),
  )).toList(),
)
```

---

## 5. Animations & Transitions

### 5.1 Durées Standard

```dart
class VibeTermAnimations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
}
```

### 5.2 Animations Spécifiques

```dart
// Apparition des blocs de commande
SlideTransition + FadeTransition
  offset: Offset(0, 0.1) → Offset(0, 0)
  duration: 200ms
  curve: Curves.easeOut

// Toggle switch
AnimatedAlign
  duration: 200ms

// Changement d'onglet
color transition: 150ms

// Boutons hover/press
opacity ou color: 150ms
```

---

## 6. Gestes Tactiles

| Geste | Élément | Action |
|-------|---------|--------|
| Tap | Onglet | Switch de session |
| Tap | Bouton + | Nouvelle session |
| Tap | Bouton ↑ | Envoyer commande |
| Tap | Bouton → | Accepter autocomplétion |
| Swipe → | Zone input | Accepter autocomplétion |
| Swipe horizontal | Zone onglets | Scroll entre onglets |
| Scroll vertical | Zone terminal | Navigation dans l'historique |
| Tap | Toggle | Activer/désactiver option |
| Tap | Carte clé SSH | (optionnel) Détails |
| Tap | Bouton ✏️ | Éditer clé |
| Tap | Bouton 🗑️ | Supprimer clé |

---

## 7. Hiérarchie Z-Index

```
1. Background (bg: #0f0f0f)
2. Contenu scrollable (blocs de commande)
3. Header fixe (top)
4. Zone input fixe (bottom)
5. Modals / Dialogs (si ajoutés)
```

---

## 8. Responsive Considerations

Bien que l'app soit mobile-first, prévoir :

```dart
// Largeur max pour tablettes
maxWidth: 500.0 // Centré sur tablette

// Breakpoints suggérés
phone: < 600px
tablet: >= 600px
```

---

## 9. Thèmes Additionnels (Référence)

### Dracula
```dart
bg: Color(0xFF282A36)
bgBlock: Color(0xFF343746)
border: Color(0xFF44475A)
text: Color(0xFFF8F8F2)
accent: Color(0xFFBD93F9) // Purple
```

### Nord
```dart
bg: Color(0xFF2E3440)
bgBlock: Color(0xFF3B4252)
border: Color(0xFF434C5E)
text: Color(0xFFECEFF4)
accent: Color(0xFF88C0D0) // Frost blue
```

---

## 10. Assets & Icônes

### Icônes utilisées (Material Icons ou équivalent)
- `terminal` ou `keyboard` → Navigation terminal
- `settings` → Navigation settings
- `edit` → Éditer
- `delete` → Supprimer
- `arrow_upward` → Envoyer
- `chevron_right` ou `→` → Compléter
- `add` ou `+` → Ajouter

### Emojis utilisés
- ⌘ → Logo app
- ❯ → Prompt terminal
- 🔑 → Section clés SSH
- ⚡ → Connexions rapides / Info session
- 🎨 → Apparence
- 🔒 → Sécurité
- ⚙️ → Settings
- ⌨️ → Terminal
- 📁 → Dossier (si utilisé)
- ✏️ → Éditer
- 🗑️ → Supprimer

---

## 11. Checklist Implémentation

- [ ] Configurer les couleurs dans un fichier `theme.dart`
- [ ] Configurer la typographie (JetBrains Mono via google_fonts)
- [ ] Créer les widgets réutilisables :
  - [ ] `VibeTermHeader`
  - [ ] `TabBar` custom avec scroll tactile
  - [ ] `TabItem`
  - [ ] `SessionInfoBar`
  - [ ] `CommandBlock`
  - [ ] `GhostTextInput`
  - [ ] `SendButton`
  - [ ] `ToggleSwitch`
  - [ ] `SSHKeyCard`
  - [ ] `ThemeSelector`
  - [ ] `SectionHeader`
  - [ ] `SettingsCard`
- [ ] Implémenter les animations
- [ ] Tester les gestes tactiles
- [ ] Valider sur iOS et Android

