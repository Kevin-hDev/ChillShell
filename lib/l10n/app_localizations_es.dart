// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'ChillShell';

  @override
  String get settings => 'Ajustes';

  @override
  String get connection => 'Conexión';

  @override
  String get access => 'Acceso';

  @override
  String get general => 'General';

  @override
  String get security => 'Seguridad';

  @override
  String get wol => 'WOL';

  @override
  String get remoteAccess => 'Acceso remoto';

  @override
  String get tailscaleDescription =>
      'Conéctate a tu PC desde cualquier parte del mundo';

  @override
  String get playStore => 'Play Store';

  @override
  String get appStore => 'App Store';

  @override
  String get website => 'Sitio web';

  @override
  String get noSshKeys => 'Sin claves SSH. Crea una para conectarte.';

  @override
  String get theme => 'Tema';

  @override
  String get language => 'Idioma';

  @override
  String get fontSize => 'Tamaño de fuente';

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
  String get disconnect => 'Desconectar';

  @override
  String get disconnectConfirmTitle => 'Desconexión';

  @override
  String get disconnectConfirmMessage =>
      '¿Desea cerrar todas las conexiones SSH?';

  @override
  String get connect => 'Conectar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get add => 'Añadir';

  @override
  String get retry => 'Reintentar';

  @override
  String get noConnection => 'Sin conexión';

  @override
  String get connectToServer => 'Conéctese a un servidor SSH';

  @override
  String get newConnection => 'Nueva conexión';

  @override
  String get connectionInProgress => 'Conectando...';

  @override
  String get reconnecting => 'Reconectando...';

  @override
  String get connectionError => 'Error de conexión';

  @override
  String get reconnect => 'Reconectar';

  @override
  String get terminal => 'Terminal';

  @override
  String get runCommands => 'Ejecutar comandos';

  @override
  String get localShell => 'Shell local';

  @override
  String get localShellNotAvailable => 'No disponible en iOS';

  @override
  String get localShellIOSMessage =>
      'iOS no permite el acceso al shell local. Las conexiones SSH funcionan normalmente.';

  @override
  String get copy => 'Copiar';

  @override
  String get paste => 'Pegar';

  @override
  String get sshKeys => 'Claves SSH';

  @override
  String get createSshKey => 'Crear clave SSH';

  @override
  String get importKey => 'Importar clave';

  @override
  String get importKeySubtitle => 'Archivo .pem o clave privada';

  @override
  String get selectFile => 'Seleccionar archivo';

  @override
  String get orPasteKey => 'O pega la clave:';

  @override
  String get keyName => 'Nombre de la clave';

  @override
  String get publicKey => 'Clave pública';

  @override
  String get privateKey => 'Clave privada';

  @override
  String get keyCopied => 'Clave copiada al portapapeles';

  @override
  String get deleteKey => 'Eliminar clave';

  @override
  String get savedConnections => 'Conexiones guardadas';

  @override
  String get autoConnection => 'Conexión automática';

  @override
  String get host => 'Host';

  @override
  String get port => 'Puerto';

  @override
  String get username => 'Usuario';

  @override
  String get selectKey => 'Seleccionar clave';

  @override
  String get saveConnection => 'Guardar conexión';

  @override
  String get deleteConnection => 'Eliminar conexión';

  @override
  String get unlock => 'Desbloqueo';

  @override
  String get pinCode => 'Código PIN';

  @override
  String get createPin => 'Crear su PIN';

  @override
  String get confirmPin => 'Confirmar su PIN';

  @override
  String get enterPin => 'Ingrese su PIN';

  @override
  String get pinMismatch => 'Los PIN no coinciden';

  @override
  String get wrongPin => 'PIN incorrecto';

  @override
  String get fingerprint => 'Huella dactilar';

  @override
  String get fingerprintUnavailable =>
      'No hay huella registrada en este dispositivo';

  @override
  String get autoLock => 'Bloqueo automático';

  @override
  String get autoLockTime => 'Tiempo de bloqueo';

  @override
  String get minutes => 'minutos';

  @override
  String get clearHistory => 'Borrar historial';

  @override
  String get clearHistoryConfirm => '¿Eliminar todo el historial de comandos?';

  @override
  String get historyCleared => 'Historial borrado';

  @override
  String get wolEnabled => 'Wake-on-LAN activado';

  @override
  String get wolConfigs => 'Configuraciones WOL';

  @override
  String get addWolConfig => 'Añadir configuración WOL';

  @override
  String get macAddress => 'Dirección MAC';

  @override
  String get broadcastAddress => 'Dirección de difusión';

  @override
  String get wolStart => 'WOL START';

  @override
  String get pressKeyForCtrl => 'Pulse una tecla...';

  @override
  String wolWakingUp(Object name) {
    return 'Despertando $name...';
  }

  @override
  String wolAttempt(Object attempt, Object maxAttempts) {
    return 'Intento $attempt/$maxAttempts';
  }

  @override
  String get wolConnected => '¡Conectado!';

  @override
  String wolPcAwake(Object name) {
    return '$name encendido';
  }

  @override
  String get wolSshEstablished => 'Conexión SSH establecida';

  @override
  String get back => 'Volver';

  @override
  String get addPc => 'Añadir un PC';

  @override
  String get pcName => 'Nombre del PC';

  @override
  String get pcNameRequired => 'El nombre es obligatorio';

  @override
  String get macAddressRequired => 'La dirección MAC es obligatoria';

  @override
  String get macAddressInvalid => 'Formato inválido (ej. AA:BB:CC:DD:EE:FF)';

  @override
  String get howToFindMac => '¿Cómo encontrar la dirección MAC?';

  @override
  String get linkedSshConnection => 'Conexión SSH asociada *';

  @override
  String get selectConnection => 'Seleccionar una conexión';

  @override
  String get noSavedConnections => 'Sin conexiones guardadas';

  @override
  String get pleaseSelectSshConnection =>
      'Por favor seleccione una conexión SSH';

  @override
  String configAdded(Object name) {
    return 'Configuración \"$name\" añadida';
  }

  @override
  String get findMacAddress => 'Encontrar dirección MAC';

  @override
  String get macAddressFormat =>
      'La dirección MAC se parece a: AA:BB:CC:DD:EE:FF';

  @override
  String get understood => 'Entendido';

  @override
  String get quickConnections => 'CONEXIONES RÁPIDAS';

  @override
  String get autoConnectOnStart => 'Conectar automáticamente al iniciar';

  @override
  String get autoConnectOnStartDesc =>
      'Conectar automáticamente a la última conexión';

  @override
  String get autoReconnect => 'Reconexión automática';

  @override
  String get autoReconnectDesc => 'Reconectar si se pierde la conexión';

  @override
  String get disconnectNotification => 'Notificación de desconexión';

  @override
  String get disconnectNotificationDesc =>
      'Mostrar notificación al desconectar';

  @override
  String get deleteConnectionConfirm => '¿Eliminar conexión?';

  @override
  String deleteConnectionConfirmMessage(Object name) {
    return '¿Desea eliminar \"$name\" de sus conexiones guardadas?';
  }

  @override
  String get noWolConfig => 'Sin configuración. Añada una para activar WOL.';

  @override
  String get configRequired => 'Configuración requerida';

  @override
  String get wolDescription =>
      'Wake-on-LAN te permite encender tu PC desde la app.';

  @override
  String get turnOnCableRequired => 'Encender: cable Ethernet requerido';

  @override
  String get turnOffWifiOrCable => 'Apagar: WiFi o cable';

  @override
  String get fullGuide => 'Guía completa';

  @override
  String get linkCopied => 'Enlace copiado';

  @override
  String terminalTab(Object number) {
    return 'Terminal $number';
  }

  @override
  String get wakeUpPc => 'Encender un PC';

  @override
  String get connectionLostSnack => 'Conexión perdida';

  @override
  String get unableToCreateTab => 'No se pudo crear una nueva pestaña';

  @override
  String get privateKeyNotFound => 'Clave privada no encontrada';

  @override
  String get uploadingImage => 'Subiendo imagen...';

  @override
  String get uploadFailed => 'Error al subir la imagen';

  @override
  String get ok => 'OK';

  @override
  String errorMessage(String error) {
    return 'Error: $error';
  }

  @override
  String get invalidKeyFormat => 'Formato de clave inválido';

  @override
  String keyImported(String name) {
    return 'Clave \"$name\" importada';
  }

  @override
  String get deleteKeyConfirmTitle => '¿Eliminar clave?';

  @override
  String get actionIrreversible => 'Esta acción es irreversible.';

  @override
  String deleteKeysConfirm(int count) {
    return '¿Eliminar $count clave(s)?';
  }

  @override
  String deleteConnectionsConfirm(int count) {
    return '¿Eliminar $count conexión(es)?';
  }

  @override
  String deleteWolConfigsConfirm(int count) {
    return '¿Eliminar $count configuración(es)?';
  }

  @override
  String sshKeyTypeLabel(String type) {
    return 'Tipo: $type';
  }

  @override
  String sshKeyHostLabel(String host) {
    return 'Host: $host';
  }

  @override
  String sshKeyLastUsedLabel(String date) {
    return 'Último uso: $date';
  }

  @override
  String get shutdownPcTitle => 'Apagar PC';

  @override
  String shutdownPcMessage(String name) {
    return '¿Realmente desea apagar $name?\n\nLa conexión SSH se cerrará.';
  }

  @override
  String get shutdownAction => 'Apagar';

  @override
  String get searchPlaceholder => 'Buscar...';

  @override
  String get autoDetect => 'Automático';
}
