import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../config.dart';
import '../models/app_info.dart';
import '../models/batch_payload.dart';
import '../models/device_info_model.dart';
import '../models/user_info.dart';
import '../utils/logger.dart';
import 'http_client.dart';
import 'persistence.dart';

/// Queues events and flushes them in batches.
///
/// Flushes when:
/// - Queue reaches [config.flushAt] events
/// - Timer fires every [config.flushIntervalSeconds]
/// - [flush] is called explicitly
/// - Connectivity restores (loads persisted events)
class BatchProcessor {
  final AnalyticsConfig _config;
  final AnalyticsHttpClient _httpClient;
  final Persistence _persistence;
  final SdkLogger _logger;
  final Connectivity _connectivity;

  final List<Map<String, dynamic>> _queue = [];
  Timer? _flushTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isFlushing = false;
  bool _hasConsent = true;
  bool _isOptedOut = false;

  /// Callbacks for providing current context.
  AppInfo Function()? appInfoProvider;
  DeviceInfoModel Function()? deviceInfoProvider;
  UserInfo Function()? userInfoProvider;

  BatchProcessor({
    required AnalyticsConfig config,
    required AnalyticsHttpClient httpClient,
    Persistence? persistence,
    SdkLogger? logger,
    Connectivity? connectivity,
  })  : _config = config,
        _httpClient = httpClient,
        _persistence = persistence ?? Persistence(),
        _logger = logger ?? SdkLogger(),
        _connectivity = connectivity ?? Connectivity();

  /// Number of events currently in the queue.
  int get queueLength => _queue.length;

  /// Start the flush timer and connectivity listener.
  void start() {
    _startTimer();
    _listenConnectivity();
  }

  /// Stop the timer and connectivity listener.
  void stop() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  /// Add an event to the queue.
  ///
  /// Applies sampling and consent checks. Auto-flushes if threshold reached.
  void enqueue(Map<String, dynamic> event) {
    if (_isOptedOut) return;
    if (!_hasConsent) return;

    // Sampling
    if (_config.sampleRate < 1.0) {
      if (Random().nextDouble() > _config.sampleRate) return;
    }

    _queue.add(event);
    _logger.debug('Event queued (${_queue.length}/${_config.flushAt})');

    if (_queue.length >= _config.flushAt) {
      flush();
    }
  }

  /// Flush all queued events to the API.
  Future<void> flush() async {
    if (_isFlushing) return;
    if (_queue.isEmpty) return;
    if (_isOptedOut) {
      _queue.clear();
      return;
    }

    _isFlushing = true;

    try {
      // Take current batch (up to 500 per API limit)
      final batchEvents = _queue.length > 500
          ? _queue.sublist(0, 500)
          : List<Map<String, dynamic>>.from(_queue);
      _queue.removeRange(0, batchEvents.length);

      final payload = _buildPayload(batchEvents);
      final result = await _sendWithRetry(payload);

      if (!result.success) {
        _logger.warning('Batch send failed, persisting ${batchEvents.length} events');
        await _persistence.saveEvents(batchEvents);
      } else {
        _logger.debug(
            'Batch sent: ${result.response?.accepted} accepted');
      }
    } finally {
      _isFlushing = false;
    }

    // If there are still events queued, flush again
    if (_queue.isNotEmpty) {
      await flush();
    }
  }

  /// Set consent status. If revoked, queued events are cleared.
  void setConsent(bool hasConsent) {
    _hasConsent = hasConsent;
    if (!hasConsent) {
      _queue.clear();
      _logger.debug('Consent revoked, queue cleared');
    }
  }

  /// Set opt-out status. If opted out, queued events are cleared.
  void setOptOut(bool optedOut) {
    _isOptedOut = optedOut;
    if (optedOut) {
      _queue.clear();
      _logger.debug('Opted out, queue cleared');
    }
  }

  /// Persist any remaining events and stop.
  Future<void> shutdown() async {
    stop();
    if (_queue.isNotEmpty) {
      await _persistence.saveEvents(List.from(_queue));
      _queue.clear();
    }
  }

  BatchPayload _buildPayload(List<Map<String, dynamic>> events) {
    return BatchPayload(
      environment: _config.environment,
      app: appInfoProvider?.call() ??
          const AppInfo(
            bundleId: 'unknown',
            versionName: '0.0.0',
            buildNumber: '0',
          ),
      device: deviceInfoProvider?.call() ??
          const DeviceInfoModel(
            deviceId: 'unknown',
            platform: 'android',
            osVersion: '0',
            model: 'unknown',
          ),
      user: userInfoProvider?.call() ??
          const UserInfo(anonymousId: 'unknown'),
      events: events,
    );
  }

  Future<SendResult> _sendWithRetry(BatchPayload payload) async {
    SendResult? lastResult;
    for (var attempt = 0; attempt <= _config.maxRetries; attempt++) {
      if (attempt > 0) {
        // Exponential backoff: 1s, 2s, 4s...
        final delay = Duration(seconds: pow(2, attempt - 1).toInt());
        _logger.debug('Retry attempt $attempt after ${delay.inSeconds}s');
        await Future<void>.delayed(delay);
      }

      lastResult = await _httpClient.sendBatch(payload);

      if (lastResult.success || !lastResult.shouldRetry) {
        return lastResult;
      }
    }

    return lastResult ??
        const SendResult(
          success: false,
          statusCode: 0,
          error: 'No attempts made',
          shouldRetry: false,
        );
  }

  void _startTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      Duration(seconds: _config.flushIntervalSeconds),
      (_) => flush(),
    );
  }

  void _listenConnectivity() {
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      (results) async {
        final hasConnection =
            results.any((r) => r != ConnectivityResult.none);
        if (hasConnection) {
          _logger.debug('Connectivity restored, loading persisted events');
          final persisted = await _persistence.loadEvents();
          if (persisted.isNotEmpty) {
            _queue.insertAll(0, persisted);
            await _persistence.clear();
            await flush();
          }
        }
      },
    );
  }
}
