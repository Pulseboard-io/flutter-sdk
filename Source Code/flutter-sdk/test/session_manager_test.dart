import 'package:app_analytics/src/services/session_manager.dart';
import 'package:app_analytics/src/utils/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClock implements Clock {
  DateTime _now = DateTime.utc(2026, 1, 1);

  @override
  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionManager', () {
    late _FakeClock clock;
    late List<(String, String)> sessionEvents;
    late SessionManager manager;

    setUp(() {
      clock = _FakeClock();
      sessionEvents = [];
      manager = SessionManager(
        timeoutMinutes: 5,
        clock: clock,
        onSessionEvent: (name, sessionId) {
          sessionEvents.add((name, sessionId));
        },
      );
    });

    tearDown(() {
      manager.stop();
    });

    test('start creates a new session', () {
      manager.start();

      expect(manager.currentSessionId, isNotNull);
      expect(manager.isActive, true);
      expect(sessionEvents.length, 1);
      expect(sessionEvents.first.$1, 'session_start');
    });

    test('stop ends the session', () {
      manager.start();
      manager.stop();

      expect(manager.currentSessionId, isNull);
      expect(manager.isActive, false);
      expect(sessionEvents.length, 2);
      expect(sessionEvents.last.$1, 'session_end');
    });

    test('resume within timeout keeps same session', () {
      manager.start();
      final originalSessionId = manager.currentSessionId;

      // Simulate backgrounding
      manager.didChangeAppLifecycleState(AppLifecycleState.paused);
      clock.advance(const Duration(minutes: 3));
      manager.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(manager.currentSessionId, originalSessionId);
      // Only session_start event, no new session
      expect(sessionEvents.length, 1);
    });

    test('resume after timeout creates new session', () {
      manager.start();
      final originalSessionId = manager.currentSessionId;

      manager.didChangeAppLifecycleState(AppLifecycleState.paused);
      clock.advance(const Duration(minutes: 6));
      manager.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(manager.currentSessionId, isNot(originalSessionId));
      // session_start, session_end, session_start
      expect(sessionEvents.length, 3);
      expect(sessionEvents[1].$1, 'session_end');
      expect(sessionEvents[2].$1, 'session_start');
    });

    test('multiple starts are idempotent', () {
      manager.start();
      final firstId = manager.currentSessionId;
      manager.start();

      expect(manager.currentSessionId, firstId);
      expect(sessionEvents.length, 1);
    });
  });
}
