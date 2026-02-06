import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../../models/models.dart';
import '../../../services/key_generation_service.dart';
import '../../../services/secure_storage_service.dart';
import '../providers/settings_provider.dart';

class AddSSHKeySheet extends ConsumerStatefulWidget {
  const AddSSHKeySheet({super.key});

  @override
  ConsumerState<AddSSHKeySheet> createState() => _AddSSHKeySheetState();
}

class _AddSSHKeySheetState extends ConsumerState<AddSSHKeySheet> {
  bool _showGenerateForm = false;
  bool _showImportForm = false;
  bool _isGenerating = false;
  bool _isImporting = false;
  String? _generatedPublicKey;
  final _nameController = TextEditingController();
  final _importNameController = TextEditingController();
  final _privateKeyController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _importNameController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = ref.watch(vibeTermThemeProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: VibeTermSpacing.md,
        right: VibeTermSpacing.md,
        top: VibeTermSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + VibeTermSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.sshKeys, style: VibeTermTypography.settingsTitle.copyWith(color: theme.text)),
            const SizedBox(height: VibeTermSpacing.md),
            if (!_showGenerateForm && !_showImportForm) ...[
              _OptionTile(
                icon: Icons.add_circle_outline,
                title: l10n.createSshKey,
                subtitle: 'Ed25519',
                onTap: () => setState(() => _showGenerateForm = true),
                theme: theme,
              ),
              const SizedBox(height: VibeTermSpacing.sm),
              _OptionTile(
                icon: Icons.file_upload,
                title: l10n.importKey,
                subtitle: l10n.importKeySubtitle,
                onTap: () => setState(() => _showImportForm = true),
                theme: theme,
              ),
            ] else if (_showGenerateForm) ...[
              _buildGenerateForm(context, theme),
            ] else if (_showImportForm) ...[
              _buildImportForm(context, theme),
            ],
            const SizedBox(height: VibeTermSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateForm(BuildContext context, VibeTermThemeData theme) {
    final l10n = context.l10n;
    if (_generatedPublicKey != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: theme.success),
              const SizedBox(width: VibeTermSpacing.sm),
              Text(l10n.keyCopied, style: VibeTermTypography.sectionLabel.copyWith(color: theme.text)),
            ],
          ),
          const SizedBox(height: VibeTermSpacing.md),
          Text(l10n.publicKey,
               style: VibeTermTypography.caption.copyWith(color: theme.textMuted)),
          const SizedBox(height: VibeTermSpacing.xs),
          Container(
            padding: const EdgeInsets.all(VibeTermSpacing.sm),
            decoration: BoxDecoration(
              color: theme.bg,
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _generatedPublicKey!,
                  style: VibeTermTypography.caption.copyWith(fontSize: 11, color: theme.text),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: VibeTermSpacing.sm),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _generatedPublicKey!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.keyCopied)),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 16, color: theme.accent),
                      const SizedBox(width: 4),
                      Text(l10n.copy, style: VibeTermTypography.caption.copyWith(color: theme.accent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: VibeTermSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.bg,
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.ok),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          style: VibeTermTypography.input.copyWith(color: theme.text),
          enabled: !_isGenerating,
          decoration: InputDecoration(
            labelText: l10n.keyName,
            labelStyle: VibeTermTypography.caption.copyWith(color: theme.textMuted),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.border),
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.accent),
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            ),
          ),
        ),
        const SizedBox(height: VibeTermSpacing.sm),
        // Type de clé fixé à Ed25519 (le plus sécurisé)
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VibeTermSpacing.md,
            vertical: VibeTermSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            border: Border.all(color: theme.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 14, color: theme.accent),
              const SizedBox(width: VibeTermSpacing.xs),
              Text(
                'Ed25519',
                style: VibeTermTypography.caption.copyWith(
                  color: theme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: VibeTermSpacing.md),
        Row(
          children: [
            TextButton(
              onPressed: _isGenerating ? null : () => setState(() => _showGenerateForm = false),
              child: Text(l10n.cancel, style: TextStyle(color: theme.accent)),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.bg,
              ),
              onPressed: _isGenerating ? null : _generateKey,
              child: _isGenerating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.bg,
                      ),
                    )
                  : Text(l10n.createSshKey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImportForm(BuildContext context, VibeTermThemeData theme) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _importNameController,
          style: VibeTermTypography.input.copyWith(color: theme.text),
          enabled: !_isImporting,
          decoration: InputDecoration(
            labelText: l10n.keyName,
            labelStyle: VibeTermTypography.caption.copyWith(color: theme.textMuted),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.border),
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.accent),
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            ),
          ),
        ),
        const SizedBox(height: VibeTermSpacing.md),
        Text(
          l10n.privateKey,
          style: VibeTermTypography.sectionLabel.copyWith(color: theme.text),
        ),
        const SizedBox(height: VibeTermSpacing.xs),
        // Bouton pour sélectionner un fichier
        OutlinedButton.icon(
          onPressed: _isImporting ? null : _pickKeyFile,
          icon: Icon(Icons.folder_open, color: theme.accent, size: 18),
          label: Text(
            l10n.selectFile,
            style: VibeTermTypography.caption.copyWith(color: theme.accent),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: theme.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            ),
          ),
        ),
        const SizedBox(height: VibeTermSpacing.sm),
        Text(
          l10n.orPasteKey,
          style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
        ),
        const SizedBox(height: VibeTermSpacing.xs),
        TextField(
          controller: _privateKeyController,
          style: VibeTermTypography.caption.copyWith(
            color: theme.text,
            fontFamily: 'JetBrainsMono',
            fontSize: 11,
          ),
          enabled: !_isImporting,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '-----BEGIN OPENSSH PRIVATE KEY-----\n...\n-----END OPENSSH PRIVATE KEY-----',
            hintStyle: VibeTermTypography.caption.copyWith(
              color: theme.textMuted,
              fontSize: 10,
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.border),
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: theme.accent),
              borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            ),
          ),
        ),
        const SizedBox(height: VibeTermSpacing.md),
        Row(
          children: [
            TextButton(
              onPressed: _isImporting ? null : () => setState(() => _showImportForm = false),
              child: Text(l10n.cancel, style: TextStyle(color: theme.accent)),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.bg,
              ),
              onPressed: _isImporting ? null : _doImportKey,
              child: _isImporting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.bg,
                      ),
                    )
                  : Text(l10n.importKey),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickKeyFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Lire le contenu du fichier
        String? content;
        if (file.bytes != null) {
          content = String.fromCharCodes(file.bytes!);
        } else if (file.path != null) {
          final fileContent = await _readFileContent(file.path!);
          content = fileContent;
        }

        if (content != null && content.isNotEmpty) {
          setState(() {
            _privateKeyController.text = content!;
            // Utiliser le nom du fichier comme nom de clé si vide
            if (_importNameController.text.isEmpty && file.name.isNotEmpty) {
              _importNameController.text = file.name.replaceAll(RegExp(r'\.(pem|key|pub)$'), '');
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorMessage('$e'))),
        );
      }
    }
  }

  Future<String?> _readFileContent(String path) async {
    try {
      final content = await File(path).readAsString();
      return content;
    } catch (e) {
      return null;
    }
  }

  Future<void> _doImportKey() async {
    final name = _importNameController.text.trim();
    final privateKey = _privateKeyController.text.trim();

    if (name.isEmpty || privateKey.isEmpty) return;

    // Vérifier que c'est une clé valide
    if (!privateKey.contains('PRIVATE KEY')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.invalidKeyFormat)),
        );
      }
      return;
    }

    setState(() => _isImporting = true);

    try {
      final keyId = DateTime.now().millisecondsSinceEpoch.toString();

      // Détecter le type de clé
      final keyType = privateKey.contains('ED25519') || privateKey.contains('ed25519')
          ? SSHKeyType.ed25519
          : SSHKeyType.rsa;

      await SecureStorageService.savePrivateKey(keyId, privateKey);
      _privateKeyController.clear();

      final newKey = SSHKey(
        id: keyId,
        name: name,
        host: '*',
        type: keyType,
        privateKey: '',
        createdAt: DateTime.now(),
      );

      await ref.read(settingsProvider.notifier).addSSHKey(newKey);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.keyImported(name))),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorMessage('$e'))),
        );
      }
    }
  }

  Future<void> _generateKey() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isGenerating = true);

    try {
      final keyName = _nameController.text.trim();
      final comment = '$keyName@vibeterm';

      // Toujours Ed25519 (le plus sécurisé)
      final keyPair = await KeyGenerationService.generateEd25519(comment);
      const keyType = SSHKeyType.ed25519;

      final keyId = DateTime.now().millisecondsSinceEpoch.toString();

      await SecureStorageService.savePrivateKey(keyId, keyPair['privateKey']!);

      final newKey = SSHKey(
        id: keyId,
        name: keyName,
        host: '*',
        type: keyType,
        privateKey: '',
        createdAt: DateTime.now(),
      );

      await ref.read(settingsProvider.notifier).addSSHKey(newKey);

      setState(() {
        _generatedPublicKey = keyPair['publicKey'];
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorMessage('$e'))),
        );
      }
    }
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VibeTermThemeData theme;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(VibeTermSpacing.md),
        decoration: BoxDecoration(
          color: theme.bg,
          borderRadius: BorderRadius.circular(VibeTermRadius.md),
          border: Border.all(color: theme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.accent),
            const SizedBox(width: VibeTermSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: VibeTermTypography.itemTitle.copyWith(color: theme.text)),
                  Text(subtitle, style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

