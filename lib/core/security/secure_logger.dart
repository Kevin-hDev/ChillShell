// =============================================================================
// FIX-002 — SecureLogger
// Problème corrigé : GAP-002 — 197 debugPrint() en production lisibles via ADB
// =============================================================================
//
// CONTEXTE DU PROBLÈME :
// Le code ChillShell contient 197 appels à debugPrint() avec des informations
// sensibles : adresses IP, ports, noms d'utilisateur, chemins de fichiers.
//
// En mode RELEASE, kDebugMode == false MAIS debugPrint() N'EST PAS supprimé
// par le compilateur Dart/Flutter. Les chaînes sont toujours formatées et
// envoyées au système de log. Sur Android, elles sont lisibles via :
//   adb logcat | grep flutter
//
// Exemples de fuites constatées :
//   debugPrint('SSHService: Connecting to $host:$port'); // IP + port
//   debugPrint('SSHService: Authenticating as $username'); // username
//   debugPrint('LocalShell: Starting shell: $shell');     // chemin
//
// SOLUTION :
// Remplacer TOUS les debugPrint par SecureLogger.log() qui :
//   1. En mode RELEASE → ne fait RIEN (même pas formater la String)
//   2. En mode DEBUG → filtre les patterns sensibles avant d'écrire
//
// INTEGRATION :
// Remplacer TOUS les debugPrint par SecureLogger.log('TAG', 'message')
//
// Recherche globale :
//   grep -rn "debugPrint" --include="*.dart" lib/
//
// Remplacement :
//   AVANT : debugPrint('SSHService: Connecting to $host:$port...');
//   APRÈS : SecureLogger.log('SSHService', 'Connecting to host...');
//           // NE JAMAIS inclure $host, $port, $username dans le message
//
// Pour les cas où l'info est vraiment nécessaire en debug :
//   AVANT : debugPrint('SSHService: Error on $host: $error');
//   APRÈS : SecureLogger.logDebugOnly('SSHService', 'Error on [host]: ${error.runtimeType}');
// =============================================================================

import 'package:flutter/foundation.dart'; // kDebugMode

/// Logger sécurisé pour ChillShell.
///
/// Remplace tous les appels à [debugPrint] pour garantir :
/// - Silence total en mode RELEASE (aucun log, aucun formatage)
/// - Filtrage des données sensibles en mode DEBUG
/// - Troncature des messages longs
///
/// Usage :
/// ```dart
/// // Simple
/// SecureLogger.log('SSHService', 'Connexion établie');
///
/// // Ne log JAMAIS (même en debug) — pour les opérations critiques
/// SecureLogger.logSensitive('KeyService', 'Chargement de la clé');
///
/// // Uniquement en debug local — jamais en production
/// SecureLogger.logDebugOnly('Parser', 'Résultat: $someValue');
/// ```
class SecureLogger {
  // ---------------------------------------------------------------------------
  // Constantes de configuration
  // ---------------------------------------------------------------------------

  /// Longueur maximale d'un message de log.
  ///
  /// Les messages plus longs sont tronqués pour éviter :
  /// - Les logs qui contiennent accidentellement de gros blocs de données
  /// - Les performances dégradées par la sérialisation de grandes Strings
  static const int _maxLogLength = 200;

  /// Marqueur de troncature ajouté à la fin des messages tronqués.
  static const String _truncationMarker = '...[tronqué]';

  // ---------------------------------------------------------------------------
  // Patterns sensibles à filtrer
  // ---------------------------------------------------------------------------

  /// Expressions régulières des patterns qui ne doivent jamais apparaître
  /// dans les logs, même en mode debug.

