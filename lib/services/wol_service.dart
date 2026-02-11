import 'dart:async';

import 'package:wake_on_lan/wake_on_lan.dart';

import '../models/wol_config.dart';

/// Progression du polling Wake-on-LAN.
///
/// Contient les informations sur la tentative en cours pour
/// afficher un feedback à l'utilisateur.
class WolProgress {
  /// Numéro de la tentative actuelle (1 à maxAttempts)
  final int attempt;

  /// Nombre maximum de tentatives (30 = 5 minutes)
  final int maxAttempts;

  /// Temps écoulé depuis le début du processus
  final Duration elapsed;

  const WolProgress({
    required this.attempt,
    required this.maxAttempts,
    required this.elapsed,
  });

  /// Pourcentage de progression (0.0 à 1.0)
  double get progress => attempt / maxAttempts;

  /// Temps restant estimé avant timeout
  Duration get estimatedRemaining {
    if (attempt == 0) return Duration(seconds: maxAttempts * 10);
    final avgSecondsPerAttempt = elapsed.inSeconds / attempt;
    final remainingAttempts = maxAttempts - attempt;
    return Duration(seconds: (avgSecondsPerAttempt * remainingAttempts).round());
  }
}

/// Service Wake-on-LAN pour réveiller un PC et attendre sa disponibilité.
///
/// Ce service gère l'envoi des magic packets et le polling pour
/// vérifier quand le PC est prêt à accepter une connexion SSH.
///
/// Usage typique:
/// ```dart
/// final wolService = WolService();
///
/// await wolService.wakeAndConnect(
///   config: wolConfig,
///   tryConnect: () async {
///     // Tentative de connexion SSH
///     return await sshService.connect();
///   },
///   onProgress: (progress) {
///     print('Tentative ${progress.attempt}/${progress.maxAttempts}');
///   },
///   onSuccess: () {
///     print('PC réveillé et connecté !');
///   },
///   onError: (error) {
///     print('Erreur: $error');
///   },
/// );
/// ```
class WolService {
  /// Délai entre chaque tentative de connexion (10 secondes)
  static const Duration _pollInterval = Duration(seconds: 10);

  /// Nombre maximum de tentatives (30 × 10s = 5 minutes)
  static const int _maxAttempts = 30;

  /// Completer pour annuler le polling en cours
  Completer<void>? _cancelCompleter;

  /// Indique si un processus de wake est en cours
  bool get isWaking => _cancelCompleter != null && !_cancelCompleter!.isCompleted;

