import 'package:flutter/widgets.dart';

import '../utils/clock.dart';
import '../utils/id_generator.dart';
import '../utils/logger.dart';

/// Callback for session lifecycle events.
typedef SessionEventCallback = void Function(
    String eventName, String sessionId);

/// Manages session lifecycle based on app state.
///
/// - Starts a new session on initialization.
/// - Ends session when app goes to background.
/// - Resumes session if app returns within [timeoutMinutes].
/// - Starts a new session if timeout exceeded.
class SessionManager with WidgetsBindingObserver {
  final int timeoutMinutes;
  final Clock _clock;
  final SdkLogger _logger;
  final SessionEventCallback? _onSessionEvent;

  String? _currentSessionId;
  DateTime? _backgroundedAt;
  bool _isActive = false;

  SessionManager({
    this.timeoutMinutes = 5,
    Clock? clock,
    SdkLogger? logger,
    SessionEventCallback? onSessionEvent,
  })  : _clock = clock ?? const SystemClock(),
        _logger = logger ?? SdkLogger(),
        _onSessionEvent = onSessionEvent;

  /// The current session ID, or null if no session is active.
  String? get currentSessionId => _currentSessionId;

  /// Whether the session manager is actively observing.
  bool get isActive => _isActive;

  /// Start observing app lifecycle and begin a session.
  void start() {
    if (_isActive) return;
    _isActive = true;
    WidgetsBinding.instance.addObserver(this);
    _startNewSession();
  }

  /// Stop observing and end the current session.
  void stop() {
    if (!_isActive) return;
    _endCurrentSession();
    _isActive = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isActive) return;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _onBackgrounded();
      case AppLifecycleState.resumed:
        _onResumed();
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _onBackgrounded() {
    _backgroundedAt = _clock.now();
    _logger.debug('App backgrounded, session $_currentSessionId paused');
  }

  void _onResumed() {
    if (_backgroundedAt == null || _currentSessionId == null) {
      _startNewSession();
      return;
    }

    final elapsed = _clock.now().difference(_backgroundedAt!);
    if (elapsed.inMinutes >= timeoutMinutes) {
      _logger.debug(
          'Session timeout exceeded (${elapsed.inMinutes}min), starting new session');
      _endCurrentSession();
      _startNewSession();
    } else {
      _logger.debug('Session $_currentSessionId resumed');
    }
    _backgroundedAt = null;
  }

  void _startNewSession() {
    _currentSessionId = IdGenerator.uuid();
    _logger.debug('Session started: $_currentSessionId');
    _onSessionEvent?.call('session_start', _currentSessionId!);
  }

  void _endCurrentSession() {
    if (_currentSessionId != null) {
      _logger.debug('Session ended: $_currentSessionId');
      _onSessionEvent?.call('session_end', _currentSessionId!);
      _currentSessionId = null;
    }
  }
}
