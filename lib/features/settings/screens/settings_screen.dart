import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../shared/widgets/app_header.dart';
import '../widgets/ssh_keys_section.dart';
import '../widgets/quick_connections_section.dart';
import '../widgets/appearance_section.dart';
import '../widgets/security_section.dart';

class SettingsScreen extends ConsumerWidget {
  final VoidCallback? onTerminalTap;

  const SettingsScreen({super.key, this.onTerminalTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(vibeTermThemeProvider);

    return Scaffold(
      backgroundColor: theme.bg,
      body: Column(
        children: [
          AppHeader(
            isTerminalActive: false,
            onTerminalTap: onTerminalTap,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(VibeTermSpacing.md),
              children: const [
                SSHKeysSection(),
                SizedBox(height: VibeTermSpacing.lg),
                QuickConnectionsSection(),
                SizedBox(height: VibeTermSpacing.lg),
                AppearanceSection(),
                SizedBox(height: VibeTermSpacing.lg),
                SecuritySection(),
                SizedBox(height: VibeTermSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
