import 'dart:async';
import 'dart:io';
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
import 'models/audit_entry.dart';
import 'services/audit_log_service.dart';
import 'services/biometric_service.dart';
import 'services/device_security_service.dart';
import 'services/foreground_ssh_service.dart';
import 'services/screenshot_protection_service.dart';
import 'services/pin_service.dart';
import 'services/rasp_service.dart';
// FIX-011 — ReconnectAuthGuard : re-authentification obligatoire après arrière-plan
// TODO(FIX-011): Enregistrer ReconnectAuthGuard.instance comme WidgetsBindingObserver
//   dans _AppRootState.initState() et appeler recordAuthentication() après unlock.
//   Exemple :
//     WidgetsBinding.instance.addObserver(ReconnectAuthGuard.instance);
//   Puis dans _handleReconnectTab (ssh_isolate_worker.dart), vérifier :
//     if (ReconnectAuthGuard.instance.needsReAuthentication()) { ... }
// ignore: unused_import
import 'core/security/reconnect_auth_guard.dart';
// FIX-019 — CanaryTokenManager : pièges de détection d'intrusion
// ignore: unused_import
import 'core/security/canary_tokens.dart';
// FIX-021 — BehavioralAnalyzer : analyse comportementale des commandes
// ignore: unused_import
import 'core/security/behavioral_analyzer.dart';
// FIX-022 — AIAgentDetector / AIRateLimiter / SecurityTarpit : détection agents IA
// ignore: unused_import
import 'core/security/ai_detection.dart';
// FIX-024 — EmergencyKillSwitch / DuressPin : effacement d'urgence et PIN de contrainte
// ignore: unused_import
import 'core/security/kill_switch.dart';
// FIX-025 — DependencyMonitor : surveillance des dependances critiques (supply chain)
// ignore: unused_import
import 'core/security/dependency_monitor.dart';
// TODO FIX-025: Lancer DependencyMonitor.checkAll() au demarrage
// ou en CI pour verifier les dependances

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ForegroundSSHService.init();
  // Migrer l'ancien PIN (v1 en clair) vers le nouveau format hashé si nécessaire
  await PinService.migrateIfNeeded();

  // ==========================================================================
  // SÉCURITÉ — Modules en attente d'activation (préparés, non actifs)
  // ==========================================================================
  //
  // TODO FIX-019: Activer les canary tokens au premier demarrage
  // await CanaryTokenManager(deploymentDir: '/home/user/.ssh/').deployAll();
  // Verifier periodiquement: manager.checkAll(onAlert: auditLog.write);
  //
  // TODO FIX-021: Initialiser le BehavioralAnalyzer au demarrage
  // BehavioralAnalyzer() — instancier et passer au provider SSH
  // Alimenter avec: analyzer.recordEvent(BehaviorEvent(command: cmd, ...));
  // Analyser avant execution: analyzer.analyzeEvent(event) → action block/warn
  //
  // TODO FIX-022: Activer la detection d'agents IA autonomes
  // AIAgentDetector() — instancier et brancher sur le flux de commandes
  // AIRateLimiter() — limiter les requetes excessives par session
  // SecurityTarpit() — appliquer le delai exponentiel aux sessions suspectes
  //
  // TODO FIX-024: Configurer le kill switch et le duress PIN
  // EmergencyKillSwitch(authenticateBiometric: ..., wipeSSHKeys: ..., ...)
  // DuressPin.validatePinPair(normalPin, duressPin) a la configuration du PIN
  // DuressPin.verifyPin(entered, realPin, duressPin) dans lock_screen.dart
  // ==========================================================================

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
  bool _raspBlocked = false;
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
      AuditLogService.log(
        AuditEventType.rootDetected,
        success: true,
        details: {'platform': Platform.isAndroid ? 'android' : 'ios'},
      );
    }

    // Initialize freeRASP if enabled
    final settings = ref.read(settingsProvider);
    if (settings.appSettings.raspEnabled) {
      await RaspService.initialize(
        onThreatDetected: (threat) => _handleRaspThreat(threat),
      );
    }
  }

  void _handleRaspThreat(RaspThreatType threat) {
    final settings = ref.read(settingsProvider);
    if (settings.appSettings.raspBlockMode) {
      // Block mode: show blocking screen
      if (mounted) setState(() => _raspBlocked = true);
    }
    // Warn mode: the audit log is already written by RaspService,
    // and a snackbar can be shown if we have a context.
    // For now, warn mode just logs (visible in audit trail).
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
    final lockEnabled =
        settings.appSettings.pinLockEnabled ||
        settings.appSettings.fingerprintEnabled;
    final autoLockDuration = Duration(
      minutes: settings.appSettings.autoLockMinutes,
    );

    if (state == AppLifecycleState.paused) {
      // App en arrière-plan - enregistrer le moment
      _backgroundTime = DateTime.now();

      // Nettoyer le clipboard seulement si la fonctionnalité est activée
      if (settings.appSettings.clipboardAutoClear) {
        ScreenshotProtectionService.clearClipboard();
      }

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

  bool _isLockingEnabled(SettingsState settings) {
    return settings.appSettings.pinLockEnabled ||
        settings.appSettings.fingerprintEnabled;
  }

  void _setLockState({required bool isLocked, bool? pinEnabled, bool? fingerprintEnabled}) {
    if (mounted) {
      setState(() {
        _isLocked = isLocked;
        if (pinEnabled != null) _pinEnabled = pinEnabled;
        if (fingerprintEnabled != null) _fingerprintEnabled = fingerprintEnabled;
        _lockStatusReady = true;
      });
    }
  }

  Future<void> _initializeLockScreen(SettingsState settings) async {
    final pinEnabled = settings.appSettings.pinLockEnabled;
    final fingerprintAvailable = settings.appSettings.fingerprintEnabled
        ? await BiometricService.isAvailable()
        : false;
    _setLockState(isLocked: true, pinEnabled: pinEnabled, fingerprintEnabled: fingerprintAvailable);
  }

  /// Vérifie le verrouillage une fois les paramètres chargés
  Future<void> _checkLockStatus(SettingsState settings) async {
    if (_checkingLock) return;
    _checkingLock = true;

    // Appliquer la protection screenshot selon le setting utilisateur
    ScreenshotProtectionService.setEnabled(
      !settings.appSettings.allowScreenshots,
    );

    if (!_isLockingEnabled(settings)) {
      _setLockState(isLocked: false);
      return;
    }

    await _initializeLockScreen(settings);
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
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    // RASP blocked screen (before lock screen)
    if (_raspBlocked) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield, color: Color(0xFFB91C1C), size: 64),
                const SizedBox(height: 24),
                Text(
                  context.l10n.raspBlockedTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.raspBlockedMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
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
            leading: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
            ),
            actions: [
              TextButton(
                onPressed: () => setState(() => _rootWarningDismissed = true),
                child: Text(
                  context.l10n.understood,
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

  /// Historique de navigation pour le bouton retour (comme un navigateur web)
  final List<int> _history = [];

  void _navigateTo(int index) {
    if (index == _currentIndex) return;
    _history.add(_currentIndex);
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Autoriser la sortie uniquement s'il n'y a plus d'historique
      canPop: _history.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _history.isNotEmpty) {
          setState(() => _currentIndex = _history.removeLast());
        }
      },
      child: IndexedStack(
        index: _currentIndex,
        children: [
          TerminalScreen(onSettingsTap: () => _navigateTo(1)),
          SettingsScreen(onTerminalTap: () => _navigateTo(0)),
        ],
      ),
    );
  }
}
