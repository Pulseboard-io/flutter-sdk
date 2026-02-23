import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models/analytics_event.dart';
import 'models/app_info.dart';
import 'models/breadcrumb.dart';
import 'models/crash_report.dart';
import 'models/device_info_model.dart';
import 'models/trace_event.dart';
import 'models/user_info.dart';
import 'models/user_property_op.dart';
import 'services/batch_processor.dart';
import 'services/crash_handler.dart';
import 'services/device_info_provider.dart';
import 'services/http_client.dart';
import 'services/persistence.dart';
import 'services/session_manager.dart';
import 'utils/id_generator.dart';
import 'utils/logger.dart';

/// Pulseboard analytics client singleton.
///
/// Usage:
/// ```dart
/// await AppAnalytics.initialize(
///   AnalyticsConfig(dsn: 'https://key@host/project/env'),
/// );
/// AppAnalytics.instance.track('button_pressed', properties: {'id': '1'});
/// ```
class AppAnalytics {
  static AppAnalytics? _instance;

  /// Get the singleton instance. Throws if not initialized.
  static AppAnalytics get instance {
    if (_instance == null) {
      throw StateError(
        'AppAnalytics not initialized. Call AppAnalytics.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Whether the SDK has been initialized.
  static bool get isInitialized => _instance != null;

  final AnalyticsConfig _config;
  final SdkLogger _logger;
  final AnalyticsHttpClient _httpClient;
  final BatchProcessor _batchProcessor;
  final SessionManager _sessionManager;
  final CrashHandler _crashHandler;
  UserInfo _userInfo;
  AppInfo? _appInfo;
  DeviceInfoModel? _deviceInfo;
  bool _optedOut = false;

  AppAnalytics._({
    required AnalyticsConfig config,
    required SdkLogger logger,
    required AnalyticsHttpClient httpClient,
    required BatchProcessor batchProcessor,
    required SessionManager sessionManager,
    required CrashHandler crashHandler,
    required UserInfo userInfo,
  })  : _config = config,
        _logger = logger,
        _httpClient = httpClient,
        _batchProcessor = batchProcessor,
        _sessionManager = sessionManager,
        _crashHandler = crashHandler,
        _userInfo = userInfo;

  /// Initialize the analytics SDK.
  ///
  /// Must be called once before using any other SDK methods.
  /// Typically called in `main()` after `WidgetsFlutterBinding.ensureInitialized()`.
  static Future<AppAnalytics> initialize(
    AnalyticsConfig config, {
    http.Client? httpClient,
  }) async {
    if (_instance != null) {
      _instance!._logger.warning('SDK already initialized, returning existing instance');
      return _instance!;
    }

    WidgetsFlutterBinding.ensureInitialized();

    final logger = SdkLogger(enabled: config.debug);
    logger.debug('Initializing Pulseboard SDK');

    final analyticsHttpClient = AnalyticsHttpClient(
      config: config,
      client: httpClient,
      logger: logger,
    );

    final persistence = Persistence(
      maxEvents: config.maxPersistedEvents,
      logger: logger,
    );

    final batchProcessor = BatchProcessor(
      config: config,
      httpClient: analyticsHttpClient,
      persistence: persistence,
      logger: logger,
    );

    final sessionManager = SessionManager(
      timeoutMinutes: config.sessionTimeoutMinutes,
      logger: logger,
      onSessionEvent: (eventName, sessionId) {
        _instance?._enqueueSessionEvent(eventName, sessionId);
      },
    );

    final crashHandler = CrashHandler(
      maxBreadcrumbs: config.maxBreadcrumbs,
      logger: logger,
      onCrash: (report) {
        _instance?._enqueueCrashReport(report);
      },
    );

    final deviceInfoProvider = DeviceInfoProvider();

    // Load or generate anonymous ID
    final prefs = await SharedPreferences.getInstance();
    var anonymousId = prefs.getString('pulseboard_anonymous_id');
    if (anonymousId == null) {
      anonymousId = IdGenerator.uuid();
      await prefs.setString('pulseboard_anonymous_id', anonymousId);
    }

    final userInfo = UserInfo(anonymousId: anonymousId);

    final instance = AppAnalytics._(
      config: config,
      logger: logger,
      httpClient: analyticsHttpClient,
      batchProcessor: batchProcessor,
      sessionManager: sessionManager,
      crashHandler: crashHandler,
      userInfo: userInfo,
    );

    _instance = instance;

    // Fetch device/app info
    try {
      instance._deviceInfo = await deviceInfoProvider.getDeviceInfo();
      instance._appInfo = await deviceInfoProvider.getAppInfo();
    } catch (e) {
      logger.warning('Could not fetch device/app info: $e');
    }

    // Wire up context providers
    batchProcessor.appInfoProvider = () =>
        instance._appInfo ??
        const AppInfo(
          bundleId: 'unknown',
          versionName: '0.0.0',
          buildNumber: '0',
        );
    batchProcessor.deviceInfoProvider = () =>
        instance._deviceInfo ??
        const DeviceInfoModel(
          deviceId: 'unknown',
          platform: 'android',
          osVersion: '0',
          model: 'unknown',
        );
    batchProcessor.userInfoProvider = () => instance._userInfo;

    // Start services
    batchProcessor.start();
    sessionManager.start();
    crashHandler.install();

    logger.debug('Pulseboard SDK initialized');
    return instance;
  }

  /// Track a named event.
  void track(String name, {Map<String, dynamic>? properties}) {
    if (_optedOut) return;

    final event = AnalyticsEvent(
      name: name,
      sessionId: _sessionManager.currentSessionId,
      properties: properties,
    );

    _batchProcessor.enqueue(event.toJson());
  }

  /// Identify a user by their ID.
  void identify(String userId) {
    _userInfo = _userInfo.copyWith(userId: userId);
    _logger.debug('User identified: $userId');
  }

  /// Set a user property.
  void setUserProperty(String key, dynamic value) {
    _enqueueUserPropertyOp(
      UserPropertyOp(op: 'set', key: key, value: value),
    );
  }

  /// Set a user property only if not already set.
  void setUserPropertyOnce(String key, dynamic value) {
    _enqueueUserPropertyOp(
      UserPropertyOp(op: 'set_once', key: key, value: value),
    );
  }

  /// Increment a numeric user property.
  void incrementUserProperty(String key, num value) {
    _enqueueUserPropertyOp(
      UserPropertyOp(op: 'increment', key: key, value: value),
    );
  }

  /// Remove a user property.
  void unsetUserProperty(String key) {
    _enqueueUserPropertyOp(
      UserPropertyOp(op: 'unset', key: key),
    );
  }

  /// Start a performance trace and return a [Trace] handle.
  Trace startTrace(String name) {
    return Trace._(name: name, client: this);
  }

  /// Flush all queued events immediately.
  Future<void> flush() => _batchProcessor.flush();

  /// Reset the SDK state (anonymous ID, user, session).
  Future<void> reset() async {
    _sessionManager.stop();

    final newAnonymousId = IdGenerator.uuid();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pulseboard_anonymous_id', newAnonymousId);
    _userInfo = UserInfo(anonymousId: newAnonymousId);

    _sessionManager.start();
    _logger.debug('SDK reset with new anonymous ID');
  }

  /// Opt out of all tracking. Clears queue.
  void optOut() {
    _optedOut = true;
    _batchProcessor.setOptOut(true);
    _logger.debug('User opted out');
  }

  /// Opt back in to tracking.
  void optIn() {
    _optedOut = false;
    _batchProcessor.setOptOut(false);
    _logger.debug('User opted in');
  }

  /// Grant consent for data collection.
  void grantConsent() {
    _batchProcessor.setConsent(true);
    _logger.debug('Consent granted');
  }

  /// Revoke consent for data collection. Clears queue.
  void revokeConsent() {
    _batchProcessor.setConsent(false);
    _logger.debug('Consent revoked');
  }

  /// Add a breadcrumb for crash context.
  void addBreadcrumb({required String type, required String message}) {
    _crashHandler.addBreadcrumb(
      Breadcrumb(type: type, message: message),
    );
  }

  /// Shut down the SDK and release resources.
  Future<void> shutdown() async {
    _crashHandler.uninstall();
    _sessionManager.stop();
    await _batchProcessor.shutdown();
    _httpClient.close();
    _instance = null;
    _logger.debug('SDK shut down');
  }

  /// Access the current config (read-only).
  AnalyticsConfig get config => _config;

  // -- Internal methods --

  void _enqueueSessionEvent(String eventName, String sessionId) {
    if (_optedOut) return;
    final event = AnalyticsEvent(
      name: eventName,
      sessionId: sessionId,
    );
    _batchProcessor.enqueue(event.toJson());
  }

  void _enqueueCrashReport(CrashReport report) {
    _batchProcessor.enqueue(report.toJson());
    // Immediately flush crash reports
    _batchProcessor.flush();
  }

  void _enqueueUserPropertyOp(UserPropertyOp op) {
    if (_optedOut) return;
    final event = UserPropertiesEvent(operations: [op]);
    _batchProcessor.enqueue(event.toJson());
  }

  void _enqueueTrace(TraceEvent trace) {
    if (_optedOut) return;
    _batchProcessor.enqueue(trace.toJson());
  }

  /// For testing: reset the singleton.
  static void resetForTesting() {
    _instance = null;
  }
}

/// A performance trace handle.
class Trace {
  final String _name;
  final AppAnalytics _client;
  final DateTime _startTime;
  final Map<String, dynamic> _attributes = {};

  Trace._({required String name, required AppAnalytics client})
      : _name = name,
        _client = client,
        _startTime = DateTime.now().toUtc();

  /// Add an attribute to this trace.
  void putAttribute(String key, dynamic value) {
    _attributes[key] = value;
  }

  /// Stop the trace and send it.
  void stop() {
    final duration = DateTime.now().toUtc().difference(_startTime);
    final trace = TraceEvent(
      trace: TraceData(
        traceId: IdGenerator.uuid(),
        name: _name,
        durationMs: duration.inMilliseconds,
        attributes: _attributes.isNotEmpty ? Map.from(_attributes) : null,
      ),
    );
    _client._enqueueTrace(trace);
  }
}
