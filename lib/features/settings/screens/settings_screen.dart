import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/widgets/app_header.dart';
import '../widgets/quick_connections_section.dart';
import '../widgets/access_section.dart';
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
    _tabController = TabController(length: 5, vsync: this);
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
                // Onglet 2: Accès (Tailscale + Clés SSH)
                _AccessTab(),
                // Onglet 3: Général (Thème + Langue + Taille police)
                _GeneralTab(),
                // Onglet 4: Sécurité
                _SecurityTab(),
                // Onglet 5: WOL
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
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: theme.bg,
        border: Border(
          bottom: BorderSide(color: theme.border),
        ),
      ),
      child: TabBar(
        controller: tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: theme.accent,
        unselectedLabelColor: theme.textMuted,
        indicatorColor: theme.accent,
        indicatorWeight: 2,
        labelPadding: const EdgeInsets.symmetric(horizontal: VibeTermSpacing.md),
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
        tabs: [
          Tab(text: l10n.connection),
          Tab(text: l10n.access),
          Tab(text: l10n.general),
          Tab(text: l10n.security),
          Tab(text: l10n.wol),
        ],
      ),
    );
  }
}

/// Onglet Connexion : Connexions rapides + Connexions sauvegardées
class _ConnectionTab extends StatelessWidget {
  const _ConnectionTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(VibeTermSpacing.md),
      children: const [
        QuickConnectionsSection(),
        SizedBox(height: VibeTermSpacing.xl),
      ],
    );
  }
}

/// Onglet Accès : Tailscale + Clés SSH
class _AccessTab extends StatelessWidget {
  const _AccessTab();

  @override
  Widget build(BuildContext context) {
    return const AccessSection();
  }
}

/// Onglet Général : Thème + Langue + Taille de police
class _GeneralTab extends StatelessWidget {
  const _GeneralTab();

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
