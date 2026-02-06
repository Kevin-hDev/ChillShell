import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../../services/biometric_service.dart';
import '../../../services/pin_service.dart';
import '../../terminal/providers/terminal_provider.dart';
import '../providers/settings_provider.dart';
import 'section_header.dart';

class SecuritySection extends ConsumerWidget {
  const SecuritySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final theme = ref.watch(vibeTermThemeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Déverrouillage
        SectionHeader(title: l10n.unlock.toUpperCase()),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: theme.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            children: [
              // Toggle Code PIN
              _ToggleRow(
                icon: Icons.pin,
                label: l10n.pinCode,
                value: settings.appSettings.pinLockEnabled,
                onChanged: (value) async {
                  if (value) {
                    // Activer : créer un nouveau PIN
                    final pin = await _showCreatePinDialog(context, theme, l10n);
                    if (pin != null) {
                      await PinService.savePin(pin);
                      ref.read(settingsProvider.notifier).togglePinLock(true);
                    }
                  } else {
                    // Désactiver : vérifier le PIN actuel
                    final verified = await _showVerifyPinDialog(context, theme, l10n);
                    if (verified) {
                      await PinService.deletePin();
                      ref.read(settingsProvider.notifier).togglePinLock(false);
                    }
                  }
                },
                theme: theme,
              ),
              Divider(color: theme.border.withValues(alpha: 0.5), height: 1),
              // Toggle Empreinte digitale
              _ToggleRow(
                icon: Icons.fingerprint,
                label: l10n.fingerprint,
                value: settings.appSettings.fingerprintEnabled,
                onChanged: (value) async {
                  if (value) {
                    // Vérifier que l'appareil supporte la biométrie
                    final available = await BiometricService.isAvailable();
                    if (!available) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.fingerprintUnavailable),
                            backgroundColor: theme.danger,
                          ),
                        );
                      }
                      return;
                    }
                    // Test d'authentification pour confirmer
                    final success = await BiometricService.authenticate();
                    if (success) {
                      ref.read(settingsProvider.notifier).toggleFingerprint(true);
                    }
                  } else {
                    ref.read(settingsProvider.notifier).toggleFingerprint(false);
                  }
                },
                theme: theme,
              ),
            ],
          ),
        ),
        const SizedBox(height: VibeTermSpacing.lg),
        // Section Verrouillage automatique
        SectionHeader(title: l10n.autoLock.toUpperCase()),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: theme.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            children: [
              _SecurityToggle(
                title: l10n.autoLock,
                subtitle: l10n.autoLockTime,
                value: settings.appSettings.autoLockEnabled,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).toggleAutoLock(value);
                },
                theme: theme,
              ),
              if (settings.appSettings.autoLockEnabled) ...[
                Divider(color: theme.border.withValues(alpha: 0.5), height: 1),
                Padding(
                  padding: const EdgeInsets.all(VibeTermSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.autoLockTime,
                        style: VibeTermTypography.itemDescription.copyWith(
                          color: theme.textMuted,
                        ),
                      ),
                      const SizedBox(height: VibeTermSpacing.sm),
                      _AutoLockTimeSelector(
                        selectedMinutes: settings.appSettings.autoLockMinutes,
                        onChanged: (minutes) {
                          ref.read(settingsProvider.notifier).setAutoLockMinutes(minutes);
                        },
                        theme: theme,
                        minutesLabel: l10n.minutes,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: VibeTermSpacing.lg),
        // Section Historique des commandes
        SectionHeader(title: l10n.clearHistory.toUpperCase()),
        const SizedBox(height: VibeTermSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: theme.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.md),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(VibeTermSpacing.md),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.clearHistory,
                            style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.clearHistoryConfirm,
                            style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: theme.bgBlock,
                            title: Text(
                              l10n.clearHistoryConfirm,
                              style: TextStyle(color: theme.text),
                            ),
                            content: Text(
                              l10n.clearHistoryConfirm,
                              style: TextStyle(color: theme.textMuted),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(false),
                                child: Text(l10n.cancel, style: TextStyle(color: theme.textMuted)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(true),
                                child: Text(l10n.delete, style: TextStyle(color: theme.danger)),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await ref.read(terminalProvider.notifier).clearCommandHistory();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(l10n.historyCleared),
                                backgroundColor: theme.success,
                              ),
                            );
                          }
                        }
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: theme.danger.withValues(alpha: 0.1),
                        foregroundColor: theme.danger,
                      ),
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Dialog pour créer un nouveau PIN (saisie + confirmation)
  Future<String?> _showCreatePinDialog(
    BuildContext context,
    VibeTermThemeData theme,
    dynamic l10n,
  ) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CreatePinDialog(theme: theme, l10n: l10n),
    );
  }

  /// Dialog pour vérifier le PIN actuel (avant désactivation)
  Future<bool> _showVerifyPinDialog(
    BuildContext context,
    VibeTermThemeData theme,
    dynamic l10n,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VerifyPinDialog(theme: theme, l10n: l10n),
    );
    return result ?? false;
  }
}

