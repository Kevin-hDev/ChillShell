import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../models/models.dart';
import '../providers/providers.dart';

class SessionTabBar extends ConsumerWidget {
  final VoidCallback? onAddSession;
  final VoidCallback? onAddTab;

  const SessionTabBar({super.key, this.onAddSession, this.onAddTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final activeIndex = ref.watch(activeSessionIndexProvider);
    final theme = ref.watch(vibeTermThemeProvider);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: VibeTermSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: sessions.isEmpty
                ? const SizedBox()
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: sessions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: VibeTermSpacing.xs),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isActive = index == activeIndex;
                      return _SessionTab(
                        session: session,
                        isActive: isActive,
                        theme: theme,
                        onTap: () => ref.read(activeSessionIndexProvider.notifier).state = index,
                        onClose: sessions.length > 1
                            ? () async {
                                // IMPORTANT: Fermer d'abord la connexion SSH par index
                                // AVANT de modifier l'état UI
                                await ref.read(sshProvider.notifier).closeTabByIndex(index);

                                // Ensuite supprimer la session UI
                                ref.read(sessionsProvider.notifier).removeSession(session.id);

                                // Ajuster l'index actif si nécessaire
                                if (activeIndex >= sessions.length - 1 && activeIndex > 0) {
                                  ref.read(activeSessionIndexProvider.notifier).state = activeIndex - 1;
                                }
                              }
                            : null,
                      );
                    },
                  ),
          ),
          const SizedBox(width: VibeTermSpacing.xs),
          _AddSessionButton(
            onTap: onAddTab,
            onLongPress: onAddSession,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _SessionTab extends StatelessWidget {
  final Session session;
  final bool isActive;
  final VibeTermThemeData theme;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _SessionTab({
    required this.session,
    required this.isActive,
    required this.theme,
    required this.onTap,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(
          left: VibeTermSpacing.sm,
          right: VibeTermSpacing.xs,
          top: VibeTermSpacing.xs,
          bottom: VibeTermSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isActive ? theme.accent : theme.bgBlock,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          border: Border.all(
            color: isActive ? theme.accent : theme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusDot(status: session.status, theme: theme),
            const SizedBox(width: VibeTermSpacing.xs),
            Text(
              session.name,
              style: VibeTermTypography.tabText.copyWith(
                color: isActive ? theme.bg : theme.text,
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: VibeTermSpacing.xs),
              GestureDetector(
                onTap: onClose,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: isActive ? theme.bg.withValues(alpha: 0.7) : theme.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final ConnectionStatus status;
  final VibeTermThemeData theme;

  const _StatusDot({required this.status, required this.theme});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ConnectionStatus.connected:
        color = theme.success;
        break;
      case ConnectionStatus.connecting:
        color = theme.warning;
        break;
      case ConnectionStatus.error:
        color = theme.danger;
        break;
      case ConnectionStatus.disconnected:
        color = theme.textMuted;
        break;
    }

    return Container(
      width: VibeTermSizes.statusDotSmall,
      height: VibeTermSizes.statusDotSmall,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _AddSessionButton extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VibeTermThemeData theme;

  const _AddSessionButton({this.onTap, this.onLongPress, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: theme.bgBlock,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          border: Border.all(color: theme.border),
        ),
        child: Icon(
          Icons.add,
          color: theme.textMuted,
          size: 20,
        ),
      ),
    );
  }
}
