import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/l10n/l10n.dart';
import 'features/terminal/screens/terminal_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/auth/screens/lock_screen.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/terminal/providers/providers.dart';
import 'services/biometric_service.dart';
import 'services/device_security_service.dart';
import 'services/foreground_ssh_service.dart';
import 'services/pin_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ForegroundSSHService.init();
  // Migrer l'ancien PIN (v1 en clair) vers le nouveau format hashé si nécessaire
  await PinService.migrateIfNeeded();
  runApp(const ProviderScope(child: VibeTermApp()));
}

class VibeTermApp extends ConsumerWidget {
  const VibeTermApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final languageCode = settings.appSettings.languageCode;

    return MaterialApp(
      title: 'VibeTerm',
      debugShowCheckedModeBanner: false,
      theme: VibeTermTheme.dark,
      locale: languageCode != null ? Locale(languageCode) : null,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('fr'),
        Locale('es'),
        Locale('de'),
        Locale('zh'),
      ],
      home: const AppRoot(),
    );
  }
}

class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _lockStatusReady = false;
  bool _checkingLock = false;
  bool _pinEnabled = false;
  bool _fingerprintEnabled = false;
  bool _deviceRooted = false;
  bool _rootWarningDismissed = false;
  Timer? _autoLockTimer;
  DateTime? _backgroundTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkDeviceSecurity();
  }

  Future<void> _checkDeviceSecurity() async {
    final status = await DeviceSecurityService.checkDeviceSecurity();
    if (mounted && status == DeviceSecurityStatus.rooted) {
      setState(() => _deviceRooted = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoLockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = ref.read(settingsProvider);
    final lockEnabled = settings.appSettings.pinLockEnabled ||
        settings.appSettings.fingerprintEnabled;
    final autoLockDuration = Duration(minutes: settings.appSettings.autoLockMinutes);

    if (state == AppLifecycleState.paused) {
      // App en arrière-plan - enregistrer le moment
      _backgroundTime = DateTime.now();

      // Nettoyer le clipboard pour éviter les fuites de données sensibles
      Clipboard.setData(const ClipboardData(text: ''));

      // Pause le timer de vérification SSH (économie batterie)
      ref.read(sshProvider.notifier).pauseConnectionMonitor();

      // Démarrer le timer si auto-lock est activé
      if (settings.appSettings.autoLockEnabled && lockEnabled) {
        _autoLockTimer = Timer(autoLockDuration, () {
          if (mounted) {
            setState(() => _isLocked = true);
          }
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      // App au premier plan - vérifier le temps écoulé
      _autoLockTimer?.cancel();

      if (_backgroundTime != null &&
          settings.appSettings.autoLockEnabled &&
          lockEnabled) {
        final elapsed = DateTime.now().difference(_backgroundTime!);
        if (elapsed >= autoLockDuration) {
          setState(() => _isLocked = true);
        }
      }
      _backgroundTime = null;

      // Reprendre le timer de vérification SSH
      ref.read(sshProvider.notifier).resumeConnectionMonitor();

      // Vérifier et reconnecter les sessions SSH si nécessaire
      ref.read(sshProvider.notifier).checkAndReconnectIfNeeded();
    }
  }

  /// Vérifie le verrouillage une fois les paramètres chargés
  Future<void> _checkLockStatus(SettingsState settings) async {
    if (_checkingLock) return;
    _checkingLock = true;

    final pinEnabled = settings.appSettings.pinLockEnabled;
    final fingerprintEnabled = settings.appSettings.fingerprintEnabled;

    if (pinEnabled || fingerprintEnabled) {
      // Vérifier si l'empreinte est dispo sur l'appareil
      bool fingerprintAvailable = false;
      if (fingerprintEnabled) {
        fingerprintAvailable = await BiometricService.isAvailable();
      }

      if (mounted) {
        setState(() {
          _isLocked = true;
          _pinEnabled = pinEnabled;
          _fingerprintEnabled = fingerprintAvailable;
          _lockStatusReady = true;
        });
      }
    } else {
      // Aucun verrouillage activé, déverrouiller directement
      if (mounted) {
        setState(() {
          _isLocked = false;
          _lockStatusReady = true;
        });
      }
    }
  }

  void _unlock() {
    setState(() {
      _isLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    // Attendre que les paramètres soient chargés depuis le stockage
    if (settings.isLoading || !_lockStatusReady) {
      // Paramètres chargés → lancer la vérification après le frame actuel
      if (!settings.isLoading && !_checkingLock) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkLockStatus(settings);
        });
      }
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF10B981),
          ),
        ),
      );
    }

    if (_isLocked) {
      return LockScreen(
        onUnlocked: _unlock,
        pinEnabled: _pinEnabled,
        fingerprintEnabled: _fingerprintEnabled,
      );
    }

    if (_deviceRooted && !_rootWarningDismissed) {
      return Column(
        children: [
          MaterialBanner(
            backgroundColor: const Color(0xFFB91C1C),
            content: Text(
              context.l10n.rootedDeviceWarning,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.white),
            actions: [
              TextButton(
                onPressed: () => setState(() => _rootWarningDismissed = true),
                child: Text(
                  MaterialLocalizations.of(context).okButtonLabel,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const Expanded(child: HomeScreen()),
        ],
      );
    }

    return const HomeScreen();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _currentIndex,
      children: [
        TerminalScreen(
          onSettingsTap: () => setState(() => _currentIndex = 1),
        ),
        SettingsScreen(
          onTerminalTap: () => setState(() => _currentIndex = 0),
        ),
      ],
    );
  }
}
