import 'ghost_text_commands.dart';

/// Moteur de suggestions Ghost Text pour l'auto-completion.
///
/// Fournit des suggestions de commandes basees sur :
/// 1. L'historique de l'utilisateur (priorite)
/// 2. Une base de donnees de commandes courantes
class GhostTextEngine {
  /// Retourne une suggestion pour completer l'input courant.
  ///
  /// Cherche d'abord dans [commandHistory], puis dans la base de commandes.
  /// Retourne la partie manquante (suffix) ou null si aucune suggestion.
  static String? getSuggestion(String input, List<String> commandHistory) {
    if (input.isEmpty) return null;

    final lower = input.toLowerCase().trim();

    // 1. Chercher d'abord dans l'historique des commandes (priorite maximale)
    for (final cmd in commandHistory.reversed) {
      if (cmd.toLowerCase().startsWith(lower) && cmd.length > input.length) {
        return cmd.substring(input.length);
      }
    }

    // 2. Chercher dans la base de commandes courantes
    for (final cmd in kGhostTextCommands) {
      if (cmd.toLowerCase().startsWith(lower) && cmd.length > input.length) {
        return cmd.substring(input.length);
      }
    }

    return null;
  }
}
