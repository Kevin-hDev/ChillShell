import 'dart:async';
import 'package:flutter/material.dart';
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
import 'services/foreground_ssh_service.dart';

void main() {
  ForegroundSSHService.init();
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
  bool _isLocked = true;
  bool _checkingBiometric = true;
  bool _biometricUnavailable = false;
  Timer? _autoLockTimer;
  DateTime? _backgroundTime;

  // Durée avant verrouillage automatique (10 minutes)
  static const _autoLockDuration = Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBiometricStatus();
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

    if (state == AppLifecycleState.paused) {
      // App en arrière-plan - enregistrer le moment
      _backgroundTime = DateTime.now();

      // Démarrer le timer si auto-lock est activé
      if (settings.appSettings.autoLockEnabled && settings.appSettings.biometricEnabled) {
        _autoLockTimer = Timer(_autoLockDuration, () {
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
          settings.appSettings.biometricEnabled) {
        final elapsed = DateTime.now().difference(_backgroundTime!);
        if (elapsed >= _autoLockDuration) {
          setState(() => _isLocked = true);
        }
      }
      _backgroundTime = null;

      // Vérifier et reconnecter les sessions SSH si nécessaire
      ref.read(sshProvider.notifier).checkAndReconnectIfNeeded();
    }
  }

  Future<void> _checkBiometricStatus() async {
    final settings = ref.read(settingsProvider);

    if (settings.appSettings.biometricEnabled) {
      final isAvailable = await BiometricService.isAvailable();
      if (isAvailable) {
        setState(() {
          _isLocked = true;
          _checkingBiometric = false;
          _biometricUnavailable = false;
        });
      } else {
        // Biométrie non disponible - garder verrouillé avec message
        setState(() {
          _isLocked = true;
          _checkingBiometric = false;
          _biometricUnavailable = true;
        });
      }
    } else {
      // Biométrie désactivée, déverrouiller directement
      setState(() {
        _isLocked = false;
        _checkingBiometric = false;
        _biometricUnavailable = false;
      });
    }
  }

  void _unlock() {
    setState(() {
      _isLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingBiometric) {
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
        biometricUnavailable: _biometricUnavailable,
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