/// Dialog de création de PIN (étape 1: créer, étape 2: confirmer)
class _CreatePinDialog extends StatefulWidget {
  final VibeTermThemeData theme;
  final dynamic l10n;

  const _CreatePinDialog({required this.theme, required this.l10n});

  @override
  State<_CreatePinDialog> createState() => _CreatePinDialogState();
}

class _CreatePinDialogState extends State<_CreatePinDialog> {
  String _pin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  String? _error;

  void _addDigit(String digit) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 6) {
      _onPinComplete();
    }
  }

  void _removeDigit() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  void _onPinComplete() {
    if (!_isConfirming) {
      // Première saisie : passer à la confirmation
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _isConfirming = true;
      });
    } else {
      // Confirmation : vérifier la correspondance
      if (_pin == _firstPin) {
        Navigator.of(context).pop(_pin);
      } else {
        setState(() {
          _pin = '';
          _error = widget.l10n.pinMismatch;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final l10n = widget.l10n;

    return AlertDialog(
      backgroundColor: theme.bgBlock,
      title: Text(
        _isConfirming ? l10n.confirmPin : l10n.createPin,
        style: VibeTermTypography.appTitle.copyWith(color: theme.text),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: VibeTermSpacing.md),
          // 6 cercles indicateurs
          _PinDots(length: _pin.length, theme: theme),
          if (_error != null) ...[
            const SizedBox(height: VibeTermSpacing.sm),
            Text(
              _error!,
              style: VibeTermTypography.itemDescription.copyWith(color: theme.danger),
            ),
          ],
          const SizedBox(height: VibeTermSpacing.lg),
          // Clavier numérique
          _PinKeypad(
            onDigit: _addDigit,
            onDelete: _removeDigit,
            theme: theme,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(l10n.cancel, style: TextStyle(color: theme.textMuted)),
        ),
      ],
    );
  }
}

/// Dialog de vérification de PIN (pour désactiver)
class _VerifyPinDialog extends StatefulWidget {
  final VibeTermThemeData theme;
  final dynamic l10n;

  const _VerifyPinDialog({required this.theme, required this.l10n});

  @override
  State<_VerifyPinDialog> createState() => _VerifyPinDialogState();
}

class _VerifyPinDialogState extends State<_VerifyPinDialog> {
  String _pin = '';
  String? _error;

  void _addDigit(String digit) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 6) {
      _onPinComplete();
    }
  }

  void _removeDigit() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _onPinComplete() async {
    final verified = await PinService.verifyPin(_pin);
    if (verified) {
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _pin = '';
        _error = widget.l10n.wrongPin;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final l10n = widget.l10n;

    return AlertDialog(
      backgroundColor: theme.bgBlock,
      title: Text(
        l10n.enterPin,
        style: VibeTermTypography.appTitle.copyWith(color: theme.text),
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: VibeTermSpacing.md),
          _PinDots(length: _pin.length, theme: theme),
          if (_error != null) ...[
            const SizedBox(height: VibeTermSpacing.sm),
            Text(
              _error!,
              style: VibeTermTypography.itemDescription.copyWith(color: theme.danger),
            ),
          ],
          const SizedBox(height: VibeTermSpacing.lg),
          _PinKeypad(
            onDigit: _addDigit,
            onDelete: _removeDigit,
            theme: theme,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel, style: TextStyle(color: theme.textMuted)),
        ),
      ],
    );
  }
}

