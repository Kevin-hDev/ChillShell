import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/l10n/l10n.dart';
import '../providers/purchase_provider.dart';

class PaywallScreen extends ConsumerWidget {
  const PaywallScreen({super.key});

  String _translateError(AppLocalizations l10n, String code) {
    switch (code) {
      case 'store_unavailable':
        return l10n.storeUnavailable;
      case 'product_not_found':
        return l10n.productNotFound;
      default:
        return l10n.purchaseError;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = ref.watch(vibeTermThemeProvider);
    final purchaseState = ref.watch(purchaseProvider);

    final features = [
      (Icons.terminal, l10n.premiumFeature1),
      (Icons.tab, l10n.premiumFeature2),
      (Icons.power_settings_new, l10n.premiumFeature3),
      (Icons.palette, l10n.premiumFeature4),
      (Icons.fingerprint, l10n.premiumFeature5),
    ];

    return Scaffold(
      backgroundColor: theme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(VibeTermSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/ICONE_CHILL.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: VibeTermSpacing.lg),

                // Titre
                Text(
                  l10n.premiumTitle,
                  style: VibeTermTypography.settingsTitle.copyWith(
                    fontSize: 28,
                    color: theme.accent,
                  ),
                ),
                const SizedBox(height: VibeTermSpacing.sm),

                // Message
                Text(
                  l10n.trialExpired,
                  style: VibeTermTypography.itemTitle.copyWith(
                    color: theme.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: VibeTermSpacing.xs),
                Text(
                  l10n.trialExpiredDesc,
                  style: VibeTermTypography.caption.copyWith(
                    color: theme.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: VibeTermSpacing.xl),

                // Features
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(f.$1, color: theme.textMuted, size: 20),
                      const SizedBox(width: VibeTermSpacing.md),
                      Expanded(
                        child: Text(
                          f.$2,
                          style: VibeTermTypography.itemTitle.copyWith(
                            color: theme.text,
                          ),
                        ),
                      ),
                      Icon(Icons.check_circle, color: theme.success, size: 20),
                    ],
                  ),
                )),
                const SizedBox(height: VibeTermSpacing.lg),

                // One-time purchase mention
                Text(
                  l10n.oneTimePurchase,
                  style: VibeTermTypography.caption.copyWith(
                    color: theme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: VibeTermSpacing.lg),

                // Error
                if (purchaseState.error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(VibeTermSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.danger.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(VibeTermRadius.md),
                      border: Border.all(color: theme.danger.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _translateError(l10n, purchaseState.error!),
                      style: VibeTermTypography.caption.copyWith(
                        color: theme.danger,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: VibeTermSpacing.md),
                ],

                // Buy button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: purchaseState.isLoading
                        ? null
                        : () => ref.read(purchaseProvider.notifier).buyPremium(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accent,
                      foregroundColor: theme.bg,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(VibeTermRadius.md),
                      ),
                    ),
                    child: purchaseState.isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: theme.bg,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            l10n.buyPremium,
                            style: VibeTermTypography.itemTitle.copyWith(
                              color: theme.bg,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: VibeTermSpacing.md),

                // Restore purchase
                TextButton(
                  onPressed: purchaseState.isLoading
                      ? null
                      : () => ref.read(purchaseProvider.notifier).restorePurchases(),
                  child: Text(
                    l10n.restorePurchase,
                    style: VibeTermTypography.caption.copyWith(
                      color: theme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
