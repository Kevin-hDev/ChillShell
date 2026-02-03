import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _isGenerating = false;
  String? _generatedPublicKey;
  final _nameController = TextEditingController();
  String _selectedType = 'Ed25519';

  @override
  void dispose() {
    _nameController.dispose();
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sshKeys, style: VibeTermTypography.settingsTitle.copyWith(color: theme.text)),
          const SizedBox(height: VibeTermSpacing.md),
          if (!_showGenerateForm) ...[
            _OptionTile(
              icon: Icons.file_upload,
              title: l10n.privateKey,
              subtitle: '.pem / .pub',
              onTap: _importKey,
              theme: theme,
            ),
            const SizedBox(height: VibeTermSpacing.sm),
            _OptionTile(
              icon: Icons.auto_fix_high,
              title: l10n.generateKey,
              subtitle: l10n.keyType,
              onTap: () => setState(() => _showGenerateForm = true),
              theme: theme,
            ),
          ] else ...[
            _buildGenerateForm(context, theme),
          ],
          const SizedBox(height: VibeTermSpacing.md),
        ],
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
              child: const Text('OK'),
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
        const SizedBox(height: VibeTermSpacing.md),
        Text(l10n.keyType, style: VibeTermTypography.sectionLabel.copyWith(color: theme.text)),
        const SizedBox(height: VibeTermSpacing.xs),
        Row(
          children: [
            _TypeChip(
              label: 'Ed25519',
              isSelected: _selectedType == 'Ed25519',
              onTap: _isGenerating ? null : () => setState(() => _selectedType = 'Ed25519'),
              theme: theme,
            ),
            const SizedBox(width: VibeTermSpacing.sm),
            _TypeChip(
              label: 'RSA 4096',
              isSelected: _selectedType == 'RSA 4096',
              onTap: _isGenerating ? null : () => setState(() => _selectedType = 'RSA 4096'),
              theme: theme,
            ),
          ],
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
                  : Text(l10n.generateKey),
            ),
          ],
        ),
      ],
    );
  }

  void _importKey() {
    Navigator.pop(context);
  }

  Future<void> _generateKey() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isGenerating = true);

    try {
      final keyName = _nameController.text.trim();
      final comment = '$keyName@vibeterm';

      final keyPair = _selectedType == 'Ed25519'
          ? await KeyGenerationService.generateEd25519(comment)
          : await KeyGenerationService.generateRSA4096(comment);

      final keyType = _selectedType == 'Ed25519'
          ? SSHKeyType.ed25519
          : SSHKeyType.rsa;

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
          SnackBar(content: Text('Erreur: $e')),
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

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final VibeTermThemeData theme;

  const _TypeChip({
    required this.label,
    required this.isSelected,
    this.onTap,
    required this.theme,
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
          color: isSelected ? theme.accent : theme.bg,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          border: Border.all(
            color: isSelected ? theme.accent : theme.border,
          ),
        ),
        child: Text(
          label,
          style: VibeTermTypography.caption.copyWith(
            color: isSelected ? theme.bg : theme.text,
          ),
        ),
      ),
    );
  }
}
