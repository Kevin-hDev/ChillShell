import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../models/models.dart';

class CommandBlock extends ConsumerWidget {
  final Command command;

  const CommandBlock({super.key, required this.command});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(vibeTermThemeProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: VibeTermSpacing.sm),
      decoration: BoxDecoration(
        color: theme.bgBlock,
        borderRadius: BorderRadius.circular(VibeTermRadius.md),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommandHeader(command: command, theme: theme),
          if (command.output.isNotEmpty || command.isRunning)
            _CommandOutput(command: command, theme: theme),
        ],
      ),
    );
  }
}

class _CommandHeader extends StatelessWidget {
  final Command command;
  final VibeTermThemeData theme;

  const _CommandHeader({required this.command, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VibeTermSpacing.sm),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '>',
            style: VibeTermTypography.prompt.copyWith(
              color: theme.accent,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: VibeTermSpacing.xs),
          Expanded(
            child: Text(
              command.command,
              style: VibeTermTypography.commandHeader.copyWith(color: theme.text),
            ),
          ),
          if (command.isRunning)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.accent,
              ),
            )
          else
            Text(
              command.executionTimeLabel,
              style: VibeTermTypography.caption.copyWith(
                color: theme.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _CommandOutput extends StatelessWidget {
  final Command command;
  final VibeTermThemeData theme;

  const _CommandOutput({required this.command, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VibeTermSpacing.sm),
      child: command.isRunning && command.output.isEmpty
          ? Text(
              '...',
              style: VibeTermTypography.terminalOutput.copyWith(
                color: theme.textMuted,
              ),
            )
          : Text(
              command.output,
              style: VibeTermTypography.terminalOutput.copyWith(color: theme.text),
            ),
    );
  }
}
