import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';

class SessionsNotifier extends Notifier<List<Session>> {
  @override
  List<Session> build() => [];

  final _uuid = const Uuid();

  void addSession({
    required String name,
    required String host,
    required String username,
    int port = 22,
  }) {
    final session = Session(
      id: _uuid.v4(),
      name: name,
      host: host,
      port: port,
      username: username,
    );
    state = [...state, session];
  }

  void removeSession(String id) {
    state = state.where((s) => s.id != id).toList();
  }

  void clearSessions() {
    state = [];
  }

  void updateSessionStatus(String id, ConnectionStatus status) {
    state = state.map((s) {
      if (s.id == id) {
        return s.copyWith(
          status: status,
          lastConnected: status == ConnectionStatus.connected
              ? DateTime.now()
              : s.lastConnected,
        );
      }
      return s;
    }).toList();
  }
}

final sessionsProvider = NotifierProvider<SessionsNotifier, List<Session>>(
  SessionsNotifier.new,
);

class _ActiveSessionIndex extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) => state = value;
}

final activeSessionIndexProvider = NotifierProvider<_ActiveSessionIndex, int>(
  _ActiveSessionIndex.new,
);

final activeSessionProvider = Provider<Session?>((ref) {
  final sessions = ref.watch(sessionsProvider);
  final index = ref.watch(activeSessionIndexProvider);
  if (sessions.isEmpty || index >= sessions.length) return null;
  return sessions[index];
});
