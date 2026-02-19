// =============================================================================
// FIX-003 — SecureCommandHistory (TTL + MaxEntries)
// Problème corrigé : GAP-003 — Historique sans limite de taille ni expiration
// =============================================================================
//
// CONTEXTE DU PROBLÈME :
// Le code actuel dans storage_service.dart sauvegarde TOUTES les commandes
// depuis l'installation, sans aucune limite :
//
//   Future<void> saveCommandHistoryV2(List<Map<String,dynamic>> entries) async {
//     await _storage.write(key: 'command_history', value: jsonEncode(entries));
//   }
//
// Risques :
//   1. TAILLE ILLIMITÉE : Après 6 mois, l'historique peut contenir des milliers
//      de commandes, dont des commandes avec des arguments sensibles
//      (mots de passe en clair passés en argument, tokens, chemins privés)
//
//   2. RÉTENTION INFINIE : Une commande tapée il y a 2 ans est toujours là.
//      Si l'appareil est volé/analysé, toute l'historique est exposée.
//
//   3. CROISSANCE NON BORNÉE : En théorie, un SecureStorage qui grandit
//      indéfiniment peut causer des ralentissements ou des OOM sur mobile.
//
// SOLUTION :
//   - maxEntries = 500 : jamais plus de 500 commandes stockées
//   - ttlDays = 30 : les commandes de plus de 30 jours sont purgées
//   - Purge automatique à chaque lecture ET écriture
//
// FORMAT V2 (existant, maintenu) :
//   [
//     {'c': 'ls -la', 't': 1708300000000},   // t = timestamp en millisecondes
//     {'c': 'ssh user@host', 't': 1708300001000},
//     ...
//   ]
//
// INTEGRATION :
// 1. Remplacer dans tous les fichiers :
//    - storage_service.saveCommandHistory() → SecureCommandHistory.addCommand()
//    - storage_service.getCommandHistory()  → SecureCommandHistory.getHistory()
//
// 2. Appeler au démarrage de l'app (dans main.dart ou app_state_notifier.dart) :
//    await SecureCommandHistory.purgeExpired(storage);
//
// 3. Exemple de migration dans terminal_screen.dart :
//    AVANT : await _storageService.saveCommandHistoryV2(entries);
//    APRÈS : await SecureCommandHistory.addCommand(storage, command);
// =============================================================================

import 'dart:convert';

/// Interface minimale pour le stockage sécurisé.
///
/// Correspond à l'interface de flutter_secure_storage utilisée dans ChillShell.
/// Définie ici pour permettre les tests sans dépendance au package.
abstract class SecureStorageInterface {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

/// Gestionnaire d'historique de commandes avec TTL et limite de taille.
///
/// Toutes les méthodes sont statiques pour s'intégrer facilement avec
/// le pattern Service Locator utilisé dans ChillShell.
///
/// Usage :
/// ```dart
/// // Ajouter une commande
/// await SecureCommandHistory.addCommand(storage, 'ls -la');
///
/// // Lire l'historique (commandes récentes, < 30 jours, max 500)
/// final history = await SecureCommandHistory.getHistory(storage);
///
/// // Purger au démarrage de l'app
/// await SecureCommandHistory.purgeExpired(storage);
///
/// // Purge manuelle (ex: bouton "Effacer l'historique")
/// await SecureCommandHistory.clear(storage);
/// ```
class SecureCommandHistory {
  // ---------------------------------------------------------------------------
  // Constantes de configuration
  // ---------------------------------------------------------------------------

  /// Nombre maximum de commandes conservées dans l'historique.
  ///
  /// Au-delà de 500, les commandes les PLUS ANCIENNES sont supprimées.
  /// Justification : 500 commandes couvrent plusieurs semaines d'usage intensif.
  static const int maxEntries = 500;

  /// Durée de rétention des commandes en jours.
  ///
  /// Une commande de plus de 30 jours est automatiquement purgée.
  /// Justification : L'utilisateur n'a pas besoin d'historique vieux de plus
  /// d'un mois, et cela réduit la fenêtre d'exposition en cas de compromission.
  static const int ttlDays = 30;

  /// Clé de stockage dans SecureStorage (doit correspondre au code existant).
  static const String _storageKey = 'command_history';

