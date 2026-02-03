import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../../services/biometric_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  final bool biometricUnavailable;

  const LockScreen({
    super.key,
    required this.onUnlocked,
    this.biometricUnavailable = false,
  });

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Tenter l'authentification automatiquement au démarrage (si biométrie disponible)
    if (!widget.biometricUnavailable) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final success = await BiometricService.authenticate();
      if (success) {
        widget.onUnlocked();
      } else {
        setState(() {
          _errorMessage = 'Authentification annulée';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur d\'authentification';
      });
    } finally {
      setState(() {
        _isAuthenticating = false;
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
          child: Padding(
            padding: const EdgeInsets.all(VibeTermSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(
                      '>_',
                      style: TextStyle(
                        color: theme.bg,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
                  l10n.biometricUnlock,
                  style: VibeTermTypography.caption.copyWith(
                    color: widget.biometricUnavailable
                        ? theme.warning
                        : theme.textMuted,
                  ),
                ),
                const SizedBox(height: VibeTermSpacing.xl),

                // Message biométrie indisponible
                if (widget.biometricUnavailable) ...[
                  Container(
                    padding: const EdgeInsets.all(VibeTermSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(VibeTermRadius.md),
                      border: Border.all(
                        color: theme.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: theme.warning,
                          size: 32,
                        ),
                        const SizedBox(height: VibeTermSpacing.sm),
                        Text(
                          l10n.biometricUnlock,
                          textAlign: TextAlign.center,
                          style: VibeTermTypography.caption.copyWith(
                            color: theme.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Erreur
                if (_errorMessage != null && !widget.biometricUnavailable) ...[
                  Text(
                    _errorMessage!,
                    style: VibeTermTypography.caption.copyWith(
                      color: theme.danger,
                    ),
                  ),
                  const SizedBox(height: VibeTermSpacing.md),
                ],

                // Bouton (caché si biométrie indisponible)
                if (!widget.biometricUnavailable) ...[
                  if (_isAuthenticating)
                    CircularProgressIndicator(color: theme.accent)
                  else
                    GestureDetector(
                      onTap: _authenticate,
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
                            Icon(
                              Icons.fingerprint,
                              color: theme.bg,
                            ),
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
