import 'package:flutter_test/flutter_test.dart';
import 'package:vibeterm/models/command.dart';

void main() {
  group('Command', () {
    test('default values are correct', () {
      final cmd = Command(id: '1', command: 'ls', timestamp: DateTime(2026));
      expect(cmd.output, '');
      expect(cmd.executionTime, Duration.zero);
      expect(cmd.isRunning, false);
    });

    test('copyWith updates specific fields', () {
      final original = Command(
        id: '1',
        command: 'ls',
        timestamp: DateTime(2026),
        isRunning: true,
      );

      final completed = original.copyWith(
        output: 'file.txt\ndir/',
        isRunning: false,
        executionTime: const Duration(milliseconds: 150),
      );

      expect(completed.output, 'file.txt\ndir/');
      expect(completed.isRunning, false);
      expect(completed.executionTime, const Duration(milliseconds: 150));
      expect(completed.command, 'ls');
      expect(completed.id, '1');
    });

    test('executionTimeLabel formats sub-second correctly', () {
      final cmd = Command(
        id: '1',
        command: 'pwd',
        timestamp: DateTime(2026),
        executionTime: const Duration(milliseconds: 42),
      );
      expect(cmd.executionTimeLabel, '0.042s');
    });

    test('executionTimeLabel formats seconds correctly', () {
      final cmd = Command(
        id: '1',
        command: 'build',
        timestamp: DateTime(2026),
        executionTime: const Duration(seconds: 3, milliseconds: 500),
      );
      expect(cmd.executionTimeLabel, '3.5s');
    });

    test('executionTimeLabel formats exact second correctly', () {
      final cmd = Command(
        id: '1',
        command: 'test',
        timestamp: DateTime(2026),
        executionTime: const Duration(seconds: 1),
      );
      expect(cmd.executionTimeLabel, '1.0s');
    });

    test('executionTimeLabel formats zero correctly', () {
      final cmd = Command(
        id: '1',
        command: 'echo',
        timestamp: DateTime(2026),
        executionTime: Duration.zero,
      );
      expect(cmd.executionTimeLabel, '0.000s');
    });
  });
}
