import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../models/wol_config.dart';
import '../../../models/saved_connection.dart';
import '../providers/settings_provider.dart';
import '../providers/wol_provider.dart';

/// Bottom sheet pour ajouter une configuration Wake-on-LAN.
///
/// Permet de configurer un PC à réveiller à distance avec :
/// - Nom du PC
/// - Adresse MAC (obligatoire)
/// - Connexion SSH associée (obligatoire)
/// - Options avancées (broadcast, port)
class AddWolSheet extends ConsumerStatefulWidget {
  const AddWolSheet({super.key});

  @override
  ConsumerState<AddWolSheet> createState() => _AddWolSheetState();
}

class _AddWolSheetState extends ConsumerState<AddWolSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _macController = TextEditingController();
  final _broadcastController = TextEditingController(text: '255.255.255.255');
  final _portController = TextEditingController(text: '9');

  String? _selectedConnectionId;
  bool _showAdvanced = false;
  bool _isSaving = false;

  /// Regex pour valider le format MAC XX:XX:XX:XX:XX:XX
  static final _macRegex = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');

  @override
  void dispose() {
    _nameController.dispose();
    _macController.dispose();
    _broadcastController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(vibeTermThemeProvider);
    final settings = ref.watch(settingsProvider);
    final savedConnections = settings.savedConnections;

    return Container(
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(VibeTermRadius.lg),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: VibeTermSpacing.md,
          right: VibeTermSpacing.md,
          top: VibeTermSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + VibeTermSpacing.md,
        ),
        child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_ios, size: 16, color: theme.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Retour',
                          style: VibeTermTypography.caption.copyWith(color: theme.accent),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Ajouter un PC',
                    style: VibeTermTypography.settingsTitle.copyWith(color: theme.text),
                  ),
                  const Spacer(),
                  const SizedBox(width: 60), // Balance pour centrer le titre
                ],
              ),
              const SizedBox(height: VibeTermSpacing.lg),

              // Nom du PC
              _buildLabel('Nom du PC', theme),
              const SizedBox(height: VibeTermSpacing.xs),
              _buildTextField(
                controller: _nameController,
                hint: 'PC Bureau',
                theme: theme,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom est obligatoire';
                  }
                  return null;
                },
              ),
              const SizedBox(height: VibeTermSpacing.md),

              // Adresse MAC
              _buildLabel('Adresse MAC *', theme),
              const SizedBox(height: VibeTermSpacing.xs),
              _buildTextField(
                controller: _macController,
                hint: 'AA:BB:CC:DD:EE:FF',
                theme: theme,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  _MacAddressFormatter(),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'L\'adresse MAC est obligatoire';
                  }
                  if (!_macRegex.hasMatch(value.toUpperCase())) {
                    return 'Format invalide (ex: AA:BB:CC:DD:EE:FF)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: VibeTermSpacing.xs),
              GestureDetector(
                onTap: _showMacHelp,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Comment trouver l\'adresse MAC ?',
                      style: VibeTermTypography.caption.copyWith(color: theme.accent),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '\u{1F4D6}',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: VibeTermSpacing.md),

              // Connexion SSH associée
              _buildLabel('Connexion SSH associée *', theme),
              const SizedBox(height: VibeTermSpacing.xs),
              _buildConnectionDropdown(savedConnections, theme),
              const SizedBox(height: VibeTermSpacing.md),

              // Options avancées
              _buildAdvancedSection(theme),
              const SizedBox(height: VibeTermSpacing.lg),

              // Bouton Enregistrer
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent,
                    foregroundColor: theme.bg,
                    padding: const EdgeInsets.symmetric(vertical: VibeTermSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VibeTermRadius.md),
                    ),
                  ),
                  onPressed: _isSaving ? null : _saveConfig,
                  child: _isSaving
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.bg,
                          ),
                        )
                      : Text(
                          'Enregistrer',
                          style: VibeTermTypography.itemTitle.copyWith(
                            color: theme.bg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: VibeTermSpacing.md),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildLabel(String text, VibeTermThemeData theme) {
    return Text(
      text,
      style: VibeTermTypography.sectionLabel.copyWith(color: theme.textMuted),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required VibeTermThemeData theme,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: VibeTermTypography.input.copyWith(color: theme.text),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: VibeTermTypography.input.copyWith(color: theme.textMuted),
        filled: true,
        fillColor: theme.bg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: VibeTermSpacing.md,
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
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.danger),
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(color: theme.danger),
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
        ),
        errorStyle: VibeTermTypography.caption.copyWith(color: theme.danger),
      ),
    );
  }

  Widget _buildConnectionDropdown(
    List<SavedConnection> connections,
    VibeTermThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: VibeTermSpacing.md),
      decoration: BoxDecoration(
        color: theme.bg,
        borderRadius: BorderRadius.circular(VibeTermRadius.sm),
        border: Border.all(
          color: _selectedConnectionId == null && _formKey.currentState?.validate() == false
              ? theme.danger
              : theme.border,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedConnectionId,
          isExpanded: true,
          dropdownColor: theme.bgElevated,
          hint: Text(
            'Sélectionner une connexion',
            style: VibeTermTypography.input.copyWith(color: theme.textMuted),
          ),
          icon: Icon(Icons.keyboard_arrow_down, color: theme.textMuted),
          items: connections.isEmpty
              ? [
                  DropdownMenuItem<String>(
                    enabled: false,
                    child: Text(
                      'Aucune connexion sauvegardée',
                      style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
                    ),
                  ),
                ]
              : connections.map((connection) {
                  return DropdownMenuItem<String>(
                    value: connection.id,
                    child: Row(
                      children: [
                        Icon(Icons.key, size: 16, color: theme.accent),
                        const SizedBox(width: VibeTermSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                connection.name,
                                style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${connection.username}@${connection.host}',
                                style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          onChanged: connections.isEmpty
              ? null
              : (value) {
                  setState(() => _selectedConnectionId = value);
                },
        ),
      ),
    );
  }

  Widget _buildAdvancedSection(VibeTermThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Séparateur avec titre
        GestureDetector(
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          child: Row(
            children: [
              Expanded(child: Divider(color: theme.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: VibeTermSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Options avancées (WOL distant)',
                      style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showAdvanced ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: theme.textMuted,
                    ),
                  ],
                ),
              ),
              Expanded(child: Divider(color: theme.border)),
            ],
          ),
        ),
        if (_showAdvanced) ...[
          const SizedBox(height: VibeTermSpacing.md),

          // Adresse broadcast
          _buildLabel('Adresse broadcast (optionnel)', theme),
          const SizedBox(height: VibeTermSpacing.xs),
          _buildTextField(
            controller: _broadcastController,
            hint: '255.255.255.255',
            theme: theme,
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: VibeTermSpacing.xs),
          Text(
            'Par défaut: 255.255.255.255',
            style: VibeTermTypography.caption.copyWith(
              color: theme.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: VibeTermSpacing.md),

          // Port UDP
          _buildLabel('Port UDP (optionnel)', theme),
          const SizedBox(height: VibeTermSpacing.xs),
          _buildTextField(
            controller: _portController,
            hint: '9',
            theme: theme,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final port = int.tryParse(value);
                if (port == null || port < 1 || port > 65535) {
                  return 'Port entre 1 et 65535';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: VibeTermSpacing.xs),
          Text(
            'Par défaut: 9',
            style: VibeTermTypography.caption.copyWith(
              color: theme.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  void _showMacHelp() {
    final theme = ref.read(vibeTermThemeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgElevated,
        title: Text(
          'Trouver l\'adresse MAC',
          style: VibeTermTypography.settingsTitle.copyWith(color: theme.text),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem('Windows', 'ipconfig /all', theme),
            const SizedBox(height: VibeTermSpacing.sm),
            _buildHelpItem('macOS', 'ifconfig | grep ether', theme),
            const SizedBox(height: VibeTermSpacing.sm),
            _buildHelpItem('Linux', 'ip link show', theme),
            const SizedBox(height: VibeTermSpacing.md),
            Text(
              'L\'adresse MAC ressemble à : AA:BB:CC:DD:EE:FF',
              style: VibeTermTypography.caption.copyWith(color: theme.textMuted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Compris', style: TextStyle(color: theme.accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String os, String command, VibeTermThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          os,
          style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: VibeTermSpacing.sm,
            vertical: VibeTermSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: theme.bg,
            borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          ),
          child: Text(
            command,
            style: VibeTermTypography.command.copyWith(
              color: theme.accent,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveConfig() async {
    // Validation du formulaire
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validation de la connexion SSH sélectionnée
    if (_selectedConnectionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une connexion SSH')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Récupérer les valeurs
      final name = _nameController.text.trim();
      final mac = _macController.text.toUpperCase().trim();
      final broadcast = _broadcastController.text.trim().isNotEmpty
          ? _broadcastController.text.trim()
          : '255.255.255.255';
      final port = int.tryParse(_portController.text.trim()) ?? 9;

      // Créer la configuration avec un UUID unique
      final config = WolConfig(
        id: const Uuid().v4(),
        name: name,
        macAddress: mac,
        sshConnectionId: _selectedConnectionId!,
        broadcastAddress: broadcast,
        port: port,
      );

      // Sauvegarder via le provider
      await ref.read(wolProvider.notifier).addConfig(config);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Configuration "$name" ajoutée')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
}

/// Formatter pour formater automatiquement l'adresse MAC en majuscules
/// et ajouter les deux-points.
class _MacAddressFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Retirer tout sauf les caractères hex
    var text = newValue.text.toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');

    // Limiter à 12 caractères (6 octets)
    if (text.length > 12) {
      text = text.substring(0, 12);
    }

    // Ajouter les deux-points tous les 2 caractères
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && i % 2 == 0) {
        buffer.write(':');
      }
      buffer.write(text[i]);
    }

    final formattedText = buffer.toString();
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
