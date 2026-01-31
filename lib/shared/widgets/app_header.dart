import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/theme_provider.dart';
import '../../models/models.dart';
import '../../features/terminal/providers/providers.dart';

class AppHeader extends ConsumerWidget {
  final VoidCallback? onTerminalTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onDisconnect;
  final bool isTerminalActive;

  const AppHeader({
    super.key,
    this.onTerminalTap,
    this.onSettingsTap,
    this.onDisconnect,
    this.isTerminalActive = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(activeSessionProvider);
    final theme = ref.watch(vibeTermThemeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: VibeTermSpacing.md,
        vertical: VibeTermSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.bg,
        border: Border(
          bottom: BorderSide(color: theme.border),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Logo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.accent,
                borderRadius: BorderRadius.circular(VibeTermRadius.md),
              ),
              child: Center(
                child: Text(
                  '>_',
                  style: TextStyle(
                    color: theme.bg,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: VibeTermSpacing.sm),
            // Title & subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ChillShell',
                    style: VibeTermTypography.appTitle.copyWith(color: theme.text),
                  ),
                  if (session != null)
                    Row(
                      children: [
                        Container(
                          width: VibeTermSizes.statusDotSmall,
                          height: VibeTermSizes.statusDotSmall,
                          decoration: BoxDecoration(
                            color: session.status == ConnectionStatus.connected
                                ? theme.success
                                : theme.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          session.host,
                          style: VibeTermTypography.caption.copyWith(
                            color: theme.accent,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Nav buttons
            if (session != null && onDisconnect != null) ...[
              _NavButton(
                icon: Icons.logout,
                isActive: false,
                onTap: onDisconnect,
                theme: theme,
                isDanger: true,
              ),
              const SizedBox(width: VibeTermSpacing.xs),
            ],
            _NavButton(
              icon: Icons.terminal,
              isActive: isTerminalActive,
              onTap: onTerminalTap,
              theme: theme,
            ),
            const SizedBox(width: VibeTermSpacing.xs),
            _NavButton(
              icon: Icons.settings,
              isActive: !isTerminalActive,
              onTap: onSettingsTap,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback? onTap;
  final VibeTermThemeData theme;
  final bool isDanger;

  const _NavButton({
    required this.icon,
    required this.isActive,
    this.onTap,
    required this.theme,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    final Color borderColor;

    if (isDanger) {
      iconColor = theme.danger;
      borderColor = theme.danger.withValues(alpha: 0.5);
    } else if (isActive) {
      iconColor = theme.accent;
      borderColor = theme.accent;
    } else {
      iconColor = theme.textMuted;
      borderColor = theme.border;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? theme.bgElevated : theme.bgBlock,
          borderRadius: BorderRadius.circular(VibeTermRadius.md),
          border: Border.all(
            color: borderColor,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 22,
        ),
      ),
    );
  }
}