  // Clé du champ commande dans le format V2
  static const String _fieldCommand = 'c';

  // Clé du champ timestamp dans le format V2
  static const String _fieldTimestamp = 't';

  // ---------------------------------------------------------------------------
  // API publique
  // ---------------------------------------------------------------------------

  /// Ajoute une commande à l'historique.
  ///
  /// Processus :
  ///   1. Charge l'historique existant depuis [storage]
  ///   2. Purge les entrées expirées (> [ttlDays] jours)
  ///   3. Applique la limite [maxEntries] en supprimant les plus anciennes
  ///   4. Ajoute la nouvelle commande avec le timestamp actuel
  ///   5. Sauvegarde
  ///
  /// [command] ne doit pas être vide.
  /// Lance [ArgumentError] si [command] est vide ou null.
  static Future<void> addCommand(
    SecureStorageInterface storage,
    String command,
  ) async {
    if (command.trim().isEmpty) {
      // On ignore silencieusement les commandes vides (touches accidentelles)
      // sans lever d'exception pour ne pas perturber le flux UI.
      return;
    }

    // 1. Charger l'historique existant
    final entries = await _loadEntries(storage);

    // 2. Purger les entrées expirées
    final purged = _filterExpired(entries);

    // 3. Appliquer la limite de taille AVANT d'ajouter la nouvelle commande.
    //    On garde maxEntries - 1 pour laisser la place à la nouvelle.
    final limited = _applyMaxEntries(purged, reserveSlots: 1);

    // 4. Ajouter la nouvelle commande avec timestamp actuel en millisecondes
    limited.add({
      _fieldCommand: command,
      _fieldTimestamp: DateTime.now().millisecondsSinceEpoch,
    });

    // 5. Sauvegarder
    await _saveEntries(storage, limited);
  }

  /// Retourne l'historique des commandes, filtré et trié (plus récent en dernier).
  ///
  /// Applique automatiquement la purge des commandes expirées à chaque lecture.
  /// Les commandes sont retournées dans l'ordre chronologique (index 0 = plus ancienne).
  ///
  /// Retourne une liste vide si l'historique est vide ou non accessible.
  static Future<List<String>> getHistory(
    SecureStorageInterface storage,
  ) async {
    final entries = await _loadEntries(storage);

    // Purger les expirées à la lecture (purge opportuniste)
    final filtered = _filterExpired(entries);

    // Si la purge a retiré des entrées, on persiste le résultat nettoyé.
    if (filtered.length != entries.length) {
      await _saveEntries(storage, filtered);
    }

    // Extraire uniquement les strings de commandes (champ 'c')
    return filtered
        .map((entry) => entry[_fieldCommand] as String? ?? '')
        .where((cmd) => cmd.isNotEmpty)
        .toList();
  }

  /// Retourne l'historique complet au format V2 (avec timestamps).
  ///
  /// Utile pour les cas où le timestamp est nécessaire (affichage horodaté).
  /// Format de chaque entrée : {'c': String, 't': int (ms depuis epoch)}
  static Future<List<Map<String, dynamic>>> getHistoryV2(
    SecureStorageInterface storage,
  ) async {
    final entries = await _loadEntries(storage);
    final filtered = _filterExpired(entries);

    if (filtered.length != entries.length) {
      await _saveEntries(storage, filtered);
    }

    return List.unmodifiable(filtered);
  }

  /// Purge les commandes expirées sans ajouter de nouvelle entrée.
  ///
  /// À appeler au démarrage de l'application pour un nettoyage initial.
  /// Ne fait rien si l'historique est déjà propre.
  ///
  /// Retourne le nombre d'entrées supprimées (utile pour les logs de diagnostic).
  static Future<int> purgeExpired(SecureStorageInterface storage) async {
    final entries = await _loadEntries(storage);
    final filtered = _filterExpired(entries);

    final removedCount = entries.length - filtered.length;

    if (removedCount > 0) {
      await _saveEntries(storage, filtered);
    }

    return removedCount;
  }

  /// Efface l'intégralité de l'historique.
  ///
  /// Action irréversible. À lier à un bouton de confirmation dans l'UI.
  /// Supprime la clé du stockage sécurisé (pas juste écrire une liste vide).
  static Future<void> clear(SecureStorageInterface storage) async {
    await storage.delete(key: _storageKey);
  }

