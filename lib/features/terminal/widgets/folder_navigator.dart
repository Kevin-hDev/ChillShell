import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../providers/folder_provider.dart';
import '../providers/ssh_provider.dart';

/// Bouton de navigation dossiers avec dropdown
class FolderNavigator extends ConsumerStatefulWidget {
  const FolderNavigator({super.key});

  @override
  ConsumerState<FolderNavigator> createState() => _FolderNavigatorState();
}

class _FolderNavigatorState extends ConsumerState<FolderNavigator> {
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  @override
  void dispose() {
    // Retirer l'overlay sans utiliser ref (déjà disposé)
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    // Charger les dossiers via SSH exec silencieux
    _loadFolders();

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  Future<void> _loadFolders() async {
    final execute = ref.read(sshProvider.notifier).executeCommandSilently;
    final state = ref.read(folderProvider);
    // Utiliser le chemin actuel s'il existe, sinon $HOME
    final basePath = (state.currentPath != '~' && state.currentPath.isNotEmpty)
        ? state.currentPath
        : null;
    await ref
        .read(folderProvider.notifier)
        .loadFolders(execute, basePath: basePath);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    ref.read(folderProvider.notifier).setSearchQuery('');
    setState(() => _isOpen = false);
  }

  Future<void> _navigateToFolder(String folderName) async {
    final execute = ref.read(sshProvider.notifier).executeCommandSilently;
    await ref
        .read(folderProvider.notifier)
        .navigateToFolder(folderName, execute);

    // Envoyer aussi le cd au shell interactif pour synchroniser
    final folderState = ref.read(folderProvider);
    final newPath = folderState.currentPath;
    // Windows cmd.exe nécessite cd /d pour changer de lecteur (ex: C: → D:)
    final cdCommand = folderState.remoteOS == 'windows'
        ? 'cd /d "$newPath"'
        : 'cd "$newPath"';
    ref.read(sshProvider.notifier).write('$cdCommand\r');
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Fond transparent pour fermer en cliquant dehors
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeDropdown,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dropdown positionné sous le bouton via CompositedTransformFollower uniquement
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 4),
            child: _FolderDropdown(
              onNavigate: _navigateToFolder,
              onClose: _closeDropdown,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(vibeTermThemeProvider);
    final folderState = ref.watch(folderProvider);

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _isOpen
                ? theme.accent.withValues(alpha: 0.2)
                : theme.bgBlock,
            borderRadius: BorderRadius.circular(VibeTermRadius.sm),
            border: Border.all(color: _isOpen ? theme.accent : theme.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_outlined,
                color: _isOpen ? theme.accent : theme.textMuted,
                size: 14,
              ),
              const SizedBox(width: 3),
              Text(
                folderState.displayName,
                style: TextStyle(
                  color: _isOpen ? theme.accent : theme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_isOpen) ...[
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down, color: theme.accent, size: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dropdown avec la liste des dossiers
class _FolderDropdown extends ConsumerStatefulWidget {
  final void Function(String) onNavigate;
  final VoidCallback onClose;

  const _FolderDropdown({required this.onNavigate, required this.onClose});

  @override
  ConsumerState<_FolderDropdown> createState() => _FolderDropdownState();
}

class _FolderDropdownState extends ConsumerState<_FolderDropdown> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus sur le champ de recherche
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(vibeTermThemeProvider);
    final folderState = ref.watch(folderProvider);
    final folders = folderState.filteredFolders;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 180, // ~2x la largeur d'un onglet
        constraints: const BoxConstraints(maxHeight: 220),
        decoration: BoxDecoration(
          color: theme.bgBlock,
          borderRadius: BorderRadius.circular(VibeTermRadius.md),
          border: Border.all(color: theme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Champ de recherche
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.border)),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: VibeTermTypography.input.copyWith(
                  color: theme.text,
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.searchPlaceholder,
                  hintStyle: VibeTermTypography.input.copyWith(
                    color: theme.textMuted,
                    fontSize: 12,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VibeTermRadius.sm),
                    borderSide: BorderSide(color: theme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VibeTermRadius.sm),
                    borderSide: BorderSide(color: theme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(VibeTermRadius.sm),
                    borderSide: BorderSide(color: theme.accent),
                  ),
                  filled: true,
                  fillColor: theme.bg,
                  prefixIcon: Icon(
                    Icons.search,
                    size: 14,
                    color: theme.textMuted,
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 30),
                ),
                onChanged: (value) {
                  ref.read(folderProvider.notifier).setSearchQuery(value);
                },
              ),
            ),
            // Liste des dossiers
            Flexible(
              child: folderState.isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.accent,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        // Parent directory
                        _FolderItem(
                          name: '..',
                          displayName: context.l10n.folderParent,
                          icon: Icons.arrow_upward,
                          theme: theme,
                          onTap: () => widget.onNavigate('..'),
                        ),
                        // Sous-dossiers
                        if (folders.isEmpty && !folderState.isLoading)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              folderState.searchQuery.isNotEmpty
                                  ? context.l10n.folderNoResults
                                  : context.l10n.folderNoSubfolders,
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 11,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          ...folders.map(
                            (folder) => _FolderItem(
                              name: folder,
                              displayName: folder,
                              icon: Icons.folder_outlined,
                              theme: theme,
                              onTap: () => widget.onNavigate(folder),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Item de dossier dans la liste
class _FolderItem extends StatefulWidget {
  final String name;
  final String displayName;
  final IconData icon;
  final VibeTermThemeData theme;
  final VoidCallback onTap;

  const _FolderItem({
    required this.name,
    required this.displayName,
    required this.icon,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_FolderItem> createState() => _FolderItemState();
}

class _FolderItemState extends State<_FolderItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: _isHovered
              ? widget.theme.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: _isHovered
                    ? widget.theme.accent
                    : widget.theme.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.displayName,
                  style: TextStyle(
                    color: _isHovered
                        ? widget.theme.text
                        : widget.theme.textMuted,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
