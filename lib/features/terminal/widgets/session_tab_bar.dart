import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../models/models.dart';
import '../providers/providers.dart';
import 'folder_navigator.dart';

class SessionTabBar extends ConsumerWidget {
  final VoidCallback? onAddSession;
  final VoidCallback? onAddTab;
  final VoidCallback? onFolderTap;
  final VoidCallback? onScrollToBottom;
  final VoidCallback? onImageImport;

  const SessionTabBar({
    super.key,
    this.onAddSession,
    this.onAddTab,
    this.onFolderTap,
    this.onScrollToBottom,
    this.onImageImport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final activeIndex = ref.watch(activeSessionIndexProvider);
    final theme = ref.watch(vibeTermThemeProvider);
    final isScrolledUp = ref.watch(terminalScrolledUpProvider);

    return Container(
      height: 32,  // Réduit de 44 → 32 (~30%)
      padding: const EdgeInsets.symmetric(horizontal: VibeTermSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: sessions.isEmpty
                ? const SizedBox()
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: sessions.length,
                    separatorBuilder: (_, _) => const SizedBox(width: VibeTermSpacing.xs),
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isActive = index == activeIndex;
                      return _SessionTab(
                        session: session,
                        isActive: isActive,
                        theme: theme,
                        onTap: () => ref.read(activeSessionIndexProvider.notifier).set(index),
                        onClose: sessions.length > 1
                            ? () async {
                                // IMPORTANT: Fermer d'abord la connexion SSH par index
                                // AVANT de modifier l'état UI
                                await ref.read(sshProvider.notifier).closeTabByIndex(index);

                                // Ensuite supprimer la session UI
                                ref.read(sessionsProvider.notifier).removeSession(session.id);

                                // Ajuster l'index actif si nécessaire
                                if (activeIndex >= sessions.length - 1 && activeIndex > 0) {
                                  ref.read(activeSessionIndexProvider.notifier).set(activeIndex - 1);
                                }
                              }
                            : null,
                      );
                    },
                  ),
          ),
          // Boutons affichés uniquement quand connecté
          if (sessions.isNotEmpty) ...[
            const SizedBox(width: VibeTermSpacing.xs),
            // Bouton scroll to bottom (intelligent - apparaît seulement si scrollé vers le haut)
            if (isScrolledUp)
              _ScrollToBottomButton(
                onTap: onScrollToBottom,
                theme: theme,
              ),
            if (isScrolledUp)
              const SizedBox(width: VibeTermSpacing.xs),
            // Bouton import image
            _ImageImportButton(
              onTap: onImageImport,
              theme: theme,
            ),
            const SizedBox(width: VibeTermSpacing.xs),
            // Bouton navigation dossiers
            const FolderNavigator(),
            const SizedBox(width: VibeTermSpacing.xs),
            _AddSessionButton(
              onTap: onAddTab,
              onLongPress: onAddSession,
              theme: theme,
            ),
          ],
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
          left: 6,   // Réduit de 8 → 6
          right: 4,  // Réduit de 4 → 4
          top: 2,    // Réduit de 4 → 2
          bottom: 2, // Réduit de 4 → 2
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
            const SizedBox(width: 4),  // Réduit de 4 → 4
            Text(
              session.name,
              style: VibeTermTypography.tabText.copyWith(
                color: isActive ? theme.bg : theme.text,
                fontSize: 12,  // Réduit de 14 → 12
              ),
            ),
            if (onClose != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClose,
                child: Icon(
                  Icons.close,
                  size: 12,  // Réduit de 14 → 12
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
      width: 5,  // Réduit de 6 → 5
      height: 5,
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
        width: 26,   // Réduit de 36 → 26
        height: 26,  // Réduit de 36 → 26
        decoration: BoxDecoration(
          color: theme.bgBlock,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          border: Border.all(color: theme.border),
        ),
        child: Icon(
          Icons.add,
          color: theme.textMuted,
          size: 16,  // Réduit de 20 → 16
        ),
      ),
    );
  }
}

/// Bouton intelligent "scroll to bottom" (apparaît seulement si scrollé vers le haut)
class _ScrollToBottomButton extends StatelessWidget {
  final VoidCallback? onTap;
  final VibeTermThemeData theme;

  const _ScrollToBottomButton({this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: theme.bgBlock,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.arrow_downward,
              color: theme.textMuted,
              size: 12,
            ),
            Container(
              width: 10,
              height: 2,
              color: theme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton d'import d'images pour agents IA CLI
class _ImageImportButton extends StatelessWidget {
  final VoidCallback? onTap;
  final VibeTermThemeData theme;

  const _ImageImportButton({this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: theme.bgBlock,
          borderRadius: BorderRadius.circular(VibeTermRadius.sm),
          border: Border.all(color: theme.border),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          color: theme.textMuted,
          size: 16,
        ),
      ),
    );
  }
}