  /// Retourne le nombre de commandes actuellement dans l'historique.
  ///
  /// Applique la purge TTL avant de compter (le count reflète les entrées valides).
  static Future<int> count(SecureStorageInterface storage) async {
    final history = await getHistory(storage);
    return history.length;
  }

  // ---------------------------------------------------------------------------
  // Méthodes privées de traitement
  // ---------------------------------------------------------------------------

  /// Charge les entrées depuis le stockage sécurisé.
  ///
  /// Retourne une liste vide si la clé n'existe pas ou si le JSON est invalide.
  /// La robustesse ici est intentionnelle : un historique corrompu ne doit pas
  /// planter l'application.
  static Future<List<Map<String, dynamic>>> _loadEntries(
    SecureStorageInterface storage,
  ) async {
    try {
      final raw = await storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(raw);

      // Validation : doit être une List
      if (decoded is! List) {
        // Données corrompues ou format incompatible → reset silencieux
        return [];
      }

      // Conversion en List<Map<String, dynamic>> avec validation de chaque entrée
      final result = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is Map) {
          // Valider que l'entrée contient les champs requis
          final entry = Map<String, dynamic>.from(item);
          if (_isValidEntry(entry)) {
            result.add(entry);
          }
          // Les entrées invalides sont silencieusement ignorées
        }
      }

      return result;
    } catch (_) {
      // En cas d'erreur de décodage JSON ou autre :
      // Fail CLOSED → retourner une liste vide (pas de crash, pas de fuite)
      return [];
    }
  }

  /// Sauvegarde les entrées dans le stockage sécurisé.
  static Future<void> _saveEntries(
    SecureStorageInterface storage,
    List<Map<String, dynamic>> entries,
  ) async {
    await storage.write(
      key: _storageKey,
      value: jsonEncode(entries),
    );
  }

  /// Filtre les entrées expirées (plus anciennes que [ttlDays] jours).
  ///
  /// Une entrée sans timestamp valide est considérée expirée (fail closed).
  static List<Map<String, dynamic>> _filterExpired(
    List<Map<String, dynamic>> entries,
  ) {
    final cutoffMs = DateTime.now()
        .subtract(Duration(days: ttlDays))
        .millisecondsSinceEpoch;

    return entries.where((entry) {
      final timestamp = entry[_fieldTimestamp];
      if (timestamp is! int) {
        // Entrée sans timestamp valide → expirée par défaut (sécurité)
        return false;
      }
      return timestamp >= cutoffMs;
    }).toList();
  }

  /// Applique la limite [maxEntries] en supprimant les entrées les plus anciennes.
  ///
  /// [reserveSlots] : nombre de slots à réserver pour les prochains ajouts.
  /// Par exemple, reserveSlots=1 garde maxEntries-1 entrées.
  ///
  /// Suppose que la liste est en ordre chronologique (plus ancienne en tête).
  static List<Map<String, dynamic>> _applyMaxEntries(
    List<Map<String, dynamic>> entries, {
    int reserveSlots = 0,
  }) {
    final limit = maxEntries - reserveSlots;
    if (entries.length <= limit) {
      return entries;
    }

    // Supprimer les plus anciennes (début de la liste) pour atteindre la limite.
    // sublist(from, to) retourne une vue → on crée une copie avec toList().
    final excess = entries.length - limit;
    return entries.sublist(excess).toList();
  }

  /// Valide qu'une entrée V2 est bien formée.
  ///
  /// Une entrée valide doit avoir :
  /// - 'c' : String non vide (la commande)
  /// - 't' : int positif (timestamp en millisecondes)
  static bool _isValidEntry(Map<String, dynamic> entry) {
    final command = entry[_fieldCommand];
    final timestamp = entry[_fieldTimestamp];

    if (command is! String || command.isEmpty) {
      return false;
    }

    if (timestamp is! int || timestamp <= 0) {
      return false;
    }

    // Sanity check : le timestamp ne doit pas être dans le futur lointain
    // (signe de corruption ou de manipulation)
    final maxFutureMs =
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
    if (timestamp > maxFutureMs) {
      return false;
    }

    return true;
  }
}
