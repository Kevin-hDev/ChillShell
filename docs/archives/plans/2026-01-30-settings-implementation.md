# Settings Screen - Implementation Plan

> **Pour Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implémenter l'écran Settings complet avec gestion SSH, connexions, thèmes et sécurité.

**Architecture:** Feature-first avec Riverpod, écran scrollable avec sections.

**Tech Stack:** Flutter, Riverpod, flutter_secure_storage, local_auth

---

## Task 1: Settings Provider et État

**Files:**
- Create: `lib/features/settings/providers/settings_provider.dart`
- Modify: `lib/features/terminal/providers/providers.dart` (export)

**Step 1: Créer le provider settings**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/models.dart';

class SettingsState {
  final List<SSHKey> sshKeys;
  final AppSettings appSettings;
  final bool isLoading;

  const SettingsState({
    this.sshKeys = const [],
    required this.appSettings,
    this.isLoading = false,
  });

  SettingsState copyWith({
    List<SSHKey>? sshKeys,
    AppSettings? appSettings,
    bool? isLoading,
  }) {
    return SettingsState(
      sshKeys: sshKeys ?? this.sshKeys,
      appSettings: appSettings ?? this.appSettings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(SettingsState(appSettings: AppSettings()));

  void addSSHKey(SSHKey key) {
    state = state.copyWith(sshKeys: [...state.sshKeys, key]);
  }

  void removeSSHKey(String id) {
    state = state.copyWith(
      sshKeys: state.sshKeys.where((k) => k.id != id).toList(),
    );
  }

  void updateTheme(String theme) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(theme: theme),
    );
  }

  void toggleBiometric(bool enabled) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(biometricEnabled: enabled),
    );
  }

  void toggleAutoLock(bool enabled) {
    state = state.copyWith(
      appSettings: state.appSettings.copyWith(autoLockEnabled: enabled),
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) => SettingsNotifier(),
);
```

**Step 2: Commit**
```bash
git add lib/features/settings/
git commit -m "feat(settings): add settings provider and state"
```

---

## Task 2: Settings Screen Structure

**Files:**
- Create: `lib/features/settings/screens/settings_screen.dart`

**Step 1: Créer l'écran principal**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../shared/widgets/app_header.dart';
import '../widgets/ssh_keys_section.dart';
import '../widgets/quick_connections_section.dart';
import '../widgets/appearance_section.dart';
import '../widgets/security_section.dart';

class SettingsScreen extends ConsumerWidget {
  final VoidCallback? onTerminalTap;

  const SettingsScreen({super.key, this.onTerminalTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: VibeTermColors.bg,
      body: Column(
        children: [
          AppHeader(
            isTerminalActive: false,
            onTerminalTap: onTerminalTap,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(VibeTermSpacing.md),
              children: const [
                SSHKeysSection(),
                SizedBox(height: VibeTermSpacing.lg),
                QuickConnectionsSection(),
                SizedBox(height: VibeTermSpacing.lg),
                AppearanceSection(),
                SizedBox(height: VibeTermSpacing.lg),
                SecuritySection(),
                SizedBox(height: VibeTermSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**
```bash
git add lib/features/settings/screens/
git commit -m "feat(settings): add settings screen structure"
```

---

## Task 3: SSH Keys Section Widget

**Files:**
- Create: `lib/features/settings/widgets/ssh_keys_section.dart`

**Step 1: Créer le widget section clés SSH**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../providers/settings_provider.dart';
import 'section_header.dart';
import 'ssh_key_tile.dart';
import 'add_ssh_key_sheet.dart';

class SSHKeysSection extends ConsumerWidget {
  const SSHKeysSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'CLÉS SSH',
          trailing: IconButton(
            icon: const Icon(Icons.add, color: VibeTermColors.accent),
            onPressed: () => _showAddKeySheet(context),
          ),
        ),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: VibeTermColors.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: VibeTermColors.border),
          ),
          child: settings.sshKeys.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(VibeTermSpacing.md),
                  child: Text(
                    'Aucune clé SSH',
                    style: VibeTermTypography.caption,
                  ),
                )
              : Column(
                  children: settings.sshKeys
                      .map((key) => SSHKeyTile(sshKey: key))
                      .toList(),
                ),
        ),
      ],
    );
  }

  void _showAddKeySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VibeTermColors.bgBlock,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const AddSSHKeySheet(),
    );
  }
}
```

**Step 2: Commit**
```bash
git add lib/features/settings/widgets/ssh_keys_section.dart
git commit -m "feat(settings): add SSH keys section widget"
```

