import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/app_header.dart';
import '../widgets/ssh_keys_section.dart';
import '../widgets/quick_connections_section.dart';
import '../widgets/appearance_section.dart';
import '../widgets/security_section.dart';
import '../widgets/wol_section.dart';
import '../widgets/add_wol_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onTerminalTap;

  const SettingsScreen({super.key, this.onTerminalTap});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(vibeTermThemeProvider);

    return Scaffold(
      backgroundColor: theme.bg,
      body: Column(
        children: [
          AppHeader(
            isTerminalActive: false,
            onTerminalTap: widget.onTerminalTap,
          ),
          // Barre d'onglets
          _SettingsTabBar(
            tabController: _tabController,
            theme: theme,
          ),
          // Contenu des onglets
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                // Onglet 1: Connexion
                _ConnectionTab(),
                // Onglet 2: Thème
                _ThemeTab(),
                // Onglet 3: Sécurité
                _SecurityTab(),
                // Onglet 4: WOL
                _WolTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Barre d'onglets des settings
class _SettingsTabBar extends StatelessWidget {
  final TabController tabController;
  final VibeTermThemeData theme;

  const _SettingsTabBar({
    required this.tabController,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bg,
        border: Border(
          bottom: BorderSide(color: theme.border),
        ),
      ),
      child: TabBar(
        controller: tabController,
        labelColor: theme.accent,
        unselectedLabelColor: theme.textMuted,
        indicatorColor: theme.accent,
        indicatorWeight: 2,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontFamily: 'JetBrainsMono',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          fontFamily: 'JetBrainsMono',
        ),
        tabs: const [
          Tab(text: 'Connexion'),
          Tab(text: 'Thème'),
          Tab(text: 'Sécurité'),
          Tab(text: 'WOL'),
        ],
      ),
    );
  }
}

/// Onglet Connexion : Clés SSH + Connexions rapides + Connexions sauvegardées
class _ConnectionTab extends StatelessWidget {
  const _ConnectionTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(VibeTermSpacing.md),
      children: const [
        SSHKeysSection(),
        SizedBox(height: VibeTermSpacing.lg),
        QuickConnectionsSection(),
        SizedBox(height: VibeTermSpacing.xl),
      ],
    );
  }
}

/// Onglet Thème : Sélection des 12 thèmes
class _ThemeTab extends StatelessWidget {
  const _ThemeTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(VibeTermSpacing.md),
      children: const [
        AppearanceSection(),
        SizedBox(height: VibeTermSpacing.xl),
      ],
    );
  }
}

/// Onglet Sécurité : Biométrie et verrouillage
class _SecurityTab extends StatelessWidget {
  const _SecurityTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(VibeTermSpacing.md),
      children: const [
        SecuritySection(),
        SizedBox(height: VibeTermSpacing.xl),
      ],
    );
  }
}

/// Onglet WOL : Wake-on-LAN pour allumer le PC à distance
class _WolTab extends StatelessWidget {
  const _WolTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(VibeTermSpacing.md),
      children: [
        WolSection(
          onAddConfig: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const AddWolSheet(),
            );
          },
        ),
        const SizedBox(height: VibeTermSpacing.xl),
      ],
    );
  }
}
