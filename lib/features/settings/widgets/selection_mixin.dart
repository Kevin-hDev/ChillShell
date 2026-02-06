import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';

/// Mixin fournissant la logique de sélection multiple réutilisable.
///
/// Utilisé par SSHKeysSection, QuickConnectionsSection et WolSection
/// pour le mode sélection avec suppression en masse.
mixin SelectionModeMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool isSelectionMode = false;
  final Set<String> selectedIds = {};

  void enterSelectionMode(String id) {
    setState(() {
      isSelectionMode = true;
      selectedIds.add(id);
    });
  }

  void exitSelectionMode() {
    setState(() {
      isSelectionMode = false;
      selectedIds.clear();
    });
  }

  void toggleSelection(String id) {
    setState(() {
      if (selectedIds.contains(id)) {
        selectedIds.remove(id);
        if (selectedIds.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedIds.add(id);
      }
    });
  }

  /// Construit les boutons de sélection (supprimer + fermer) pour le header.
  Widget buildSelectionActions({
    required VibeTermThemeData theme,
    required VoidCallback onDelete,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(Icons.delete, color: theme.danger),
          onPressed: selectedIds.isNotEmpty ? onDelete : null,
        ),
        IconButton(
          icon: Icon(Icons.close, color: theme.textMuted),
          onPressed: exitSelectionMode,
        ),
      ],
    );
  }
}