/// 6 cercles indicateurs de PIN
class _PinDots extends StatelessWidget {
  final int length;
  final VibeTermThemeData theme;

  const _PinDots({required this.length, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final isFilled = index < length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? theme.accent : Colors.transparent,
            border: Border.all(
              color: isFilled ? theme.accent : theme.textMuted,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

/// Clavier numérique pour la saisie du PIN
class _PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VibeTermThemeData theme;

  const _PinKeypad({
    required this.onDigit,
    required this.onDelete,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 8),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 8),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Espace vide à gauche
            const SizedBox(width: 64, height: 52),
            const SizedBox(width: 12),
            _buildKey('0'),
            const SizedBox(width: 12),
            // Bouton supprimer
            SizedBox(
              width: 64,
              height: 52,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(VibeTermRadius.sm),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onDelete();
                  },
                  child: Center(
                    child: Icon(
                      Icons.backspace_outlined,
                      color: theme.textMuted,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: digits.map((d) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _buildKey(d),
        );
      }).toList(),
    );
  }

  Widget _buildKey(String digit) {
    return SizedBox(
      width: 64,
      height: 52,
      child: Material(
        color: theme.bg,
        borderRadius: BorderRadius.circular(VibeTermRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          onTap: () {
            HapticFeedback.lightImpact();
            onDigit(digit);
          },
          child: Center(
            child: Text(
              digit,
              style: VibeTermTypography.appTitle.copyWith(
                color: theme.text,
                fontSize: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ligne toggle pour Code PIN / Empreinte
class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VibeTermThemeData theme;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeTermSpacing.md,
        vertical: VibeTermSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.accent, size: 22),
          const SizedBox(width: VibeTermSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: VibeTermTypography.itemTitle.copyWith(color: theme.text),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: theme.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Toggle générique pour les paramètres de sécurité
class _SecurityToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VibeTermThemeData theme;

  const _SecurityToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title, style: VibeTermTypography.itemTitle.copyWith(color: theme.text)),
      subtitle: Text(subtitle, style: VibeTermTypography.itemDescription.copyWith(color: theme.textMuted)),
      trailing: Switch(
        value: value,
        activeThumbColor: theme.accent,
        onChanged: onChanged,
      ),
    );
  }
}

/// Sélecteur de temps pour le verrouillage automatique (5 / 10 / 15 / 30 min)
class _AutoLockTimeSelector extends StatelessWidget {
  final int selectedMinutes;
  final ValueChanged<int> onChanged;
  final VibeTermThemeData theme;
  final String minutesLabel;

  const _AutoLockTimeSelector({
    required this.selectedMinutes,
    required this.onChanged,
    required this.theme,
    required this.minutesLabel,
  });

  static const List<int> _options = [5, 10, 15, 30];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((minutes) {
        final isSelected = selectedMinutes == minutes;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: minutes != _options.last ? VibeTermSpacing.xs : 0,
            ),
            child: GestureDetector(
              onTap: () => onChanged(minutes),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: VibeTermSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected ? theme.accent : theme.bg,
                  borderRadius: BorderRadius.circular(VibeTermRadius.sm),
                  border: Border.all(
                    color: isSelected ? theme.accent : theme.border,
                  ),
                ),
                child: Center(
                  child: Text(
                    '$minutes min',
                    style: VibeTermTypography.itemTitle.copyWith(
                      color: isSelected ? theme.bg : theme.text,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
