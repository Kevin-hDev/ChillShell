// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'ChillShell';

  @override
  String get settings => '设置';

  @override
  String get connection => '连接';

  @override
  String get access => '访问';

  @override
  String get general => '通用';

  @override
  String get security => '安全';

  @override
  String get wol => 'WOL';

  @override
  String get remoteAccess => '远程访问';

  @override
  String get tailscaleDescription => '从世界任何地方连接到您的电脑';

  @override
  String get playStore => 'Play Store';

  @override
  String get appStore => 'App Store';

  @override
  String get website => '网站';

  @override
  String get noSshKeys => '没有SSH密钥。创建一个以连接。';

  @override
  String get theme => '主题';

  @override
  String get language => '语言';

  @override
  String get fontSize => '字体大小';

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
  String get disconnect => '断开';

  @override
  String get disconnectConfirmTitle => '断开连接';

  @override
  String get disconnectConfirmMessage => '是否关闭所有SSH连接？';

  @override
  String get connect => '连接';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get add => '添加';

  @override
  String get retry => '重试';

  @override
  String get noConnection => '无连接';

  @override
  String get connectToServer => '连接到SSH服务器';

  @override
  String get newConnection => '新建连接';

  @override
  String get connectionInProgress => '正在连接...';

  @override
  String get reconnecting => '正在重连...';

  @override
  String get connectionError => '连接错误';

  @override
  String get reconnect => '重新连接';

  @override
  String get terminal => '终端';

  @override
  String get runCommands => '运行命令';

  @override
  String get localShell => '本地Shell';

  @override
  String get localShellNotAvailable => 'iOS不可用';

  @override
  String get localShellIOSMessage => 'iOS不允许访问本地Shell。SSH连接正常工作。';

  @override
  String get copy => '复制';

  @override
  String get paste => '粘贴';

  @override
  String get sshKeys => 'SSH密钥';

  @override
  String get createSshKey => '创建SSH密钥';

  @override
  String get importKey => '导入密钥';

  @override
  String get importKeySubtitle => '.pem文件或私钥';

  @override
  String get selectFile => '选择文件';

  @override
  String get orPasteKey => '或粘贴密钥：';

  @override
  String get keyName => '密钥名称';

  @override
  String get publicKey => '公钥';

  @override
  String get privateKey => '私钥';

  @override
  String get keyCopied => '密钥已复制到剪贴板';

  @override
  String get deleteKey => '删除密钥';

  @override
  String get savedConnections => '已保存的连接';

  @override
  String get autoConnection => '自动连接';

  @override
  String get host => '主机';

  @override
  String get port => '端口';

  @override
  String get username => '用户名';

  @override
  String get selectKey => '选择密钥';

  @override
  String get saveConnection => '保存连接';

  @override
  String get deleteConnection => '删除连接';

  @override
  String get unlock => '解锁';

  @override
  String get pinCode => 'PIN码';

  @override
  String get createPin => '创建PIN码';

  @override
  String get confirmPin => '确认PIN码';

  @override
  String get enterPin => '输入PIN码';

  @override
  String get pinMismatch => 'PIN码不匹配';

  @override
  String get wrongPin => 'PIN码错误';

  @override
  String get fingerprint => '指纹';

  @override
  String get fingerprintUnavailable => '此设备未注册指纹';

  @override
  String get autoLock => '自动锁定';

  @override
  String get autoLockTime => '锁定时间';

  @override
  String get minutes => '分钟';

  @override
  String get clearHistory => '清除历史';

  @override
  String get clearHistoryConfirm => '删除所有命令历史？';

  @override
  String get historyCleared => '历史已清除';

  @override
  String get wolEnabled => '启用网络唤醒';

  @override
  String get wolConfigs => 'WOL配置';

  @override
  String get addWolConfig => '添加WOL配置';

  @override
  String get macAddress => 'MAC地址';

  @override
  String get broadcastAddress => '广播地址';

  @override
  String get wolStart => 'WOL启动';

  @override
  String get pressKeyForCtrl => '按下一个键...';

  @override
  String wolWakingUp(Object name) {
    return '正在唤醒 $name...';
  }

  @override
  String wolAttempt(Object attempt, Object maxAttempts) {
    return '尝试 $attempt/$maxAttempts';
  }

  @override
  String get wolConnected => '已连接！';

  @override
  String wolPcAwake(Object name) {
    return '$name 已唤醒';
  }

  @override
  String get wolSshEstablished => 'SSH连接已建立';

  @override
  String get back => '返回';

  @override
  String get addPc => '添加电脑';

  @override
  String get pcName => '电脑名称';

  @override
  String get pcNameRequired => '名称为必填项';

  @override
  String get macAddressRequired => 'MAC地址为必填项';

  @override
  String get macAddressInvalid => '格式无效（例如 AA:BB:CC:DD:EE:FF）';

  @override
  String get howToFindMac => '如何查找MAC地址？';

  @override
  String get linkedSshConnection => '关联的SSH连接 *';

  @override
  String get selectConnection => '选择连接';

  @override
  String get noSavedConnections => '没有已保存的连接';

  @override
  String get pleaseSelectSshConnection => '请选择一个SSH连接';

  @override
  String configAdded(Object name) {
    return '配置 \"$name\" 已添加';
  }

  @override
  String get findMacAddress => '查找MAC地址';

  @override
  String get macAddressFormat => 'MAC地址格式：AA:BB:CC:DD:EE:FF';

  @override
  String get understood => '明白了';

  @override
  String get quickConnections => '快速连接';

  @override
  String get autoConnectOnStart => '启动时自动连接';

  @override
  String get autoConnectOnStartDesc => '自动连接到上次的连接';

  @override
  String get autoReconnect => '自动重连';

  @override
  String get autoReconnectDesc => '连接丢失时自动重连';

  @override
  String get disconnectNotification => '断开通知';

  @override
  String get disconnectNotificationDesc => '断开时显示通知';

  @override
  String get deleteConnectionConfirm => '删除连接？';

  @override
  String deleteConnectionConfirmMessage(Object name) {
    return '是否从已保存的连接中删除 \"$name\"？';
  }

  @override
  String get noWolConfig => '暂无配置。添加一个以启用WOL。';

  @override
  String get configRequired => '需要配置';

  @override
  String get wolDescription => 'Wake-on-LAN允许您从应用程序启动电脑。';

  @override
  String get turnOnCableRequired => '开机：需要以太网电缆';

  @override
  String get turnOffWifiOrCable => '关机：WiFi或电缆';

  @override
  String get fullGuide => '完整指南';

  @override
  String get linkCopied => '链接已复制';

  @override
  String terminalTab(Object number) {
    return '终端 $number';
  }

  @override
  String get wakeUpPc => '唤醒电脑';

  @override
  String get connectionLostSnack => '连接丢失';

  @override
  String get unableToCreateTab => '无法创建新标签页';

  @override
  String get privateKeyNotFound => '找不到私钥';

  @override
  String get uploadingImage => '正在上传图片...';

  @override
  String get uploadFailed => '图片上传失败';

  @override
  String get ok => '确定';

  @override
  String errorMessage(String error) {
    return '错误：$error';
  }

  @override
  String get invalidKeyFormat => '密钥格式无效';

  @override
  String get keyFileTooLarge => '文件过大（最大 16 KB）。SSH 密钥应该是小文件。';

  @override
  String keyImported(String name) {
    return '密钥 \"$name\" 已导入';
  }

  @override
  String get deleteKeyConfirmTitle => '删除密钥？';

  @override
  String get actionIrreversible => '此操作不可撤销。';

  @override
  String deleteKeysConfirm(int count) {
    return '删除 $count 个密钥？';
  }

  @override
  String deleteConnectionsConfirm(int count) {
    return '删除 $count 个连接？';
  }

  @override
  String deleteWolConfigsConfirm(int count) {
    return '删除 $count 个配置？';
  }

  @override
  String sshKeyTypeLabel(String type) {
    return '类型：$type';
  }

  @override
  String sshKeyHostLabel(String host) {
    return '主机：$host';
  }

  @override
  String sshKeyLastUsedLabel(String date) {
    return '最近使用：$date';
  }

  @override
  String get shutdownPcTitle => '关闭电脑';

  @override
  String shutdownPcMessage(String name) {
    return '确定要关闭 $name 吗？\n\nSSH连接将断开。';
  }

  @override
  String get shutdownAction => '关闭';

  @override
  String get searchPlaceholder => '搜索...';

  @override
  String get autoDetect => '自动';

  @override
  String get wolBiosTitle => '1. BIOS';

  @override
  String get wolBiosEnablePcie => '启用 \"Power On By PCI-E\"';

  @override
  String get wolBiosDisableErp => '禁用 \"ErP Ready\"';

  @override
  String get wolFastStartupTitle => '2. 快速启动';

  @override
  String get wolFastStep1 => '电源选项 → 系统设置';

  @override
  String get wolFastStep2 => '更改不可用的设置';

  @override
  String get wolFastStep3 => '取消勾选\"启用快速启动\"';

  @override
  String get wolDeviceManagerTitle => '3. 设备管理器';

  @override
  String get wolDevStep1 => '网络适配器 → 电源管理';

  @override
  String get wolDevStep2 => '勾选\"仅限魔术数据包\"';

  @override
  String get wolDevStep3 => '网络适配器 → 高级';

  @override
  String get wolDevStep4 => '启用 \"Wake on Magic Packet\"';

  @override
  String get wolMacConfigTitle => '配置';

  @override
  String get wolMacStep1 => '1. Apple菜单 → 系统偏好设置';

  @override
  String get wolMacStep2 => '2. 节能';

  @override
  String get wolMacStep3 => '3. 勾选\"唤醒以进行网络访问\"';

  @override
  String get sshKeySecurityTitle => '保护您的密钥';

  @override
  String get sshKeySecurityDesc =>
      '您的SSH密钥就像密码，可以授予您服务器的访问权限。私钥绝对不能分享——不能通过邮件、即时通讯或云存储。只将公钥分享给您要连接的服务器。ChillShell仅在您的设备上安全存储密钥。如果您怀疑密钥已被泄露，请立即删除并创建新的密钥。';

  @override
  String get sshHostKeyTitle => '新服务器';

  @override
  String sshHostKeyMessage(String host) {
    return '您是第一次连接到 $host。\n连接前请验证服务器指纹：';
  }

  @override
  String sshHostKeyType(String type) {
    return '类型：$type';
  }

  @override
  String get sshHostKeyFingerprint => '指纹：';

  @override
  String get sshHostKeyAccept => '信任并连接';

  @override
  String get sshHostKeyReject => '拒绝';

  @override
  String get sshHostKeyMismatchTitle => '警告 — 密钥已更改！';

  @override
  String sshHostKeyMismatchMessage(String host) {
    return '服务器 $host 的密钥已更改！\n\n这可能表示中间人攻击。如果您没有更改服务器配置，请拒绝此连接。';
  }

  @override
  String get rootedDeviceWarning => '警告：此设备似乎已获取Root权限。SSH密钥安全性可能受到影响。';

  @override
  String tooManyAttempts(int seconds) {
    return '尝试次数过多。请在 $seconds 秒后重试';
  }

  @override
  String tryAgainIn(int seconds) {
    return '请在 $seconds 秒后重试';
  }

  @override
  String get sshConnectionFailed => '无法连接。请检查服务器地址。';

  @override
  String get sshAuthFailed => '认证失败。请检查您的SSH密钥。';

  @override
  String get sshKeyNotConfigured => '未为此主机配置SSH密钥。';

  @override
  String get sshTimeout => '连接超时。';

  @override
  String get sshHostUnreachable => '服务器不可达。请检查Tailscale。';

  @override
  String get connectionLost => '连接已断开';

  @override
  String get biometricReason => '解锁ChillShell以访问您的SSH会话';

  @override
  String get biometricFingerprint => '指纹';

  @override
  String get biometricIris => '虹膜';

  @override
  String get biometricGeneric => '生物识别';

  @override
  String get localShellError => '本地Shell错误';

  @override
  String reconnectingAttempt(String current, String max) {
    return '重新连接中...（第$current/$max次）';
  }

  @override
  String get unexpectedError => '意外错误';

  @override
  String get allowScreenshots => '截屏';

  @override
  String get allowScreenshotsWarning =>
      '启用后，允许截屏和录屏。请注意不要分享敏感信息（SSH密钥、密码、服务器地址）。';

  @override
  String get rename => '重命名';

  @override
  String get renameDialogHint => '新名称';

  @override
  String get nameCannotBeEmpty => '名称不能为空';
}