  /// Envoie un magic packet Wake-on-LAN.
  ///
  /// Retourne `true` si le paquet a été envoyé avec succès,
  /// `false` en cas d'erreur (format MAC invalide, réseau indisponible, etc.)
  ///
  /// Note: Le succès de l'envoi ne garantit pas que le PC va se réveiller.
  /// UDP est un protocole sans connexion, donc on ne peut pas confirmer
  /// la réception du paquet.
  Future<bool> sendMagicPacket(WolConfig config) async {
    try {
      // Valider l'adresse MAC
      final macValidation = MACAddress.validate(config.macAddress);
      if (!macValidation.state) {
        return false;
      }

      // Valider l'adresse de broadcast
      final ipValidation = IPAddress.validate(config.broadcastAddress);
      if (!ipValidation.state) {
        return false;
      }

      // Créer les instances
      final macAddress = MACAddress(config.macAddress);
      final ipAddress = IPAddress(config.broadcastAddress);

      // Créer l'instance WakeOnLAN avec le port configuré
      final wakeOnLan = WakeOnLAN(
        ipAddress,
        macAddress,
        port: config.port,
      );

      // Envoyer le magic packet (3 fois pour plus de fiabilité)
      await wakeOnLan.wake(
        repeat: 3,
        repeatDelay: const Duration(milliseconds: 100),
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Réveille un PC et attend qu'il soit disponible pour une connexion SSH.
  ///
  /// Cette méthode:
  /// 1. Tente d'abord une connexion SSH (PC peut-être déjà allumé)
  /// 2. Si échec, envoie un magic packet
  /// 3. Attend 10 secondes puis retente SSH
  /// 4. Répète jusqu'à succès ou timeout (5 minutes)
  ///
  /// [config] Configuration WOL contenant MAC et adresse broadcast
  /// [tryConnect] Callback qui tente la connexion SSH, retourne true si succès
  /// [onProgress] Callback appelé à chaque tentative avec les infos de progression
  /// [onSuccess] Callback appelé quand la connexion SSH réussit
  /// [onError] Callback appelé en cas d'échec (timeout ou erreur)
  Future<void> wakeAndConnect({
    required WolConfig config,
    required Future<bool> Function() tryConnect,
    required void Function(WolProgress) onProgress,
    required void Function() onSuccess,
    required void Function(String) onError,
  }) async {
    // Annuler tout processus précédent
    cancel();

    // Créer un nouveau completer pour ce processus
    _cancelCompleter = Completer<void>();

    final startTime = DateTime.now();

    // Étape 1: Tenter d'abord une connexion SSH (PC peut-être déjà allumé)
    onProgress(WolProgress(
      attempt: 0,
      maxAttempts: _maxAttempts,
      elapsed: Duration.zero,
    ));

    try {
      final connected = await tryConnect();
      // Vérifier si annulé PENDANT tryConnect (l'utilisateur a pu cliquer Annuler)
      if (_cancelCompleter == null || _cancelCompleter!.isCompleted) {
        return;
      }
      if (connected) {
        _cancelCompleter = null;
        onSuccess();
        return;
      }
    } catch (_) {
      // PC pas allumé, on continue avec WOL
    }

    // Vérifier si annulé
    if (_cancelCompleter == null || _cancelCompleter!.isCompleted) {
      return;
    }

    // Étape 2: Envoyer le magic packet
    final sent = await sendMagicPacket(config);
    if (!sent) {
      _cancelCompleter = null;
      onError('ERREUR RÉSEAU - Impossible d\'envoyer le magic packet');
      return;
    }

    // Étape 3-4: Polling jusqu'à connexion réussie ou timeout
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      // Vérifier si annulé
      if (_cancelCompleter == null || _cancelCompleter!.isCompleted) {
        return;
      }

      // Calculer le temps écoulé
      final elapsed = DateTime.now().difference(startTime);

      // Notifier la progression
      onProgress(WolProgress(
        attempt: attempt,
        maxAttempts: _maxAttempts,
        elapsed: elapsed,
      ));

      // Attendre l'intervalle de polling (ou annulation)
      try {
        await Future.any([
          Future.delayed(_pollInterval),
          _cancelCompleter!.future,
        ]);
      } catch (_) {
        // Annulé pendant l'attente
        _cancelCompleter = null;
        return;
      }

      // Vérifier à nouveau si annulé après l'attente
      if (_cancelCompleter == null || _cancelCompleter!.isCompleted) {
        return;
      }

      // Tenter la connexion SSH
      try {
        final connected = await tryConnect();
        // Vérifier si annulé PENDANT tryConnect (l'utilisateur a pu cliquer Annuler)
        if (_cancelCompleter == null || _cancelCompleter!.isCompleted) {
          return;
        }
        if (connected) {
          _cancelCompleter = null;
          onSuccess();
          return;
        }
      } catch (_) {
        // Échec de connexion, on continue le polling
      }

      // Si c'est la dernière tentative et toujours pas connecté
      if (attempt == _maxAttempts) {
        _cancelCompleter = null;
        onError('PC ÉTEINT - Le PC n\'a pas répondu après 5 minutes');
        return;
      }

      // Renvoyer un magic packet toutes les 5 tentatives (50 secondes)
      // pour augmenter les chances de réveil
      if (attempt % 5 == 0) {
        await sendMagicPacket(config);
      }
    }
  }

  /// Annule le processus de wake en cours.
  ///
  /// Si aucun processus n'est en cours, cette méthode ne fait rien.
  void cancel() {
    if (_cancelCompleter != null && !_cancelCompleter!.isCompleted) {
      _cancelCompleter!.complete();
    }
    _cancelCompleter = null;
  }

  /// Libère les ressources du service.
  void dispose() {
    cancel();
  }
}
