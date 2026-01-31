import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../models/models.dart';

class SessionsNotifier extends StateNotifier<List<Session>> {
  SessionsNotifier() : super([]);

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

  void updateTmuxSession(String id, String tmuxSession) {
    state = state.map((s) {
      if (s.id == id) {
        return s.copyWith(tmuxSession: tmuxSession);
      }
      return s;
    }).toList();
  }

  void toggleQuickAccess(String id) {
    state = state.map((s) {
      if (s.id == id) {
        return s.copyWith(isQuickAccess: !s.isQuickAccess);
      }
      return s;
    }).toList();
  }
}

final sessionsProvider = StateNotifierProvider<SessionsNotifier, List<Session>>(
  (ref) => SessionsNotifier(),
);

final activeSessionIndexProvider = StateProvider<int>((ref) => 0);

final activeSessionProvider = Provider<Session?>((ref) {
  final sessions = ref.watch(sessionsProvider);
  final index = ref.watch(activeSessionIndexProvider);
  if (sessions.isEmpty || index >= sessions.length) return null;
  return sessions[index];
});
