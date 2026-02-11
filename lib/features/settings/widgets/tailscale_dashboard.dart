import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../../../models/tailscale_device.dart';
import '../providers/tailscale_provider.dart';
import 'section_header.dart';

/// Dashboard Tailscale affiche dans l'onglet dedie.
/// Montre le statut, l'IP, et la liste des appareils du reseau.
class TailscaleDashboard extends ConsumerWidget {
  const TailscaleDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = ref.watch(vibeTermThemeProvider);
    final tailscaleState = ref.watch(tailscaleProvider);

    if (!tailscaleState.isConnected) {
      return _NotConnectedMessage(theme: theme, l10n: l10n);
    }

    return ListView(
      padding: const EdgeInsets.all(VibeTermSpacing.md),
      children: [
        // Card de statut
        _StatusCard(
          theme: theme,
          l10n: l10n,
          ip: tailscaleState.myIP,
          deviceName: tailscaleState.deviceName,
          isConnected: tailscaleState.isConnected,
          onLogout: () => ref.read(tailscaleProvider.notifier).logout(),
        ),
        const SizedBox(height: VibeTermSpacing.lg),

        // Liste des machines
        SectionHeader(
          title: l10n.tailscaleDevicesCount(
            tailscaleState.devices.length,
          ).toUpperCase(),
        ),
        const SizedBox(height: VibeTermSpacing.sm),
        ...tailscaleState.devices.map(
          (device) => Padding(
            padding: const EdgeInsets.only(bottom: VibeTermSpacing.sm),
            child: _DeviceCard(theme: theme, l10n: l10n, device: device),
          ),
        ),
        const SizedBox(height: VibeTermSpacing.xl),
      ],
    );
  }
}

/// Message affiche quand Tailscale n'est pas connecte.
class _NotConnectedMessage extends StatelessWidget {
  final VibeTermThemeData theme;
  final AppLocalizations l10n;

  const _NotConnectedMessage({required this.theme, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(VibeTermSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.public_off,
              color: theme.textMuted,
              size: 48,
            ),
            const SizedBox(height: VibeTermSpacing.md),
            Text(
              l10n.tailscaleAuthPrompt,
              style: VibeTermTypography.itemDescription.copyWith(
                color: theme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de statut Tailscale en haut du dashboard.
class _StatusCard extends StatelessWidget {
  final VibeTermThemeData theme;
  final AppLocalizations l10n;
  final String? ip;
  final String? deviceName;
  final bool isConnected;
  final VoidCallback onLogout;

  const _StatusCard({
    required this.theme,
    required this.l10n,
    this.ip,
    this.deviceName,
    required this.isConnected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VibeTermSpacing.md),
      decoration: BoxDecoration(
        color: theme.bgBlock,
        borderRadius: BorderRadius.circular(VibeTermRadius.md),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statut + bouton deconnecter
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isConnected ? theme.success : theme.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: VibeTermSpacing.sm),
              Expanded(
                child: Text(
                  isConnected
                      ? l10n.tailscaleConnected
                      : l10n.tailscaleDisconnected,
                  style: VibeTermTypography.itemTitle.copyWith(
                    color: theme.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: onLogout,
                icon: Icon(Icons.logout, color: theme.textMuted, size: 20),
                tooltip: l10n.tailscaleDisconnect,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: VibeTermSpacing.sm),

          // Mon IP
          if (ip != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.tailscaleMyIP} : $ip',
                    style: VibeTermTypography.caption.copyWith(
                      color: theme.text,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: ip!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.tailscaleIPCopied),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(Icons.copy, color: theme.textMuted, size: 16),
                  tooltip: l10n.tailscaleCopyIP,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

          // Nom appareil
          if (deviceName != null) ...[
            const SizedBox(height: VibeTermSpacing.xs),
            Text(
              deviceName!,
              style: VibeTermTypography.itemDescription.copyWith(
                color: theme.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Card pour un appareil Tailscale.
class _DeviceCard extends StatelessWidget {
  final VibeTermThemeData theme;
  final AppLocalizations l10n;
  final TailscaleDevice device;

  const _DeviceCard({
    required this.theme,
    required this.l10n,
    required this.device,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: device.isOnline ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(VibeTermSpacing.md),
        decoration: BoxDecoration(
          color: theme.bgBlock,
          borderRadius: BorderRadius.circular(VibeTermRadius.md),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nom + pastille statut + IP
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: device.isOnline ? theme.success : theme.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: VibeTermSpacing.sm),
                Expanded(
                  child: Text(
                    device.name,
                    style: VibeTermTypography.itemTitle.copyWith(
                      color: theme.text,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  device.ip,
                  style: VibeTermTypography.caption.copyWith(
                    color: theme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: VibeTermSpacing.sm),

            // Boutons d'action
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Copier IP
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: device.ip));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.tailscaleIPCopied),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(Icons.copy, color: theme.textMuted, size: 16),
                  tooltip: l10n.tailscaleCopyIP,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: VibeTermSpacing.md),
                // Connexion SSH
                IconButton(
                  onPressed: device.isOnline
                      ? () {
                          // TODO: Navigate to new SSH connection form with device.ip pre-filled
                        }
                      : null,
                  icon: Icon(
                    Icons.terminal,
                    color: device.isOnline ? theme.accent : theme.textMuted,
                    size: 18,
                  ),
                  tooltip: l10n.tailscaleNewSSH,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
