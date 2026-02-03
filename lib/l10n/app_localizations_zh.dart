// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'VibeTerm';

  @override
  String get settings => '设置';

  @override
  String get connection => '连接';

  @override
  String get general => '通用';

  @override
  String get security => '安全';

  @override
  String get wol => 'WOL';

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
  String get disconnectAll => '全部断开';

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
  String get edit => '编辑';

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
  String get connectionLost => '连接丢失';

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
  String get generateKey => '生成密钥';

  @override
  String get keyName => '密钥名称';

  @override
  String get keyType => '密钥类型';

  @override
  String get publicKey => '公钥';

  @override
  String get privateKey => '私钥';

  @override
  String get copyPublicKey => '复制公钥';

  @override
  String get keyCopied => '密钥已复制到剪贴板';

  @override
  String get deleteKey => '删除密钥';

  @override
  String get deleteKeyConfirm => '删除此SSH密钥？';

  @override
  String get savedConnections => '已保存的连接';

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
  String get biometricUnlock => '生物识别解锁';

  @override
  String get faceId => '面容ID';

  @override
  String get fingerprint => '指纹';

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
  String get wolName => '名称';

  @override
  String get macAddress => 'MAC地址';

  @override
  String get broadcastAddress => '广播地址';

  @override
  String get udpPort => 'UDP端口';

  @override
  String get linkedConnection => '关联的SSH连接';

  @override
  String get wolStart => 'WOL启动';

  @override
  String get wakingUp => '正在唤醒...';

  @override
  String get waitingForBoot => '等待启动...';

  @override
  String get tryingToConnect => '尝试连接...';

  @override
  String get pcAwake => '电脑已唤醒！';

  @override
  String get wolFailed => '网络唤醒失败';

  @override
  String get shutdown => '关机';

  @override
  String get shutdownConfirm => '关闭此电脑？';

  @override
  String get pressKeyForCtrl => '按下一个键...';

  @override
  String get swipeDownToReduce => '向下滑动缩小...';

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
  String get advancedOptions => '高级选项（远程WOL）';

  @override
  String get broadcastOptional => '广播地址（可选）';

  @override
  String get defaultBroadcast => '默认：255.255.255.255';

  @override
  String get udpPortOptional => 'UDP端口（可选）';

  @override
  String get defaultPort => '默认：9';

  @override
  String get portRange => '端口范围1-65535';

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
  String get privateKeyNotFound => '未找到私钥';
}