---

## Task 4: Section Header + SSH Key Tile Widgets

**Files:**
- Create: `lib/features/settings/widgets/section_header.dart`
- Create: `lib/features/settings/widgets/ssh_key_tile.dart`

**Step 1: Section Header**

```dart
import 'package:flutter/material.dart';
import '../../../core/theme/typography.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: VibeTermTypography.sectionLabel),
        if (trailing != null) trailing!,
      ],
    );
  }
}
```

**Step 2: SSH Key Tile**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../models/models.dart';
import '../providers/settings_provider.dart';

class SSHKeyTile extends ConsumerWidget {
  final SSHKey sshKey;

  const SSHKeyTile({super.key, required this.sshKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(sshKey.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: VibeTermColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: VibeTermSpacing.md),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) => _confirmDelete(context),
      onDismissed: (direction) {
        ref.read(settingsProvider.notifier).removeSSHKey(sshKey.id);
      },
      child: ListTile(
        leading: const Icon(Icons.key, color: VibeTermColors.accent),
        title: Text(sshKey.name, style: VibeTermTypography.itemTitle),
        subtitle: Text(
          '${sshKey.type} • ${_formatDate(sshKey.createdAt)}',
          style: VibeTermTypography.itemDescription,
        ),
        onTap: () => _showKeyDetails(context),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VibeTermColors.bgBlock,
        title: Text('Supprimer la clé ?', style: VibeTermTypography.settingsTitle),
        content: Text(
          'Cette action est irréversible.',
          style: VibeTermTypography.itemDescription,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: VibeTermColors.error)),
          ),
        ],
      ),
    );
  }

  void _showKeyDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VibeTermColors.bgBlock,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(VibeTermSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sshKey.name, style: VibeTermTypography.settingsTitle),
            const SizedBox(height: VibeTermSpacing.sm),
            Text('Type: ${sshKey.type}', style: VibeTermTypography.itemDescription),
            const SizedBox(height: VibeTermSpacing.md),
            Text('Clé publique:', style: VibeTermTypography.sectionLabel),
            const SizedBox(height: VibeTermSpacing.xs),
            Container(
              padding: const EdgeInsets.all(VibeTermSpacing.sm),
              decoration: BoxDecoration(
                color: VibeTermColors.bg,
                borderRadius: BorderRadius.circular(VibeTermRadius.sm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sshKey.publicKey,
                      style: VibeTermTypography.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    color: VibeTermColors.accent,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: sshKey.publicKey));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Clé copiée !')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: VibeTermSpacing.lg),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
```

**Step 3: Commit**
```bash
git add lib/features/settings/widgets/
git commit -m "feat(settings): add section header and SSH key tile widgets"
```

---

## Task 5: Add SSH Key Bottom Sheet

**Files:**
- Create: `lib/features/settings/widgets/add_ssh_key_sheet.dart`

**Step 1: Créer le bottom sheet d'ajout**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../models/models.dart';
import '../providers/settings_provider.dart';

class AddSSHKeySheet extends ConsumerStatefulWidget {
  const AddSSHKeySheet({super.key});

  @override
  ConsumerState<AddSSHKeySheet> createState() => _AddSSHKeySheetState();
}

class _AddSSHKeySheetState extends ConsumerState<AddSSHKeySheet> {
  bool _showGenerateForm = false;
  final _nameController = TextEditingController();
  String _selectedType = 'Ed25519';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: VibeTermSpacing.md,
        right: VibeTermSpacing.md,
        top: VibeTermSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + VibeTermSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ajouter une clé SSH', style: VibeTermTypography.settingsTitle),
          const SizedBox(height: VibeTermSpacing.md),
          if (!_showGenerateForm) ...[
            _OptionTile(
              icon: Icons.file_upload,
              title: 'Importer une clé',
              subtitle: 'Depuis un fichier .pem ou .pub',
              onTap: _importKey,
            ),
            const SizedBox(height: VibeTermSpacing.sm),
            _OptionTile(
              icon: Icons.auto_fix_high,
              title: 'Générer une clé',
              subtitle: 'Créer une nouvelle paire de clés',
              onTap: () => setState(() => _showGenerateForm = true),
            ),
          ] else ...[
            _buildGenerateForm(),
          ],
          const SizedBox(height: VibeTermSpacing.md),
        ],
      ),
    );
  }

  Widget _buildGenerateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          style: VibeTermTypography.input,
          decoration: InputDecoration(
            labelText: 'Nom de la clé',
            labelStyle: VibeTermTypography.caption,
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: VibeTermColors.border),
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: VibeTermColors.accent),
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            ),
          ),
        ),
        const SizedBox(height: VibeTermSpacing.md),
        Text('Type de clé', style: VibeTermTypography.sectionLabel),
        const SizedBox(height: VibeTermSpacing.xs),
        Row(
          children: [
            _TypeChip(
              label: 'Ed25519',
              isSelected: _selectedType == 'Ed25519',
              onTap: () => setState(() => _selectedType = 'Ed25519'),
            ),
            const SizedBox(width: VibeTermSpacing.sm),
            _TypeChip(
              label: 'RSA 4096',
              isSelected: _selectedType == 'RSA 4096',
              onTap: () => setState(() => _selectedType = 'RSA 4096'),
            ),
          ],
        ),
        const SizedBox(height: VibeTermSpacing.md),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(() => _showGenerateForm = false),
              child: const Text('Retour'),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: VibeTermColors.accent,
                foregroundColor: VibeTermColors.bg,
              ),
              onPressed: _generateKey,
              child: const Text('Générer'),
            ),
          ],
        ),
      ],
    );
  }

  void _importKey() {
    // TODO: Implement file picker
    Navigator.pop(context);
  }

  void _generateKey() {
    if (_nameController.text.trim().isEmpty) return;

    final newKey = SSHKey(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      type: _selectedType,
      publicKey: 'ssh-ed25519 AAAA... (généré)',
      privateKey: '-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----',
      createdAt: DateTime.now(),
    );

    ref.read(settingsProvider.notifier).addSSHKey(newKey);
    Navigator.pop(context);
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(VibeTermSpacing.md),
        decoration: BoxDecoration(
          color: VibeTermColors.bg,
          borderRadius: BorderRadius.circular(VibeTermRadius.md),
          border: Border.all(color: VibeTermColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: VibeTermColors.accent),
            const SizedBox(width: VibeTermSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: VibeTermTypography.itemTitle),
                Text(subtitle, style: VibeTermTypography.itemDescription),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: VibeTermSpacing.md,
          vertical: VibeTermSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? VibeTermColors.accent : VibeTermColors.bg,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          border: Border.all(
            color: isSelected ? VibeTermColors.accent : VibeTermColors.border,
          ),
        ),
        child: Text(
          label,
          style: VibeTermTypography.caption.copyWith(
            color: isSelected ? VibeTermColors.bg : VibeTermColors.text,
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Commit**
```bash
git add lib/features/settings/widgets/add_ssh_key_sheet.dart
git commit -m "feat(settings): add SSH key creation bottom sheet"
```

---

## Task 6: Quick Connections Section

**Files:**
- Create: `lib/features/settings/widgets/quick_connections_section.dart`

**Step 1: Créer la section connexions rapides**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../features/terminal/providers/providers.dart';
import 'section_header.dart';

class QuickConnectionsSection extends ConsumerWidget {
  const QuickConnectionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'CONNEXIONS RAPIDES'),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: VibeTermColors.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: VibeTermColors.border),
          ),
          child: sessions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(VibeTermSpacing.md),
                  child: Text(
                    'Aucune connexion sauvegardée',
                    style: VibeTermTypography.caption,
                  ),
                )
              : Column(
                  children: sessions.map((session) {
                    return ListTile(
                      leading: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: session.isQuickAccess
                              ? VibeTermColors.success
                              : VibeTermColors.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      title: Text(session.name, style: VibeTermTypography.itemTitle),
                      subtitle: Text(
                        '${session.username}@${session.host}:${session.port}',
                        style: VibeTermTypography.itemDescription,
                      ),
                      trailing: Switch(
                        value: session.isQuickAccess,
                        activeColor: VibeTermColors.accent,
                        onChanged: (value) {
                          ref.read(sessionsProvider.notifier).toggleQuickAccess(session.id);
                        },
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
```

**Step 2: Commit**
```bash
git add lib/features/settings/widgets/quick_connections_section.dart
git commit -m "feat(settings): add quick connections section"
```

---

## Task 7: Appearance Section

**Files:**
- Create: `lib/features/settings/widgets/appearance_section.dart`

**Step 1: Créer la section apparence**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../providers/settings_provider.dart';
import 'section_header.dart';

class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final currentTheme = settings.appSettings.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'APPARENCE'),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          padding: const EdgeInsets.all(VibeTermSpacing.md),
          decoration: BoxDecoration(
            color: VibeTermColors.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: VibeTermColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Thème', style: VibeTermTypography.sectionLabel),
              const SizedBox(height: VibeTermSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ThemePreview(
                    name: 'Warp Dark',
                    bgColor: const Color(0xFF0F0F0F),
                    accentColor: const Color(0xFF10B981),
                    isSelected: currentTheme == 'warp_dark',
                    onTap: () => ref.read(settingsProvider.notifier).updateTheme('warp_dark'),
                  ),
                  _ThemePreview(
                    name: 'Dracula',
                    bgColor: const Color(0xFF282A36),
                    accentColor: const Color(0xFFBD93F9),
                    isSelected: currentTheme == 'dracula',
                    onTap: () => ref.read(settingsProvider.notifier).updateTheme('dracula'),
                  ),
                  _ThemePreview(
                    name: 'Nord',
                    bgColor: const Color(0xFF2E3440),
                    accentColor: const Color(0xFF88C0D0),
                    isSelected: currentTheme == 'nord',
                    onTap: () => ref.read(settingsProvider.notifier).updateTheme('nord'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemePreview extends StatelessWidget {
  final String name;
  final Color bgColor;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemePreview({
    required this.name,
    required this.bgColor,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
              border: Border.all(
                color: isSelected ? accentColor : VibeTermColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 50,
                  height: 3,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 30,
                  height: 3,
                  color: Colors.white.withOpacity(0.2),
                ),
              ],
            ),
          ),
          const SizedBox(height: VibeTermSpacing.xs),
          Text(
            name,
            style: VibeTermTypography.caption.copyWith(
              color: isSelected ? VibeTermColors.accent : VibeTermColors.textMuted,
            ),
          ),
          if (isSelected)
            const Icon(Icons.check, color: VibeTermColors.accent, size: 16),
        ],
      ),
    );
  }
}
```

**Step 2: Commit**
```bash
git add lib/features/settings/widgets/appearance_section.dart
git commit -m "feat(settings): add appearance/theme section"
```

---

## Task 8: Security Section

**Files:**
- Create: `lib/features/settings/widgets/security_section.dart`

**Step 1: Créer la section sécurité**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../providers/settings_provider.dart';
import 'section_header.dart';

class SecuritySection extends ConsumerWidget {
  const SecuritySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'SÉCURITÉ'),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: VibeTermColors.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: VibeTermColors.border),
          ),
          child: Column(
            children: [
              _SecurityToggle(
                title: 'Déverrouillage biométrique',
                subtitle: 'Face ID / Empreinte digitale',
                value: settings.appSettings.biometricEnabled,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).toggleBiometric(value);
                },
              ),
              const Divider(color: VibeTermColors.borderLight, height: 1),
              _SecurityToggle(
                title: 'Verrouillage automatique',
                subtitle: 'Après 5 minutes d\'inactivité',
                value: settings.appSettings.autoLockEnabled,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).toggleAutoLock(value);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SecurityToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SecurityToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: VibeTermTypography.itemTitle),
      subtitle: Text(subtitle, style: VibeTermTypography.itemDescription),
      trailing: Switch(
        value: value,
        activeColor: VibeTermColors.accent,
        onChanged: onChanged,
      ),
    );
  }
}
```

**Step 2: Commit**
```bash
git add lib/features/settings/widgets/security_section.dart
git commit -m "feat(settings): add security section"
```

---

## Task 9: Update Models and Integrate Navigation

**Files:**
- Modify: `lib/models/session.dart` - add isQuickAccess field
- Modify: `lib/features/terminal/providers/sessions_provider.dart` - add toggleQuickAccess
- Modify: `lib/app.dart` or main navigation - add Settings screen routing

**Step 1: Update Session model**

Add `isQuickAccess` field to Session class.

**Step 2: Update SessionsNotifier**

Add `toggleQuickAccess(String id)` method.

**Step 3: Wire up navigation**

Connect AppHeader Settings button to SettingsScreen.

**Step 4: Commit**
```bash
git add .
git commit -m "feat(settings): integrate settings screen with navigation"
```

---

## Task 10: Final Integration Test

**Steps:**
1. Run `flutter analyze` - fix any issues
2. Run app on device/emulator
3. Test navigation Terminal ↔ Settings
4. Test adding SSH key (generate)
5. Test theme switching
6. Test security toggles

**Final Commit:**
```bash
git add .
git commit -m "feat(settings): complete settings screen implementation"
```
