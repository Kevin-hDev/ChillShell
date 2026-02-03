import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/l10n/l10n.dart';
import '../../../models/wol_config.dart';
import '../../../services/wol_service.dart';

/// Écran d'animation pendant le réveil WOL.
///
/// Affiche une animation de chargement et les infos de progression
/// pendant que le service WOL tente de réveiller le PC et d'établir
/// une connexion SSH.
class WolStartScreen extends StatefulWidget {
  /// Configuration WOL du PC à réveiller
  final WolConfig config;

  /// Callback pour tenter une connexion SSH, retourne true si succès
  final Future<bool> Function() tryConnect;

  /// Appelé quand la connexion SSH est établie
  final VoidCallback onSuccess;

  /// Appelé quand l'utilisateur annule le processus
  final VoidCallback onCancel;

  /// Appelé en cas d'erreur (timeout, réseau, etc.)
  final Function(String) onError;

  const WolStartScreen({
    super.key,
    required this.config,
    required this.tryConnect,
    required this.onSuccess,
    required this.onCancel,
    required this.onError,
  });

  @override
  State<WolStartScreen> createState() => _WolStartScreenState();
}

class _WolStartScreenState extends State<WolStartScreen>
    with TickerProviderStateMixin {
  /// Service WOL pour gérer le réveil
  final WolService _wolService = WolService();

  /// Animation de pulsation pour l'éclair
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  /// Animation de rotation pour l'indicateur de chargement
  late AnimationController _rotationController;

  /// Progression actuelle du polling
  WolProgress? _progress;

  /// Indique si l'opération a réussi (pour afficher l'écran de succès)
  bool _isSuccess = false;

  /// Timer pour le chronomètre
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startWolProcess();
  }

  void _initAnimations() {
    // Animation de pulsation (1.5 secondes)
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Animation de rotation continue
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rotationController.repeat();

    // Timer pour le chronomètre
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isSuccess) {
        setState(() {
          _elapsed += const Duration(seconds: 1);
        });
      }
    });
  }

  void _startWolProcess() {
    _wolService.wakeAndConnect(
      config: widget.config,
      tryConnect: widget.tryConnect,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _progress = progress;
          });
        }
      },
      onSuccess: () {
        if (mounted) {
          setState(() {
            _isSuccess = true;
          });
          // Afficher l'écran de succès 1.5s puis callback
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) {
              widget.onSuccess();
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          widget.onError(error);
        }
      },
    );
  }

  void _handleCancel() {
    _wolService.cancel();
    widget.onCancel();
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _pulseController.dispose();
    _rotationController.dispose();
    _wolService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VibeTermColors.bg,
      body: SafeArea(
        child: _isSuccess ? _buildSuccessScreen() : _buildLoadingScreen(),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VibeTermSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Titre "WOL START" avec éclairs animés
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Text(
                    l10n.wolStart,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: VibeTermColors.accent,
                      letterSpacing: 2,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: VibeTermSpacing.xl),

            // Animation de chargement
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Cercle de fond
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: VibeTermColors.border,
                        width: 3,
                      ),
                    ),
                  ),
                  // Indicateur de progression circulaire animé
                  RotationTransition(
                    turns: _rotationController,
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: _progress?.progress,
                        strokeWidth: 4,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          VibeTermColors.accent,
                        ),
                      ),
                    ),
                  ),
                  // Icône d'éclair au centre
                  const Icon(
                    Icons.bolt,
                    size: 40,
                    color: VibeTermColors.accent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: VibeTermSpacing.xl),

            // Message de statut
            Text(
              l10n.wolWakingUp(widget.config.name),
              style: VibeTermTypography.itemTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: VibeTermSpacing.lg),

            // Tentative X/30
            if (_progress != null)
              Text(
                l10n.wolAttempt(_progress!.attempt.toString(), _progress!.maxAttempts.toString()),
                style: VibeTermTypography.itemDescription,
              ),
            const SizedBox(height: VibeTermSpacing.sm),

            // Timer MM:SS
            Text(
              _formatDuration(_elapsed),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: VibeTermColors.textMuted,
              ),
            ),
            const SizedBox(height: VibeTermSpacing.xl),

            // Bouton Annuler
            TextButton(
              onPressed: _handleCancel,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: VibeTermSpacing.lg,
                  vertical: VibeTermSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(VibeTermRadius.md),
                  side: const BorderSide(color: VibeTermColors.border),
                ),
              ),
              child: Text(
                l10n.cancel,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  color: VibeTermColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScreen() {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VibeTermSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône de succès
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VibeTermColors.success.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.check_circle,
                size: 50,
                color: VibeTermColors.success,
              ),
            ),
            const SizedBox(height: VibeTermSpacing.lg),

            // "Connecté !"
            Text(
              l10n.wolConnected,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: VibeTermColors.success,
              ),
            ),
            const SizedBox(height: VibeTermSpacing.md),

            // "PC Bureau allumé"
            Text(
              l10n.wolPcAwake(widget.config.name),
              style: VibeTermTypography.itemTitle,
            ),
            const SizedBox(height: VibeTermSpacing.sm),

            // "Connexion SSH établie"
            Text(
              l10n.wolSshEstablished,
              style: VibeTermTypography.itemDescription,
            ),
          ],
        ),
      ),
    );
  }
}