  // Adresses IPv4 : 192.168.1.1, 10.0.0.1, etc.
  static final RegExp _ipPattern = RegExp(
    r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}',
  );

  // Ports réseaux : :22, :8080, :443, etc. (2 à 5 chiffres après un ':'
  // précédé d'un espace ou d'un autre chiffre)
  static final RegExp _portPattern = RegExp(
    r':\d{2,5}(?=\s|$|[^/])',
  );

  // Pattern "as username" (authentification SSH)
  static final RegExp _usernamePattern = RegExp(
    r'\bas\s+\w+',
    caseSensitive: false,
  );

  // Chemins de fichiers absolus : /home/user/..., /etc/ssh/..., etc.
  static final RegExp _filePathPattern = RegExp(
    r"""/[^\s,;:'"]{3,}""",
  );

  // Clés, tokens, hashes : longues chaînes hexadécimales ou base64
  // Détecte les chaînes de 20+ caractères de hex ou base64
  static final RegExp _keyLikePattern = RegExp(
    r'[A-Fa-f0-9]{32,}|[A-Za-z0-9+/]{32,}={0,2}',
  );

  // Email addresses
  static final RegExp _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}',
  );

  // Liste de tous les patterns sensibles avec leur remplacement
  static final List<_SensitivePattern> _sensitivePatterns = [
    _SensitivePattern(_ipPattern, '[IP]'),
    _SensitivePattern(_portPattern, ':[PORT]'),
    _SensitivePattern(_usernamePattern, 'as [USER]'),
    _SensitivePattern(_filePathPattern, '[PATH]'),
    _SensitivePattern(_keyLikePattern, '[KEY/TOKEN]'),
    _SensitivePattern(_emailPattern, '[EMAIL]'),
  ];

  // ---------------------------------------------------------------------------
  // API publique
  // ---------------------------------------------------------------------------

  /// Log standard — filtré et tronqué.
  ///
  /// En mode RELEASE : ne fait absolument rien.
  /// En mode DEBUG : filtre les patterns sensibles, tronque à 200 caractères.
  ///
  /// [tag] : Identifiant de la source (ex: 'SSHService', 'KeyService')
  /// [message] : Message à logger — NE PAS inclure d'infos sensibles
  static void log(String tag, String message) {
    // RÈGLE CRITIQUE : En release, on ne fait RIEN.
    // Pas de formatage, pas d'allocation String, rien.
    if (!kDebugMode) {
      return;
    }

    final sanitized = _sanitize(message);
    final truncated = _truncate(sanitized);
    debugPrint('[$tag] $truncated');
  }

  /// Log critique — ne log JAMAIS, en aucune circonstance.
  ///
  /// À utiliser pour les opérations sur des données sensibles :
  /// - Chargement/parsing d'une clé SSH
  /// - Authentification
  /// - Décryptage
  ///
  /// Cette méthode existe pour documenter l'intention : on sait que
  /// l'opération est sensible, et on choisit explicitement de ne rien logger.
  ///
  /// [tag] et [message] sont ignorés. Retourne toujours une chaîne générique.
  static String logSensitive(String tag, String message) {
    // INTENTIONNELLEMENT VIDE.
    // Ne pas logger. Ne rien retourner de l'opération.
    // Le paramètre message est accepté pour faciliter la migration
    // (remplacement de debugPrint sans changer la signature d'appel)
    // mais son contenu est ignoré.
    return '[opération sécurisée]';
  }

  /// Log uniquement en debug local — filtre quand même les patterns sensibles.
  ///
  /// Différence avec [log] : accepte explicitement que le message peut
  /// contenir plus de détails techniques. Mais le filtrage s'applique quand même.
  ///
  /// En mode RELEASE : ne fait absolument rien.
  static void logDebugOnly(String tag, String message) {
    if (!kDebugMode) {
      return;
    }
    final sanitized = _sanitize(message);
    final truncated = _truncate(sanitized);
    debugPrint('[DEBUG][$tag] $truncated');
  }

  /// Log d'erreur — affiche le type de l'erreur mais PAS le message complet.
  ///
  /// Évite de logger des stack traces ou des messages d'erreur qui pourraient
  /// contenir des chemins de fichiers, des hostnames, etc.
  ///
  /// En mode RELEASE : ne fait absolument rien.
  static void logError(String tag, Object error) {
    if (!kDebugMode) {
      return;
    }
    // On log uniquement le TYPE de l'erreur, pas son message.
    // error.toString() peut contenir des infos sensibles.
    debugPrint('[ERROR][$tag] ${error.runtimeType}');
  }

  /// Log de début d'une opération importante (pour tracer les flux).
  ///
  /// Utile pour le debug de problèmes de performance ou de flux.
  /// Ne jamais inclure de données dans le [operationName].
  ///
  /// En mode RELEASE : ne fait absolument rien.
  static void logOperation(String tag, String operationName) {
    if (!kDebugMode) {
      return;
    }
    // Sanitize même les noms d'opérations par sécurité.
    final safe = _sanitize(operationName);
    final truncated = _truncate(safe);
    debugPrint('[OP][$tag] $truncated');
  }

  // ---------------------------------------------------------------------------
  // Méthodes privées de traitement
  // ---------------------------------------------------------------------------

  /// Applique tous les filtres de patterns sensibles sur [message].
  ///
  /// Retourne une version sanitisée où les données sensibles sont remplacées
  /// par des marqueurs génériques.
  static String _sanitize(String message) {
    String result = message;
    for (final pattern in _sensitivePatterns) {
      result = result.replaceAll(pattern.regex, pattern.replacement);
    }
    return result;
  }

  /// Tronque [message] à [_maxLogLength] caractères si nécessaire.
  ///
  /// Ajoute le marqueur '[tronqué]' pour signaler la troncature.
  static String _truncate(String message) {
    if (message.length <= _maxLogLength) {
      return message;
    }
    // On laisse de la place pour le marqueur de troncature.
    final cutLength = _maxLogLength - _truncationMarker.length;
    return '${message.substring(0, cutLength)}$_truncationMarker';
  }
}

// =============================================================================
// Classe utilitaire interne
// =============================================================================

/// Paire (regex, remplacement) pour le filtrage des patterns sensibles.
class _SensitivePattern {
  final RegExp regex;
  final String replacement;

  const _SensitivePattern(this.regex, this.replacement);
}
