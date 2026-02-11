// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'ChillShell';

  @override
  String get settings => 'Paramètres';

  @override
  String get connection => 'Connexion';

  @override
  String get access => 'Accès';

  @override
  String get general => 'Général';

  @override
  String get security => 'Sécurité';

  @override
  String get wol => 'WOL';

  @override
  String get remoteAccess => 'Accès distant';

  @override
  String get tailscaleDescription =>
      'Connectez-vous à votre PC de n\'importe où dans le monde';

  @override
  String get playStore => 'Play Store';

  @override
  String get appStore => 'App Store';

  @override
  String get website => 'Site web';

  @override
  String get noSshKeys => 'Aucune clé SSH. Créez-en une pour vous connecter.';

  @override
  String get theme => 'Thème';

  @override
  String get language => 'Langue';

  @override
  String get fontSize => 'Taille de police';

  @override
  String get fontSizeXXS => 'XXS (10px)';

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
  String get createSshKey => 'Créer une clé SSH';

  @override
  String get importKey => 'Importer une clé';

  @override
  String get importKeySubtitle => 'Fichier .pem ou clé privée';

  @override
  String get selectFile => 'Sélectionner un fichier';

  @override
  String get orPasteKey => 'Ou collez la clé :';

  @override
  String get keyName => 'Nom de la clé';

  @override
  String get publicKey => 'Clé publique';

  @override
  String get privateKey => 'Clé privée';

  @override
  String get keyCopied => 'Clé copiée dans le presse-papiers';

  @override
  String get deleteKey => 'Supprimer la clé';

  @override
  String get savedConnections => 'Connexions sauvegardées';

  @override
  String get autoConnection => 'Connexion automatique';

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
  String get unlock => 'Déverrouillage';

  @override
  String get pinCode => 'Code PIN';

  @override
  String get createPin => 'Créer votre code PIN';

  @override
  String get confirmPin => 'Confirmer votre code PIN';

  @override
  String get enterPin => 'Entrez votre code PIN';

  @override
  String get pinMismatch => 'Les codes PIN ne correspondent pas';

  @override
  String get wrongPin => 'Code PIN incorrect';

  @override
  String get fingerprint => 'Empreinte digitale';

  @override
  String get fingerprintUnavailable =>
      'Aucune empreinte enregistrée sur cet appareil';

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
  String get macAddress => 'Adresse MAC';

  @override
  String get broadcastAddress => 'Adresse de diffusion';

  @override
  String get wolStart => 'WOL START';

  @override
  String get pressKeyForCtrl => 'Appuyez sur une lettre...';

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
  String get configRequired => 'Configuration requise';

  @override
  String get wolDescription =>
      'Le Wake-on-LAN permet d\'allumer votre PC depuis l\'app.';

  @override
  String get turnOnCableRequired => 'Allumer : câble Ethernet requis';

  @override
  String get turnOffWifiOrCable => 'Éteindre : WiFi ou câble';

  @override
  String get fullGuide => 'Guide complet';

  @override
  String get linkCopied => 'Lien copié';

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

  @override
  String get uploadingImage => 'Envoi de l\'image...';

  @override
  String get uploadFailed => 'Échec de l\'envoi de l\'image';

  @override
  String get ok => 'OK';

  @override
  String errorMessage(String error) {
    return 'Erreur : $error';
  }

  @override
  String get invalidKeyFormat => 'Format de clé invalide';

  @override
  String get keyFileTooLarge =>
      'Fichier trop volumineux (max 16 Ko). Les clés SSH sont de petits fichiers.';

  @override
  String keyImported(String name) {
    return 'Clé \"$name\" importée';
  }

  @override
  String get deleteKeyConfirmTitle => 'Supprimer la clé ?';

  @override
  String get actionIrreversible => 'Cette action est irréversible.';

  @override
  String deleteKeysConfirm(int count) {
    return 'Supprimer $count clé(s) ?';
  }

  @override
  String deleteConnectionsConfirm(int count) {
    return 'Supprimer $count connexion(s) ?';
  }

  @override
  String deleteWolConfigsConfirm(int count) {
    return 'Supprimer $count config(s) ?';
  }

  @override
  String sshKeyTypeLabel(String type) {
    return 'Type : $type';
  }

  @override
  String sshKeyHostLabel(String host) {
    return 'Hôte : $host';
  }

  @override
  String sshKeyLastUsedLabel(String date) {
    return 'Dernière utilisation : $date';
  }

  @override
  String get shutdownPcTitle => 'Éteindre le PC';

  @override
  String shutdownPcMessage(String name) {
    return 'Voulez-vous vraiment éteindre $name ?\n\nLa connexion SSH sera fermée.';
  }

  @override
  String get shutdownAction => 'Éteindre';

  @override
  String get searchPlaceholder => 'Rechercher...';

  @override
  String get autoDetect => 'Auto';

  @override
  String get wolBiosTitle => '1. BIOS';

  @override
  String get wolBiosEnablePcie => 'Activer \"Power On By PCI-E\"';

  @override
  String get wolBiosDisableErp => 'Désactiver \"ErP Ready\"';

  @override
  String get wolFastStartupTitle => '2. Démarrage rapide';

  @override
  String get wolFastStep1 => 'Options d\'alimentation → Paramètre système';

  @override
  String get wolFastStep2 => 'Modifier les paramètres non disponibles';

  @override
  String get wolFastStep3 => 'Décocher \"Activer le démarrage rapide\"';

  @override
  String get wolDeviceManagerTitle => '3. Gestionnaire de périphériques';

  @override
  String get wolDevStep1 => 'Carte réseau → Gestion alimentation';

  @override
  String get wolDevStep2 => 'Cocher \"Paquet magique uniquement\"';

  @override
  String get wolDevStep3 => 'Carte réseau → Avancé';

  @override
  String get wolDevStep4 => 'Activer \"Wake on Magic Packet\"';

  @override
  String get wolMacConfigTitle => 'Configuration';

  @override
  String get wolMacStep1 => '1. Menu Apple → Préférences Système';

  @override
  String get wolMacStep2 => '2. Économiseur d\'énergie';

  @override
  String get wolMacStep3 => '3. Cocher \"Réactiver pour l\'accès au réseau\"';

  @override
  String get sshKeySecurityTitle => 'Protéger vos clés';

  @override
  String get sshKeySecurityDesc =>
      'Vos clés SSH fonctionnent comme des mots de passe qui donnent accès à vos serveurs. La clé privée ne doit JAMAIS être partagée — ni par email, messagerie, ni stockée dans le cloud. Partagez uniquement la clé publique avec les serveurs auxquels vous souhaitez vous connecter. ChillShell stocke vos clés de manière sécurisée uniquement sur votre appareil. Si vous suspectez qu\'une clé a été compromise, supprimez-la immédiatement et créez-en une nouvelle.';

  @override
  String get sshHostKeyTitle => 'Nouveau serveur';

  @override
  String sshHostKeyMessage(String host) {
    return 'Vous vous connectez à $host pour la première fois.\nVérifiez l\'empreinte du serveur avant de continuer :';
  }

  @override
  String sshHostKeyType(String type) {
    return 'Type : $type';
  }

  @override
  String get sshHostKeyFingerprint => 'Empreinte :';

  @override
  String get sshHostKeyAccept => 'Faire confiance';

  @override
  String get sshHostKeyReject => 'Refuser';

  @override
  String get sshHostKeyMismatchTitle => 'Attention — Clé modifiée !';

  @override
  String sshHostKeyMismatchMessage(String host) {
    return 'La clé du serveur $host a changé !\n\nCela pourrait indiquer une attaque de type man-in-the-middle. Si vous n\'avez pas modifié la configuration du serveur, refusez cette connexion.';
  }

  @override
  String get rootedDeviceWarning =>
      'Attention : Cet appareil semble rooté. La sécurité des clés SSH peut être compromise.';

  @override
  String tooManyAttempts(int seconds) {
    return 'Trop de tentatives. Réessayez dans $seconds s';
  }

  @override
  String tryAgainIn(int seconds) {
    return 'Réessayez dans $seconds s';
  }

  @override
  String get sshConnectionFailed =>
      'Connexion impossible. Vérifiez l\'adresse du serveur.';

  @override
  String get sshAuthFailed =>
      'Authentification échouée. Vérifiez votre clé SSH.';

  @override
  String get sshKeyNotConfigured => 'Aucune clé SSH configurée pour cet hôte.';

  @override
  String get sshTimeout => 'Délai d\'attente dépassé.';

  @override
  String get sshHostUnreachable => 'Serveur injoignable. Vérifiez Tailscale.';

  @override
  String get connectionLost => 'Connexion perdue';

  @override
  String get biometricReason =>
      'Déverrouillez ChillShell pour accéder à vos sessions SSH';

  @override
  String get biometricFingerprint => 'Empreinte digitale';

  @override
  String get biometricIris => 'Iris';

  @override
  String get biometricGeneric => 'Biométrie';

  @override
  String get localShellError => 'Erreur du shell local';

  @override
  String reconnectingAttempt(String current, String max) {
    return 'Reconnexion... (tentative $current/$max)';
  }

  @override
  String get unexpectedError => 'Erreur inattendue';

  @override
  String get allowScreenshots => 'Captures d\'écran';

  @override
  String get allowScreenshotsWarning =>
      'Lorsque activé, les captures d\'écran et l\'enregistrement d\'écran sont autorisés. Attention à ne pas partager d\'informations sensibles (clés SSH, mots de passe, adresses serveurs).';

  @override
  String get rename => 'Renommer';

  @override
  String get renameDialogHint => 'Nouveau nom';

  @override
  String get nameCannotBeEmpty => 'Le nom ne peut pas être vide';

  @override
  String get tailscaleLogin => 'Se connecter';

  @override
  String get tailscaleCreateAccount => 'Créer un compte';

  @override
  String get tailscaleAuthPrompt =>
      'Créez votre compte Tailscale et authentifiez-vous directement depuis l\'application';

  @override
  String get tailscaleWhatIs => 'Qu\'est-ce que Tailscale ?';

  @override
  String get tailscaleExplainer =>
      'Tailscale crée un réseau privé sécurisé entre vos appareils, accessible de partout (WiFi, 4G, 5G) sans configuration complexe.';

  @override
  String get tailscaleConnected => 'Connecté';

  @override
  String get tailscaleDisconnected => 'Déconnecté';

  @override
  String get tailscaleMyIP => 'Mon IP';

  @override
  String get tailscaleMyDevices => 'Mes appareils';

  @override
  String tailscaleDevicesCount(int count) {
    return 'Mes appareils ($count)';
  }

  @override
  String get tailscaleCopyIP => 'Copier l\'IP';

  @override
  String get tailscaleDisconnect => 'Se déconnecter';

  @override
  String get tailscaleOnline => 'En ligne';

  @override
  String get tailscaleOffline => 'Hors ligne';

  @override
  String get tailscaleIPCopied => 'IP copiée';

  @override
  String get tailscaleTab => 'Tailscale';
}
