import 'dart:async';
import 'dart:math' show pow;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../../services/biometric_service.dart';
import '../../../services/pin_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  final bool pinEnabled;
  final bool fingerprintEnabled;

  const LockScreen({
    super.key,
    required this.onUnlocked,
    this.pinEnabled = false,
    this.fingerprintEnabled = false,
  });

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  String? _errorMessage;
  bool _isAuthenticating = false;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;
  int _storedPinLength = 8;

  @override
  void initState() {
    super.initState();
    _loadPinLength();
    // Lancer l'empreinte automatiquement si activée (post-frame pour accès context.l10n)
    if (widget.fingerprintEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticateFingerprint();
      });
    }
  }

  Future<void> _loadPinLength() async {
    final length = await PinService.getPinLength();
    if (mounted) setState(() => _storedPinLength = length);
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _authenticateFingerprint() async {
    if (_isAuthenticating) return;
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final success = await BiometricService.authenticate(
        localizedReason: context.l10n.biometricReason,
      );
      if (success) {
        widget.onUnlocked();
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isAuthenticating = false);
    }
  }

  void _addDigit(String digit) {
    if (_pin.length >= _storedPinLength) return;
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });
    // Auto-vérification uniquement à la longueur du PIN stocké
    if (_pin.length == _storedPinLength) {
      _verifyPin();
    }
  }

  void _removeDigit() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _verifyPin() async {
    // Vérifier le lockout
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _errorMessage = context.l10n.tryAgainIn(remaining);
      });
      return;
    }

    final verified = await PinService.verifyPin(_pin);
    if (verified) {
      _failedAttempts = 0;
      _lockoutTimer?.cancel();
      widget.onUnlocked();
    } else {
      _failedAttempts++;
      HapticFeedback.heavyImpact();

      if (_failedAttempts >= 5) {
        final delaySeconds = 30 * pow(2, _failedAttempts - 5).toInt();
        _lockoutUntil = DateTime.now().add(Duration(seconds: delaySeconds));
        _lockoutTimer?.cancel();
        _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_lockoutUntil != null && DateTime.now().isAfter(_lockoutUntil!)) {
            _lockoutTimer?.cancel();
            if (mounted) setState(() => _errorMessage = null);
          } else if (mounted) {
            final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
            setState(() => _errorMessage = context.l10n.tryAgainIn(remaining));
          }
        });
      }

      setState(() {
        _pin = '';
        _errorMessage = _failedAttempts >= 5
            ? context.l10n.tooManyAttempts(30 * pow(2, _failedAttempts - 5).toInt())
            : context.l10n.wrongPin;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = ref.watch(vibeTermThemeProvider);

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(VibeTermSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/ICONE_CHILL.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: VibeTermSpacing.lg),

                // Titre
                Text(
                  l10n.appName,
                  style: VibeTermTypography.settingsTitle.copyWith(
                    fontSize: 28,
                    color: theme.text,
                  ),
                ),
                const SizedBox(height: VibeTermSpacing.sm),

                Text(
                  l10n.enterPin,
                  style: VibeTermTypography.caption.copyWith(
                    color: theme.textMuted,
                  ),
                ),
                const SizedBox(height: VibeTermSpacing.xl),

                // PIN entry (si PIN activé)
                if (widget.pinEnabled) ...[
                  _PinDots(length: _pin.length, total: _storedPinLength, theme: theme),

                  // Erreur
                  if (_errorMessage != null) ...[
                    const SizedBox(height: VibeTermSpacing.sm),
                    Text(
                      _errorMessage!,
                      style: VibeTermTypography.caption.copyWith(
                        color: theme.danger,
                      ),
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

                // Bouton empreinte (si activée)
                if (widget.fingerprintEnabled) ...[
                  const SizedBox(height: VibeTermSpacing.lg),
                  GestureDetector(
                    onTap: _isAuthenticating ? null : _authenticateFingerprint,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: VibeTermSpacing.lg,
                        vertical: VibeTermSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: theme.accent,
                        borderRadius: BorderRadius.circular(VibeTermRadius.md),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isAuthenticating
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: theme.bg,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(Icons.fingerprint, color: theme.bg),
                          const SizedBox(width: VibeTermSpacing.sm),
                          Text(
                            l10n.fingerprint,
                            style: VibeTermTypography.itemTitle.copyWith(
                              color: theme.bg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cercles indicateurs de PIN (nombre configurable)
class _PinDots extends StatelessWidget {
  final int length;
  final int total;
  final VibeTermThemeData theme;

  const _PinDots({required this.length, this.total = 8, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
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

/// Clavier numérique
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
            const SizedBox(width: 72, height: 56),
            const SizedBox(width: 12),
            _buildKey('0'),
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              height: 56,
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
                      size: 24,
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
      width: 72,
      height: 56,
      child: Material(
        color: theme.bgBlock,
        borderRadius: BorderRadius.circular(VibeTermRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(VibeTermRadius.md),
          onTap: () {
            HapticFeedback.lightImpact();
            onDigit(digit);
          },
          child: Center(
            child: Text(
              digit,
              style: VibeTermTypography.appTitle.copyWith(
                color: theme.text,
                fontSize: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
