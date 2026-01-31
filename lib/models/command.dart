import 'package:flutter/foundation.dart';

@immutable
class Command {
  final String id;
  final String command;
  final String output;
  final Duration executionTime;
  final DateTime timestamp;
  final bool isRunning;

  const Command({
    required this.id,
    required this.command,
    this.output = '',
    this.executionTime = Duration.zero,
    required this.timestamp,
    this.isRunning = false,
  });

  Command copyWith({
    String? id,
    String? command,
    String? output,
    Duration? executionTime,
    DateTime? timestamp,
    bool? isRunning,
  }) {
    return Command(
      id: id ?? this.id,
      command: command ?? this.command,
      output: output ?? this.output,
      executionTime: executionTime ?? this.executionTime,
      timestamp: timestamp ?? this.timestamp,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  String get executionTimeLabel {
    if (executionTime.inMilliseconds < 1000) {
      return '${(executionTime.inMilliseconds / 1000).toStringAsFixed(3)}s';
    }
    return '${executionTime.inSeconds}.${(executionTime.inMilliseconds % 1000 ~/ 100)}s';
  }
}
