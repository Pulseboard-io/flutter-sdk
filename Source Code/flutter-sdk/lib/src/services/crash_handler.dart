import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../models/breadcrumb.dart';
import '../models/crash_report.dart';
import '../utils/logger.dart';

/// Callback invoked when a crash is captured.
typedef CrashCallback = void Function(CrashReport report);

/// Captures Flutter errors and platform errors, manages breadcrumbs.
class CrashHandler {
  final int maxBreadcrumbs;
  final SdkLogger _logger;
  final CrashCallback? _onCrash;
  final List<Breadcrumb> _breadcrumbs = [];

  FlutterExceptionHandler? _previousFlutterHandler;
  ErrorCallback? _previousPlatformHandler;
  bool _isInstalled = false;

  CrashHandler({
    this.maxBreadcrumbs = 20,
    SdkLogger? logger,
    CrashCallback? onCrash,
  })  : _logger = logger ?? SdkLogger(),
        _onCrash = onCrash;

  /// Install error handlers.
  void install() {
    if (_isInstalled) return;
    _isInstalled = true;

    _previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = _handleFlutterError;

    _previousPlatformHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = _handlePlatformError;

    _logger.debug('Crash handler installed');
  }

  /// Uninstall error handlers and restore previous ones.
  void uninstall() {
    if (!_isInstalled) return;
    _isInstalled = false;

    FlutterError.onError = _previousFlutterHandler;
    PlatformDispatcher.instance.onError = _previousPlatformHandler;

    _logger.debug('Crash handler uninstalled');
  }

  /// Add a breadcrumb for crash context.
  void addBreadcrumb(Breadcrumb breadcrumb) {
    _breadcrumbs.add(breadcrumb);
    if (_breadcrumbs.length > maxBreadcrumbs) {
      _breadcrumbs.removeAt(0);
    }
  }

  /// Get current breadcrumbs (copy).
  List<Breadcrumb> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  /// Clear all breadcrumbs.
  void clearBreadcrumbs() => _breadcrumbs.clear();

  void _handleFlutterError(FlutterErrorDetails details) {
    _logger.debug('Caught Flutter error: ${details.exceptionAsString()}');

    final fingerprint = _generateFingerprint(
      details.exception.runtimeType.toString(),
      details.exceptionAsString(),
    );

    final report = CrashReport(
      fingerprint: fingerprint,
      fatal: false,
      exception: CrashException(
        type: details.exception.runtimeType.toString(),
        message: details.exceptionAsString(),
        stacktrace: details.stack?.toString(),
      ),
      breadcrumbs: List.from(_breadcrumbs),
    );

    _onCrash?.call(report);

    // Also call previous handler
    _previousFlutterHandler?.call(details);
  }

  bool _handlePlatformError(Object error, StackTrace stackTrace) {
    _logger.debug('Caught platform error: $error');

    final fingerprint = _generateFingerprint(
      error.runtimeType.toString(),
      error.toString(),
    );

    final report = CrashReport(
      fingerprint: fingerprint,
      fatal: true,
      exception: CrashException(
        type: error.runtimeType.toString(),
        message: error.toString(),
        stacktrace: stackTrace.toString(),
      ),
      breadcrumbs: List.from(_breadcrumbs),
    );

    _onCrash?.call(report);

    // Call previous handler if exists
    return _previousPlatformHandler?.call(error, stackTrace) ?? false;
  }

  /// Generate a simple fingerprint from exception type and message.
  String _generateFingerprint(String type, String message) {
    // Use first line of message + type for grouping
    final firstLine = message.split('\n').first;
    final input = '$type:$firstLine';
    // Simple hash - in production you'd use a proper hash
    return input.hashCode.toRadixString(16).padLeft(8, '0');
  }
}
