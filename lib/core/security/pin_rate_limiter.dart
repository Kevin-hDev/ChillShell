// =============================================================================
// FIX-004 — PIN Rate Limiter
// =============================================================================
// Probleme corrige : GAP-004
// Sans ce fix, un attaquant peut brute-forcer le PIN indefiniment.
// Avec ce fix, chaque serie d'echecs declenche un verrouillage exponentiel,
// et 10 echecs consecutifs effacent toutes les donnees sensibles.
//
// INTEGRATION:
// 1. Dans pin_service.dart:verifyPin(), ajouter AVANT la verification :
//    final check = await PinRateLimiter.instance.canAttempt();
//    if (!check.allowed) throw PinLockedException(check.waitTime);
// 2. Apres un echec : await PinRateLimiter.instance.recordFailure();
// 3. Apres un succes : await PinRateLimiter.instance.recordSuccess();
// 4. Connecter onWipeRequired a la suppression de toutes les cles sensibles.
// =============================================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// Exception levee quand le PIN est verrouille
// ---------------------------------------------------------------------------
class PinLockedException implements Exception {
  /// Temps restant avant que le verrouillage soit leve.
  final Duration waitTime;

  const PinLockedException(this.waitTime);

  @override
  String toString() =>
      'PIN verrouille. Attendre ${waitTime.inSeconds} secondes.';
}

// ---------------------------------------------------------------------------
// Resultat de canAttempt()
// ---------------------------------------------------------------------------
class AttemptCheckResult {
  /// true si l'utilisateur est autorise a tenter le PIN maintenant.
  final bool allowed;

  /// Temps restant avant que le verrou soit leve (null si allowed == true).
  final Duration? waitTime;

  const AttemptCheckResult({required this.allowed, this.waitTime});
}

// ---------------------------------------------------------------------------
// PinRateLimiter
// ---------------------------------------------------------------------------
/// Protege le PIN contre le brute-force.
///
/// Logique :
/// - Apres [maxAttempts] echecs consecutifs, un verrou temporaire est applique.
/// - La duree du verrou augmente exponentiellement selon [lockoutDurations].
/// - Apres [wipeAfterAttempts] echecs au total, [onWipeRequired] est appele.
/// - Un succes remet tous les compteurs a zero.
class PinRateLimiter {
  // -------------------------------------------------------------------------
  // Singleton
  // -------------------------------------------------------------------------
  PinRateLimiter._internal();
  static final PinRateLimiter instance = PinRateLimiter._internal();

  // -------------------------------------------------------------------------
  // Dependance — stockage securise
  // -------------------------------------------------------------------------
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // -------------------------------------------------------------------------
  // Cles de stockage (noms neutres — pas de mot "pin", "fail", etc.)
  // -------------------------------------------------------------------------
  static const String _failedAttemptsKey = 'auth_counter_a';
  static const String _lastFailedAtKey   = 'auth_ts_a';
  static const String _lockoutUntilKey   = 'auth_hold_until';

  // -------------------------------------------------------------------------
  // Constantes de comportement
  // -------------------------------------------------------------------------

  /// Nombre d'echecs avant le premier verrouillage.
  static const int maxAttempts = 5;

