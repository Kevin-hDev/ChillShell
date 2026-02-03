// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'VibeTerm';

  @override
  String get settings => 'Paramètres';

  @override
  String get connection => 'Connexion';

  @override
  String get general => 'Général';

  @override
  String get security => 'Sécurité';

  @override
  String get wol => 'WOL';

  @override
  String get theme => 'Thème';

  @override
  String get language => 'Langue';

  @override
  String get fontSize => 'Taille de police';

  @override
  String get fontSizeXS => 'XS (12px)';

  @override
  String get fontSizeS => 'S (14px)';

  @override
  String get fontSizeM => 'M (17px)';

  @override
  String get fontSizeL => 'L (20px)';

  @override
  String get fontSizeXL => 'XL (24px)';

  @override
  String get disconnect => 'Déconnecter';

  @override
  String get disconnectAll => 'Tout déconnecter';

  @override
  String get disconnectConfirmTitle => 'Déconnexion';

  @override
  String get disconnectConfirmMessage =>
      'Voulez-vous fermer toutes les connexions SSH ?';

  @override
  String get connect => 'Connecter';

  @override
  String get cancel => 'Annuler';

  @override
  String get save => 'Enregistrer';

  @override
  String get delete => 'Supprimer';

  @override
  String get add => 'Ajouter';

  @override
  String get edit => 'Modifier';

  @override
  String get retry => 'Réessayer';

  @override
  String get noConnection => 'Aucune connexion';

  @override
  String get connectToServer => 'Connectez-vous à un serveur SSH';

  @override
  String get newConnection => 'Nouvelle connexion';

  @override
  String get connectionInProgress => 'Connexion en cours...';

  @override
  String get reconnecting => 'Reconnexion...';

  @override
  String get connectionLost => 'Connexion perdue';

  @override
  String get connectionError => 'Erreur de connexion';

  @override
  String get reconnect => 'Reconnecter';

  @override
  String get terminal => 'Terminal';

  @override
  String get runCommands => 'Exécuter des commandes';

  @override
  String get localShell => 'Shell local';

  @override
  String get localShellNotAvailable => 'Non disponible sur iOS';

  @override
  String get localShellIOSMessage =>
      'iOS ne permet pas l\'accès au shell local. Les connexions SSH fonctionnent normalement.';

  @override
  String get copy => 'Copier';

  @override
  String get paste => 'Coller';

  @override
  String get sshKeys => 'Clés SSH';

  @override
  String get generateKey => 'Générer une clé';

  @override
  String get keyName => 'Nom de la clé';

  @override
  String get keyType => 'Type de clé';

  @override
  String get publicKey => 'Clé publique';

  @override
  String get privateKey => 'Clé privée';

  @override
  String get copyPublicKey => 'Copier la clé publique';

  @override
  String get keyCopied => 'Clé copiée dans le presse-papiers';

  @override
  String get deleteKey => 'Supprimer la clé';

  @override
  String get deleteKeyConfirm => 'Supprimer cette clé SSH ?';

  @override
  String get savedConnections => 'Connexions sauvegardées';

  @override
  String get host => 'Hôte';

  @override
  String get port => 'Port';

  @override
  String get username => 'Utilisateur';

  @override
  String get selectKey => 'Sélectionner une clé';

  @override
  String get saveConnection => 'Enregistrer la connexion';

  @override
  String get deleteConnection => 'Supprimer la connexion';

  @override
  String get biometricUnlock => 'Déverrouillage biométrique';

  @override
  String get faceId => 'Face ID';

  @override
  String get fingerprint => 'Empreinte digitale';

  @override
  String get autoLock => 'Verrouillage auto';

  @override
  String get autoLockTime => 'Temps de verrouillage';

  @override
  String get minutes => 'minutes';

  @override
  String get clearHistory => 'Effacer l\'historique';

  @override
  String get clearHistoryConfirm =>
      'Supprimer tout l\'historique des commandes ?';

  @override
  String get historyCleared => 'Historique effacé';

  @override
  String get wolEnabled => 'Wake-on-LAN activé';

  @override
  String get wolConfigs => 'Configurations WOL';

  @override
  String get addWolConfig => 'Ajouter une configuration WOL';

  @override
  String get wolName => 'Nom';

  @override
  String get macAddress => 'Adresse MAC';

  @override
  String get broadcastAddress => 'Adresse de diffusion';

  @override
  String get udpPort => 'Port UDP';

  @override
  String get linkedConnection => 'Connexion SSH associée';

  @override
  String get wolStart => 'WOL START';

  @override
  String get wakingUp => 'Réveil en cours...';

  @override
  String get waitingForBoot => 'Démarrage en cours...';

  @override
  String get tryingToConnect => 'Tentative de connexion...';

  @override
  String get pcAwake => 'PC réveillé !';

  @override
  String get wolFailed => 'Échec du Wake-on-LAN';

  @override
  String get shutdown => 'Éteindre';

  @override
  String get shutdownConfirm => 'Éteindre ce PC ?';

  @override
  String get pressKeyForCtrl => 'Appuyez sur une lettre...';

  @override
  String get swipeDownToReduce => 'Swipe vers le bas pour réduire...';

  @override
  String wolWakingUp(Object name) {
    return 'Réveil de $name en cours...';
  }

  @override
  String wolAttempt(Object attempt, Object maxAttempts) {
    return 'Tentative $attempt/$maxAttempts';
  }

  @override
  String get wolConnected => 'Connecté !';

  @override
  String wolPcAwake(Object name) {
    return '$name allumé';
  }

  @override
  String get wolSshEstablished => 'Connexion SSH établie';

  @override
  String get back => 'Retour';

  @override
  String get addPc => 'Ajouter un PC';

  @override
  String get pcName => 'Nom du PC';

  @override
  String get pcNameRequired => 'Le nom est obligatoire';

  @override
  String get macAddressRequired => 'L\'adresse MAC est obligatoire';

  @override
  String get macAddressInvalid => 'Format invalide (ex: AA:BB:CC:DD:EE:FF)';

  @override
  String get howToFindMac => 'Comment trouver l\'adresse MAC ?';

  @override
  String get linkedSshConnection => 'Connexion SSH associée *';

  @override
  String get selectConnection => 'Sélectionner une connexion';

  @override
  String get noSavedConnections => 'Aucune connexion sauvegardée';

  @override
  String get advancedOptions => 'Options avancées (WOL distant)';

  @override
  String get broadcastOptional => 'Adresse broadcast (optionnel)';

  @override
  String get defaultBroadcast => 'Par défaut: 255.255.255.255';

  @override
  String get udpPortOptional => 'Port UDP (optionnel)';

  @override
  String get defaultPort => 'Par défaut: 9';

  @override
  String get portRange => 'Port entre 1 et 65535';

  @override
  String get pleaseSelectSshConnection =>
      'Veuillez sélectionner une connexion SSH';

  @override
  String configAdded(Object name) {
    return 'Configuration \"$name\" ajoutée';
  }

  @override
  String get findMacAddress => 'Trouver l\'adresse MAC';

  @override
  String get macAddressFormat =>
      'L\'adresse MAC ressemble à : AA:BB:CC:DD:EE:FF';

  @override
  String get understood => 'Compris';

  @override
  String get quickConnections => 'CONNEXIONS RAPIDES';

  @override
  String get autoConnectOnStart => 'Connexion auto au démarrage';

  @override
  String get autoConnectOnStartDesc =>
      'Se connecter automatiquement à la dernière connexion';

  @override
  String get autoReconnect => 'Reconnexion automatique';

  @override
  String get autoReconnectDesc => 'Reconnecter en cas de perte de connexion';

  @override
  String get disconnectNotification => 'Notification de déconnexion';

  @override
  String get disconnectNotificationDesc =>
      'Afficher une notification en cas de déconnexion';

  @override
  String get deleteConnectionConfirm => 'Supprimer la connexion ?';

  @override
  String deleteConnectionConfirmMessage(Object name) {
    return 'Voulez-vous supprimer \"$name\" de vos connexions sauvegardées ?';
  }

  @override
  String get noWolConfig =>
      'Aucune configuration. Ajoutez-en une pour activer le WOL.';

  @override
  String terminalTab(Object number) {
    return 'Terminal $number';
  }

  @override
  String get wakeUpPc => 'Allumer un PC';

  @override
  String get connectionLostSnack => 'Connexion perdue';

  @override
  String get unableToCreateTab => 'Impossible de créer un nouvel onglet';

  @override
  String get privateKeyNotFound => 'Clé privée introuvable';
}
