// =============================================================================
// TEST — FIX-003 — SecureCommandHistory (TTL + MaxEntries)
// Couvre : GAP-003 — Historique sans limite de taille ni expiration TTL
// =============================================================================
//
// Pour lancer ces tests :
//   flutter test test_fix_003.dart
// =============================================================================

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

// Import du code à tester
// import 'package:chillshell/core/security/fix_003_history_ttl.dart';

// ---------------------------------------------------------------------------
// COPIE LOCALE pour tests autonomes
// ---------------------------------------------------------------------------

abstract class SecureStorageInterface {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class SecureCommandHistory {
  static const int maxEntries = 500;
  static const int ttlDays = 30;
  static const String _storageKey = 'command_history';
  static const String _fieldCommand = 'c';
  static const String _fieldTimestamp = 't';

  static Future<void> addCommand(SecureStorageInterface storage, String command) async {
    if (command.trim().isEmpty) return;
    final entries = await _loadEntries(storage);
    final purged = _filterExpired(entries);
    final limited = _applyMaxEntries(purged, reserveSlots: 1);
    limited.add({
      _fieldCommand: command,
      _fieldTimestamp: DateTime.now().millisecondsSinceEpoch,
    });
    await _saveEntries(storage, limited);
  }

  static Future<List<String>> getHistory(SecureStorageInterface storage) async {
    final entries = await _loadEntries(storage);
    final filtered = _filterExpired(entries);
    if (filtered.length != entries.length) {
      await _saveEntries(storage, filtered);
    }
    return filtered
        .map((e) => e[_fieldCommand] as String? ?? '')
        .where((cmd) => cmd.isNotEmpty)
        .toList();
  }

  static Future<List<Map<String, dynamic>>> getHistoryV2(SecureStorageInterface storage) async {
    final entries = await _loadEntries(storage);
    final filtered = _filterExpired(entries);
    if (filtered.length != entries.length) {
      await _saveEntries(storage, filtered);
    }
    return List.unmodifiable(filtered);
  }

  static Future<int> purgeExpired(SecureStorageInterface storage) async {
    final entries = await _loadEntries(storage);
    final filtered = _filterExpired(entries);
    final removedCount = entries.length - filtered.length;
    if (removedCount > 0) {
      await _saveEntries(storage, filtered);
    }
    return removedCount;
  }

  static Future<void> clear(SecureStorageInterface storage) async {
    await storage.delete(key: _storageKey);
  }

  static Future<int> count(SecureStorageInterface storage) async {
    return (await getHistory(storage)).length;
  }

