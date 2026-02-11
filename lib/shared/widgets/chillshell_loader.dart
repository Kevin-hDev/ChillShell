import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Styles d'animation disponibles pour le loader
enum LoaderAnimationStyle {
  /// L'image grossit et rétrécit doucement
  pulse,

  /// Rotation 3D sur l'axe Y (comme une carte qui tourne)
  rotate,

  /// Flotte de haut en bas
  float,

  /// Rebondit comme une balle
  bounce,

  /// Rotation + flottement combinés
  rotateFloat,
}

/// Widget de chargement animé avec l'icône ChillShell.
class ChillShellLoader extends StatefulWidget {
  /// Taille de l'image (largeur et hauteur)
  final double size;

  /// Style d'animation
  final LoaderAnimationStyle style;

  /// Durée d'un cycle d'animation
  final Duration duration;

  /// Couleur de teinte (optionnel) - s'adapte au thème si fourni
  final Color? color;

  const ChillShellLoader({
    super.key,
    this.size = 80,
    this.style = LoaderAnimationStyle.float,
    this.duration = const Duration(milliseconds: 1500),
    this.color,
  });

  @override
  State<ChillShellLoader> createState() => _ChillShellLoaderState();
}

class _ChillShellLoaderState extends State<ChillShellLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: _shouldReverse());
  }

  bool _shouldReverse() {
    return widget.style == LoaderAnimationStyle.pulse ||
        widget.style == LoaderAnimationStyle.float ||
        widget.style == LoaderAnimationStyle.bounce;
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      'assets/images/chillshell_loader.png',
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
    );

    // Appliquer la couleur du thème si fournie
    if (widget.color != null) {
      image = ColorFiltered(
        colorFilter: ColorFilter.mode(
          widget.color!,
          BlendMode.srcATop,
        ),
        child: image,
      );
    }

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return _buildAnimatedImage(child!);
      },
      child: image,
    );
  }

  Widget _buildAnimatedImage(Widget child) {
    switch (widget.style) {
      case LoaderAnimationStyle.pulse:
        return _buildPulse(child);
      case LoaderAnimationStyle.rotate:
        return _buildRotate(child);
      case LoaderAnimationStyle.float:
        return _buildFloat(child);
      case LoaderAnimationStyle.bounce:
        return _buildBounce(child);
      case LoaderAnimationStyle.rotateFloat:
        return _buildRotateFloat(child);
    }
  }

  /// Animation pulse : scale 0.85 → 1.0 → 0.85
  Widget _buildPulse(Widget child) {
    final scale = 0.85 + (_animController.value * 0.15);
    return Transform.scale(
      scale: scale,
      child: child,
    );
  }

  /// Animation rotation 3D sur l'axe Y
  Widget _buildRotate(Widget child) {
    final angle = _animController.value * 2 * math.pi;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001) // Perspective
        ..rotateY(angle),
      child: child,
    );
  }

  /// Animation flottement vertical
  Widget _buildFloat(Widget child) {
    final offset = math.sin(_animController.value * math.pi) * 10;
    return Transform.translate(
      offset: Offset(0, -offset),
      child: child,
    );
  }

  /// Animation rebond
  Widget _buildBounce(Widget child) {
    final curve = Curves.easeInOut.transform(_animController.value);
    final offset = curve * 15;
    return Transform.translate(
      offset: Offset(0, -offset),
      child: child,
    );
  }

  /// Animation rotation + flottement (fluide et continue)
  Widget _buildRotateFloat(Widget child) {
    final t = _animController.value * 2 * math.pi;
    final rotationAngle = math.sin(t) * 0.17;
    final floatOffset = math.cos(t) * 10;

    return Transform.translate(
      offset: Offset(0, -floatOffset),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(rotationAngle),
        child: child,
      ),
    );
  }
}
