import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../../models/models.dart';
import '../../../services/storage_service.dart';
import '../../settings/providers/settings_provider.dart';

class ConnectionDialog extends ConsumerStatefulWidget {
  const ConnectionDialog({super.key});

  @override
  ConsumerState<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends ConsumerState<ConnectionDialog> {
  final _hostController = TextEditingController();
  final _usernameController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  String? _selectedKeyId;
  List<SavedConnection> _savedConnections = [];
  bool _showSavedConnections = true;

  @override
  void initState() {
    super.initState();
    _loadSavedConnections();
  }

  Future<void> _loadSavedConnections() async {
    final storage = StorageService();
    final connections = await storage.getSavedConnections();
    if (mounted) {
      setState(() {
        _savedConnections = connections;
        _showSavedConnections = connections.isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _usernameController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final theme = ref.watch(vibeTermThemeProvider);
    final sshKeys = settings.sshKeys;

    return Dialog(
      backgroundColor: theme.bgBlock,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(VibeTermSpacing.md),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.newConnection, style: VibeTermTypography.settingsTitle.copyWith(color: theme.text)),
                  ),
                  if (_savedConnections.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setState(() => _showSavedConnections = !_showSavedConnections);
                      },
                      child: Text(
                        _showSavedConnections ? l10n.add : l10n.savedConnections,
                        style: TextStyle(color: theme.accent),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: VibeTermSpacing.md),

              if (_showSavedConnections && _savedConnections.isNotEmpty)
                _buildSavedConnectionsList(context, theme)
              else
                _buildNewConnectionForm(context, sshKeys, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedConnectionsList(BuildContext context, VibeTermThemeData theme) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.savedConnections, style: VibeTermTypography.sectionLabel.copyWith(color: theme.text)),
        const SizedBox(height: VibeTermSpacing.sm),
        ..._savedConnections.map((connection) => _SavedConnectionTile(
          connection: connection,
          onTap: () => _connectWithSaved(connection),
          onDelete: () => _deleteSavedConnection(connection),
          theme: theme,
        )),
        const SizedBox(height: VibeTermSpacing.md),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _showSavedConnections = false),
            icon: Icon(Icons.add, color: theme.accent),
            label: Text(
              l10n.newConnection,
              style: TextStyle(color: theme.accent),
            ),
          ),
        ),
        const SizedBox(height: VibeTermSpacing.sm),
        _buildLocalShellButton(context, theme),
      ],
    );
  }

  Widget _buildNewConnectionForm(BuildContext context, List<SSHKey> sshKeys, VibeTermThemeData theme) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Host
        _buildTextField(
          controller: _hostController,
          label: l10n.host,
          hint: '192.168.1.93',
          theme: theme,
        ),
        const SizedBox(height: VibeTermSpacing.sm),

        // Username
        _buildTextField(
          controller: _usernameController,
          label: l10n.username,
          hint: 'user',
          theme: theme,
        ),
        const SizedBox(height: VibeTermSpacing.sm),

        // Port
        _buildTextField(
          controller: _portController,
          label: l10n.port,
          hint: '22',
          keyboardType: TextInputType.number,
          theme: theme,
        ),
        const SizedBox(height: VibeTermSpacing.sm),

        // SSH Key selector
        Text(l10n.sshKeys, style: VibeTermTypography.sectionLabel.copyWith(color: theme.text)),
        const SizedBox(height: VibeTermSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: VibeTermSpacing.sm),
          decoration: BoxDecoration(
            color: theme.bg,
            borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            border: Border.all(color: theme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedKeyId,
              isExpanded: true,
              dropdownColor: theme.bgBlock,
              hint: Text(l10n.selectKey, style: VibeTermTypography.caption.copyWith(color: theme.textMuted)),
              items: sshKeys.map((key) {
                return DropdownMenuItem(
                  value: key.id,
                  child: Text(
                    '${key.name} (${key.typeLabel})',
                    style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedKeyId = value);
              },
            ),
          ),
        ),

        if (sshKeys.isEmpty) ...[
          const SizedBox(height: VibeTermSpacing.xs),
          Text(
            l10n.sshKeys,
            style: VibeTermTypography.caption.copyWith(color: theme.warning),
          ),
        ],

        const SizedBox(height: VibeTermSpacing.lg),

        // Buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel, style: TextStyle(color: theme.textMuted)),
            ),
            const SizedBox(width: VibeTermSpacing.sm),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accent,
                foregroundColor: theme.bg,
              ),
              onPressed: _canConnect() ? _connect : null,
              child: Text(l10n.connect),
            ),
          ],
        ),
        const SizedBox(height: VibeTermSpacing.md),
        Divider(color: theme.border),
        const SizedBox(height: VibeTermSpacing.sm),
        _buildLocalShellButton(context, theme),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required VibeTermThemeData theme,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VibeTermTypography.sectionLabel.copyWith(color: theme.text)),
        const SizedBox(height: VibeTermSpacing.xs),
        TextField(
          controller: controller,
          style: VibeTermTypography.input.copyWith(color: theme.text),
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: VibeTermTypography.caption.copyWith(color: theme.textMuted),
            filled: true,
            fillColor: theme.bg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: VibeTermSpacing.sm,
              vertical: VibeTermSpacing.sm,
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
      ],
    );
  }

  bool _isValidHost(String host) {
    if (host.isEmpty) return false;
    // Accepter IP ou hostname valide
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    final hostnameRegex = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-\.]*[a-zA-Z0-9])?$');
    return ipRegex.hasMatch(host) || hostnameRegex.hasMatch(host);
  }

  bool _isValidUsername(String username) {
    if (username.isEmpty || username.length > 32) return false;
    return RegExp(r'^[a-zA-Z0-9_\-\.]+$').hasMatch(username);
  }

  bool _isValidPort(String portStr) {
    final trimmed = portStr.trim();
    if (trimmed.isEmpty) return false;

    final port = int.tryParse(trimmed);
    if (port == null) return false; // "22a" retourne null

    return port > 0 && port <= 65535;
  }

  bool _canConnect() {
    return _isValidHost(_hostController.text.trim()) &&
        _isValidUsername(_usernameController.text.trim()) &&
        _isValidPort(_portController.text.trim()) &&
        _selectedKeyId != null;
  }

  void _connect() {
    final portStr = _portController.text.trim();
    final port = int.tryParse(portStr);

    // Double vérification (même si _canConnect devrait l'avoir vérifié)
    if (port == null || port <= 0 || port > 65535) {
      // Fallback sécurisé
      return;
    }

    final result = ConnectionInfo(
      host: _hostController.text.trim(),
      username: _usernameController.text.trim(),
      port: port, // Utiliser la valeur validée, pas int.tryParse(...) ?? 22
      keyId: _selectedKeyId!,
      isNewConnection: true,
    );
    Navigator.pop(context, result);
  }

  void _connectWithSaved(SavedConnection connection) {
    final result = ConnectionInfo(
      host: connection.host,
      username: connection.username,
      port: connection.port,
      keyId: connection.keyId,
      savedConnectionId: connection.id,
      isNewConnection: false,
    );
    Navigator.pop(context, result);
  }

  Widget _buildLocalShellButton(BuildContext context, VibeTermThemeData theme) {
    final l10n = context.l10n;
    return Center(
      child: OutlinedButton.icon(
        onPressed: _onLocalShellPressed,
        icon: Icon(Icons.computer, color: theme.accent),
        label: Text(
          l10n.localShell,
          style: TextStyle(color: theme.accent),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: theme.accent),
          padding: const EdgeInsets.symmetric(
            horizontal: VibeTermSpacing.md,
            vertical: VibeTermSpacing.sm,
          ),
        ),
      ),
    );
  }

  void _onLocalShellPressed() {
    if (Platform.isIOS) {
      _showIOSNotAvailableDialog();
    } else {
      Navigator.pop(context, const LocalShellRequest());
    }
  }

  void _showIOSNotAvailableDialog() {
    final l10n = context.l10n;
    final theme = ref.read(vibeTermThemeProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.bgBlock,
        title: Row(
          children: [
            Icon(Icons.info_outline, color: theme.warning),
            const SizedBox(width: VibeTermSpacing.sm),
            Expanded(
              child: Text(
                l10n.localShellNotAvailable,
                style: VibeTermTypography.settingsTitle.copyWith(color: theme.text),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.localShellIOSMessage,
              style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              foregroundColor: theme.bg,
            ),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSavedConnection(SavedConnection connection) async {
    final l10n = context.l10n;
    final theme = ref.read(vibeTermThemeProvider);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.bgBlock,
        title: Text(l10n.deleteConnection, style: VibeTermTypography.settingsTitle.copyWith(color: theme.text)),
        content: Text(
          '${connection.name}',
          style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel, style: TextStyle(color: theme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.danger,
              foregroundColor: theme.text,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final storage = StorageService();
      await storage.deleteSavedConnection(connection.id);
      await _loadSavedConnections();
    }
  }
}

class _SavedConnectionTile extends StatelessWidget {
  final SavedConnection connection;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VibeTermThemeData theme;

  const _SavedConnectionTile({
    required this.connection,
    required this.onTap,
    required this.onDelete,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VibeTermSpacing.xs),
      child: Material(
        color: theme.bg,
        borderRadius: BorderRadius.circular(VibeTermRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          child: Padding(
            padding: const EdgeInsets.all(VibeTermSpacing.sm),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(VibeTermSpacing.xs),
                  decoration: BoxDecoration(
                    color: theme.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(VibeTermRadius.xs),
                  ),
                  child: Icon(
                    Icons.computer,
                    color: theme.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: VibeTermSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        connection.name,
                        style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
                      ),
                      Text(
                        '${connection.username}@${connection.host}:${connection.port}',
                        style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: theme.textMuted,
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ConnectionInfo {
  final String host;
  final String username;
  final int port;
  final String keyId;
  final String? savedConnectionId;
  final bool isNewConnection;

  ConnectionInfo({
    required this.host,
    required this.username,
    required this.port,
    required this.keyId,
    this.savedConnectionId,
    this.isNewConnection = true,
  });
}

class LocalShellRequest {
  const LocalShellRequest();
}