  /// Durees de verrouillage par palier (exponentiel).
  /// Palier 0 (5 echecs)   -> 30 secondes
  /// Palier 1 (6 echecs)   -> 1 minute
  /// Palier 2 (7 echecs)   -> 5 minutes
  /// Palier 3+ (8+ echecs) -> 15 minutes
  static const List<Duration> lockoutDurations = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(minutes: 15),
  ];

  /// Nombre total d'echecs apres lequel l'effacement est declenche.
  static const int wipeAfterAttempts = 10;

  // -------------------------------------------------------------------------
  // Callback d'effacement total
  // -------------------------------------------------------------------------
  /// Appele quand le seuil d'effacement est atteint.
  /// L'appelant doit connecter ce callback a la suppression de toutes les
  /// cles sensibles (PIN hash, salt, session tokens, etc.).
  void Function()? onWipeRequired;

  // -------------------------------------------------------------------------
  // canAttempt()
  // -------------------------------------------------------------------------
  /// Verifie si l'utilisateur est autorise a tenter le PIN maintenant.
  ///
  /// Retourne [AttemptCheckResult.allowed] == true si autorise.
  /// Retourne [AttemptCheckResult.waitTime] avec le temps restant si bloque.
  Future<AttemptCheckResult> canAttempt() async {
    final lockoutUntilRaw = await _storage.read(key: _lockoutUntilKey);

    if (lockoutUntilRaw != null) {
      final lockoutUntil =
          DateTime.fromMillisecondsSinceEpoch(int.parse(lockoutUntilRaw));
      final now = DateTime.now();

      if (now.isBefore(lockoutUntil)) {
        // Verrou actif — calculer le temps restant
        final remaining = lockoutUntil.difference(now);
        return AttemptCheckResult(allowed: false, waitTime: remaining);
      }

      // Le verrou a expire — le nettoyer mais GARDER le compteur d'echecs
      // pour permettre le calcul du prochain palier exponentiel.
      await _storage.delete(key: _lockoutUntilKey);
    }

    return const AttemptCheckResult(allowed: true);
  }

  // -------------------------------------------------------------------------
  // recordFailure()
  // -------------------------------------------------------------------------
  /// Enregistre un echec d'authentification.
  ///
  /// Incremente le compteur, calcule le verrou si necessaire,
  /// et declenche l'effacement si le seuil critique est atteint.
  Future<void> recordFailure() async {
    // --- Lire le compteur actuel ---
    final raw = await _storage.read(key: _failedAttemptsKey);
    final failedAttempts = int.tryParse(raw ?? '0') ?? 0;
    final newCount = failedAttempts + 1;

    // --- Sauvegarder le nouveau compteur et l'horodatage ---
    await _storage.write(
      key: _failedAttemptsKey,
      value: newCount.toString(),
    );
    await _storage.write(
      key: _lastFailedAtKey,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    // --- Verifier si on atteint le seuil d'effacement ---
    if (newCount >= wipeAfterAttempts) {
      // Nettoyer le rate limiter lui-meme avant d'appeler le wipe
      await _deleteAllKeys();
      onWipeRequired?.call();
      return;
    }

    // --- Verifier si on doit appliquer un verrou ---
    if (newCount >= maxAttempts) {
      // Calculer le palier exponentiel
      // palier 0 : newCount == maxAttempts (5)
      // palier 1 : newCount == maxAttempts + 1 (6)
      // palier 2 : newCount == maxAttempts + 2 (7)
      // ...
      final palierIndex = (newCount - maxAttempts)
          .clamp(0, lockoutDurations.length - 1);
      final lockoutDuration = lockoutDurations[palierIndex];
      final lockoutUntil =
          DateTime.now().add(lockoutDuration).millisecondsSinceEpoch;

      await _storage.write(
        key: _lockoutUntilKey,
        value: lockoutUntil.toString(),
      );
    }
  }

  // -------------------------------------------------------------------------
  // recordSuccess()
  // -------------------------------------------------------------------------
  /// Enregistre une authentification reussie et reinitialise tous les
  /// compteurs. Doit etre appele APRES une verification PIN positive.
  Future<void> recordSuccess() async {
    await _deleteAllKeys();
  }

  // -------------------------------------------------------------------------
  // reset()
  // -------------------------------------------------------------------------
  /// Reinitialise de force tous les compteurs.
  /// Reservee a l'administration (acces biometrique ou recuperation).
  /// NE PAS exposer a l'utilisateur normal.
  Future<void> reset() async {
    await _deleteAllKeys();
  }

  // -------------------------------------------------------------------------
  // Methode interne de nettoyage
  // -------------------------------------------------------------------------
  Future<void> _deleteAllKeys() async {
    await Future.wait([
      _storage.delete(key: _failedAttemptsKey),
      _storage.delete(key: _lastFailedAtKey),
      _storage.delete(key: _lockoutUntilKey),
    ]);
  }

  // -------------------------------------------------------------------------
  // Methode utilitaire de lecture (pour debug et tests)
  // -------------------------------------------------------------------------
  /// Retourne le nombre d'echecs actuellement enregistres.
  /// Ne pas exposer en production sans controle d'acces.
  Future<int> getFailedAttemptCount() async {
    final raw = await _storage.read(key: _failedAttemptsKey);
    return int.tryParse(raw ?? '0') ?? 0;
  }
}