  static Future<List<Map<String, dynamic>>> _loadEntries(SecureStorageInterface storage) async {
    try {
      final raw = await storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final result = <Map<String, dynamic>>[];
      for (final item in decoded) {
        if (item is Map) {
          final entry = Map<String, dynamic>.from(item);
          if (_isValidEntry(entry)) result.add(entry);
        }
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveEntries(SecureStorageInterface storage, List<Map<String, dynamic>> entries) async {
    await storage.write(key: _storageKey, value: jsonEncode(entries));
  }

  static List<Map<String, dynamic>> _filterExpired(List<Map<String, dynamic>> entries) {
    final cutoffMs = DateTime.now().subtract(Duration(days: ttlDays)).millisecondsSinceEpoch;
    return entries.where((entry) {
      final timestamp = entry[_fieldTimestamp];
      if (timestamp is! int) return false;
      return timestamp >= cutoffMs;
    }).toList();
  }

  static List<Map<String, dynamic>> _applyMaxEntries(List<Map<String, dynamic>> entries, {int reserveSlots = 0}) {
    final limit = maxEntries - reserveSlots;
    if (entries.length <= limit) return entries;
    final excess = entries.length - limit;
    return entries.sublist(excess).toList();
  }

  static bool _isValidEntry(Map<String, dynamic> entry) {
    final command = entry[_fieldCommand];
    final timestamp = entry[_fieldTimestamp];
    if (command is! String || command.isEmpty) return false;
    if (timestamp is! int || timestamp <= 0) return false;
    final maxFutureMs = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
    if (timestamp > maxFutureMs) return false;
    return true;
  }
}

// ---------------------------------------------------------------------------
// Implémentation en mémoire de SecureStorageInterface (pour les tests)
// ---------------------------------------------------------------------------

/// Faux stockage en mémoire pour les tests.
///
/// Simule le comportement de flutter_secure_storage sans dépendances
/// au système de fichiers ou au keystore.
class FakeSecureStorage implements SecureStorageInterface {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({required String key}) async {
    return _store[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _store[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    _store.remove(key);
  }

  /// Permet d'injecter directement des données brutes pour les tests.
  void inject(String key, String value) {
    _store[key] = value;
  }

  /// Retourne le contenu brut stocké (pour inspection dans les tests).
  String? raw(String key) => _store[key];

  /// Efface tout le stockage (reset entre les tests).
  void reset() => _store.clear();
}

// ---------------------------------------------------------------------------
// FIN COPIE LOCALE
// ---------------------------------------------------------------------------

/// Crée un timestamp en millisecondes relatif à aujourd'hui.
///
/// [daysAgo] : nombre de jours dans le passé (positif = passé)
/// [daysAgo] négatif = futur
int timestampDaysAgo(int daysAgo) {
  return DateTime.now()
      .subtract(Duration(days: daysAgo))
      .millisecondsSinceEpoch;
}

/// Crée une entrée V2 valide pour les tests.
Map<String, dynamic> makeEntry(String command, {int daysAgo = 1}) {
  return {
    'c': command,
    't': timestampDaysAgo(daysAgo),
  };
}

void main() {
  late FakeSecureStorage storage;

  setUp(() {
    // Nouveau stockage vide avant chaque test
    storage = FakeSecureStorage();
  });

  // =========================================================================
  group('SecureCommandHistory — addCommand()', () {
    // -------------------------------------------------------------------------
    test('addCommand() ajoute une commande à un historique vide', () async {
      await SecureCommandHistory.addCommand(storage, 'ls -la');

      final history = await SecureCommandHistory.getHistory(storage);
      expect(history, hasLength(1));
      expect(history.first, equals('ls -la'));
    });

    // -------------------------------------------------------------------------
    test('addCommand() ajoute plusieurs commandes dans l\'ordre', () async {
      await SecureCommandHistory.addCommand(storage, 'ls');
      await SecureCommandHistory.addCommand(storage, 'pwd');
      await SecureCommandHistory.addCommand(storage, 'whoami');

      final history = await SecureCommandHistory.getHistory(storage);
      expect(history, hasLength(3));
      expect(history[0], equals('ls'));
      expect(history[1], equals('pwd'));
      expect(history[2], equals('whoami'));
    });

    // -------------------------------------------------------------------------
    test('addCommand() ignore les commandes vides', () async {
      await SecureCommandHistory.addCommand(storage, 'ls');
      await SecureCommandHistory.addCommand(storage, '');      // vide
      await SecureCommandHistory.addCommand(storage, '   ');   // espaces seulement

      final history = await SecureCommandHistory.getHistory(storage);
      expect(history, hasLength(1));
      expect(history.first, equals('ls'));
    });

    // -------------------------------------------------------------------------
    test('addCommand() stocke le timestamp au format V2', () async {
      final beforeMs = DateTime.now().millisecondsSinceEpoch;
      await SecureCommandHistory.addCommand(storage, 'ssh user@host');
      final afterMs = DateTime.now().millisecondsSinceEpoch;

      final v2 = await SecureCommandHistory.getHistoryV2(storage);
      expect(v2, hasLength(1));

      final entry = v2.first;
      expect(entry['c'], equals('ssh user@host'));
      expect(entry['t'], isA<int>());

      // Le timestamp doit être dans la fenêtre [before, after]
      final ts = entry['t'] as int;
      expect(ts, greaterThanOrEqualTo(beforeMs));
      expect(ts, lessThanOrEqualTo(afterMs));
    });
  });

  // =========================================================================
  group('SecureCommandHistory — TTL de 30 jours', () {
    // -------------------------------------------------------------------------
    test('les commandes de moins de 30 jours sont conservées', () async {
      // Injecter des entrées récentes (1, 7, 29 jours)
      final recentEntries = [
        makeEntry('ls', daysAgo: 1),
        makeEntry('pwd', daysAgo: 7),
        makeEntry('whoami', daysAgo: 29),
      ];
      storage.inject('command_history', jsonEncode(recentEntries));

      final history = await SecureCommandHistory.getHistory(storage);
      expect(history, hasLength(3));
      expect(history, containsAll(['ls', 'pwd', 'whoami']));
    });

    // -------------------------------------------------------------------------
    test('les commandes exactement à 30 jours sont conservées (frontière inclusive)', () async {
      // cutoff = now - 30 jours, le filtre est timestamp >= cutoffMs
      // Donc une commande exactement à 30 jours (timestamp == cutoff) est conservée.
      final entries = [
        makeEntry('ancienne', daysAgo: 30),  // exactement 30 jours → conservée (>=)
        makeEntry('recente', daysAgo: 1),    // récente → conservée
      ];
      storage.inject('command_history', jsonEncode(entries));

      final history = await SecureCommandHistory.getHistory(storage);
      expect(history, contains('ancienne'));
      expect(history, contains('recente'));
    });

    // -------------------------------------------------------------------------
    test('les commandes de plus de 30 jours sont purgées', () async {
      final entries = [
        makeEntry('tres_ancienne', daysAgo: 31),   // > 30 jours → expiré
        makeEntry('ancienne', daysAgo: 60),         // > 30 jours → expiré
        makeEntry('tres_vieille', daysAgo: 365),    // > 30 jours → expiré
        makeEntry('recente', daysAgo: 5),            // récente → conservée
      ];
      storage.inject('command_history', jsonEncode(entries));

      final history = await SecureCommandHistory.getHistory(storage);

      expect(history, isNot(contains('tres_ancienne')));
      expect(history, isNot(contains('ancienne')));
      expect(history, isNot(contains('tres_vieille')));
      expect(history, contains('recente'));
      expect(history, hasLength(1));
    });

    // -------------------------------------------------------------------------
    test('un historique entièrement expiré retourne une liste vide', () async {
      final entries = [
        makeEntry('vieille1', daysAgo: 31),
        makeEntry('vieille2', daysAgo: 45),
        makeEntry('vieille3', daysAgo: 100),
      ];
      storage.inject('command_history', jsonEncode(entries));

      final history = await SecureCommandHistory.getHistory(storage);
      expect(history, isEmpty);
    });

    // -------------------------------------------------------------------------
    test('purgeExpired() retourne le nombre d\'entrées supprimées', () async {
      final entries = [
        makeEntry('vieille1', daysAgo: 31),   // expiré
        makeEntry('vieille2', daysAgo: 45),   // expiré
        makeEntry('recente', daysAgo: 5),      // valide
      ];
      storage.inject('command_history', jsonEncode(entries));

      final removed = await SecureCommandHistory.purgeExpired(storage);
      expect(removed, equals(2));
    });

    // -------------------------------------------------------------------------
    test('purgeExpired() retourne 0 si rien n\'est expiré', () async {
      final entries = [
        makeEntry('cmd1', daysAgo: 1),
        makeEntry('cmd2', daysAgo: 7),
      ];
      storage.inject('command_history', jsonEncode(entries));

      final removed = await SecureCommandHistory.purgeExpired(storage);
      expect(removed, equals(0));
    });

    // -------------------------------------------------------------------------
    test('addCommand() purge les commandes expirées avant d\'ajouter', () async {
      // Pré-remplir avec des commandes expirées
      final oldEntries = [
        makeEntry('vieille1', daysAgo: 31),
        makeEntry('vieille2', daysAgo: 60),
      ];
      storage.inject('command_history', jsonEncode(oldEntries));

      // Ajouter une nouvelle commande
      await SecureCommandHistory.addCommand(storage, 'nouvelle_commande');

      final history = await SecureCommandHistory.getHistory(storage);

      // Les vieilles doivent être parties
      expect(history, isNot(contains('vieille1')));
      expect(history, isNot(contains('vieille2')));
      // La nouvelle doit être là
      expect(history, contains('nouvelle_commande'));
      expect(history, hasLength(1));
    });
  });

  // =========================================================================
  group('SecureCommandHistory — Limite de 500 entrées (maxEntries)', () {
    // -------------------------------------------------------------------------
    test('accepte exactement 500 entrées sans en supprimer', () async {
      // Créer exactement 500 entrées récentes
      final entries = List.generate(
        500,
        (i) => makeEntry('cmd_$i', daysAgo: 1),
      );
      storage.inject('command_history', jsonEncode(entries));

      final history = await SecureCommandHistory.getHistory(storage);
      expect(history, hasLength(500));
    });

    // -------------------------------------------------------------------------
    test('ajouter au-delà de 500 supprime les plus anciennes', () async {
      // Créer 500 entrées récentes (les plus "anciennes" ont daysAgo=2,
      // les plus "récentes" ont daysAgo=1 — tous dans la TTL)
      // On simule l'ordre : plus ancienne en tête, plus récente en queue
      final entries = List.generate(
        500,
        (i) => {
          'c': 'ancienne_$i',
          't': DateTime.now()
              .subtract(Duration(hours: 500 - i))
              .millisecondsSinceEpoch,
        },
      );
      storage.inject('command_history', jsonEncode(entries));

      // Ajouter la 501ème commande
      await SecureCommandHistory.addCommand(storage, 'cmd_501');

      final history = await SecureCommandHistory.getHistory(storage);

      // Doit rester dans la limite
      expect(history.length, lessThanOrEqualTo(500));

      // La nouvelle commande doit être présente
      expect(history, contains('cmd_501'));

      // La commande la plus ancienne (ancienne_0) doit être supprimée
      expect(history, isNot(contains('ancienne_0')));
    });

    // -------------------------------------------------------------------------
    test('maxEntries = 500 est correctement défini', () {
      // Vérification de la constante elle-même
      expect(SecureCommandHistory.maxEntries, equals(500));
    });

    // -------------------------------------------------------------------------
    test('ttlDays = 30 est correctement défini', () {
      expect(SecureCommandHistory.ttlDays, equals(30));
    });
  });

  // =========================================================================
  group('SecureCommandHistory — Format V2 (avec timestamps)', () {
    // -------------------------------------------------------------------------
    test('getHistoryV2() retourne les entrées avec champs c et t', () async {
      await SecureCommandHistory.addCommand(storage, 'ls -la');
      await SecureCommandHistory.addCommand(storage, 'pwd');

      final v2 = await SecureCommandHistory.getHistoryV2(storage);
      expect(v2, hasLength(2));

      for (final entry in v2) {
        // Vérifier la présence des deux champs requis
        expect(entry.containsKey('c'), isTrue, reason: 'Champ "c" manquant');
        expect(entry.containsKey('t'), isTrue, reason: 'Champ "t" manquant');
        // Vérifier les types
        expect(entry['c'], isA<String>());
        expect(entry['t'], isA<int>());
        // Vérifier que le timestamp est cohérent
        expect(entry['t'] as int, greaterThan(0));
      }
    });

    // -------------------------------------------------------------------------
    test('getHistoryV2() retourne une liste immuable', () async {
      await SecureCommandHistory.addCommand(storage, 'ls');

      final v2 = await SecureCommandHistory.getHistoryV2(storage);

      // Tenter de modifier la liste doit lever une erreur
      expect(
        () => v2.add({'c': 'hack', 't': 0}),
        throwsA(anything),
      );
    });
  });

  // =========================================================================
  group('SecureCommandHistory — clear()', () {
    // -------------------------------------------------------------------------
    test('clear() vide l\'historique', () async {
      await SecureCommandHistory.addCommand(storage, 'cmd1');
      await SecureCommandHistory.addCommand(storage, 'cmd2');

      // Vérifier qu'il y a bien des données
      expect(await SecureCommandHistory.count(storage), equals(2));

      await SecureCommandHistory.clear(storage);

      // Après clear, l'historique doit être vide
      final history = await SecureCommandHistory.getHistory(storage);
      expect(history, isEmpty);
    });

    // -------------------------------------------------------------------------
    test('clear() sur un historique vide ne lève pas d\'erreur', () async {
      expect(
        () => SecureCommandHistory.clear(storage),
        returnsNormally,
      );
    });

    // -------------------------------------------------------------------------
    test('on peut ajouter des commandes après clear()', () async {
      await SecureCommandHistory.addCommand(storage, 'avant');
      await SecureCommandHistory.clear(storage);
      await SecureCommandHistory.addCommand(storage, 'apres');

      final history = await SecureCommandHistory.getHistory(storage);
      expect(history, hasLength(1));
      expect(history.first, equals('apres'));
    });
  });

  // =========================================================================
  group('SecureCommandHistory — count()', () {
    // -------------------------------------------------------------------------
    test('count() retourne 0 sur un historique vide', () async {
      final n = await SecureCommandHistory.count(storage);
      expect(n, equals(0));
    });

    // -------------------------------------------------------------------------
    test('count() retourne le bon nombre après ajouts', () async {
      await SecureCommandHistory.addCommand(storage, 'a');
      await SecureCommandHistory.addCommand(storage, 'b');
      await SecureCommandHistory.addCommand(storage, 'c');

      expect(await SecureCommandHistory.count(storage), equals(3));
    });

    // -------------------------------------------------------------------------
    test('count() ne compte pas les entrées expirées', () async {
      // Injecter 2 expirées + 1 récente
      final entries = [
        makeEntry('vieille1', daysAgo: 31),
        makeEntry('vieille2', daysAgo: 60),
        makeEntry('recente', daysAgo: 1),
      ];
      storage.inject('command_history', jsonEncode(entries));

      final n = await SecureCommandHistory.count(storage);
      expect(n, equals(1));
    });
  });

  // =========================================================================
  group('SecureCommandHistory — Robustesse (données corrompues)', () {
    // -------------------------------------------------------------------------
    test('retourne une liste vide si le stockage est vide', () async {
      final history = await SecureCommandHistory.getHistory(storage);
      expect(history, isEmpty);
    });

    // -------------------------------------------------------------------------
    test('retourne une liste vide si le JSON est invalide', () async {
      storage.inject('command_history', 'ceci_nest_pas_du_json{{{{');

      // Ne doit pas planter l'application
      final history = await SecureCommandHistory.getHistory(storage);
      expect(history, isEmpty);
    });

    // -------------------------------------------------------------------------
    test('ignore les entrées avec un format invalide', () async {
      // Mélange d'entrées valides et invalides
      final mixedEntries = [
        {'c': 'valide', 't': timestampDaysAgo(1)},          // valide
        {'c': '', 't': timestampDaysAgo(1)},                 // commande vide → invalide
        {'x': 'mauvais_champ'},                              // champ inconnu → invalide
        {'c': 'valide2', 't': timestampDaysAgo(2)},          // valide
        {'c': 'future', 't': timestampDaysAgo(-100)},        // timestamp futur → invalide
        42,                                                    // pas un Map → ignoré
        'string_au_lieu_de_map',                              // string → ignoré
      ];
      storage.inject('command_history', jsonEncode(mixedEntries));

      final history = await SecureCommandHistory.getHistory(storage);

      // Seules les 2 entrées valides doivent être retournées
      expect(history, hasLength(2));
      expect(history, containsAll(['valide', 'valide2']));
    });

    // -------------------------------------------------------------------------
    test('retourne une liste vide si le JSON est un objet au lieu d\'un tableau', () async {
      // Le format attendu est une List, pas un Map
      storage.inject('command_history', '{"key": "value"}');

      final history = await SecureCommandHistory.getHistory(storage);
      expect(history, isEmpty);
    });
  });
}
