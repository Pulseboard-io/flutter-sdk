// ignore_for_file: avoid_print

/// Internal SDK debug logger.
///
/// Only outputs when [enabled] is true.
class SdkLogger {
  /// Whether debug logging is enabled.
  bool enabled;

  /// Override print function for testing.
  void Function(String)? printOverride;

  SdkLogger({this.enabled = false, this.printOverride});

  void debug(String message) {
    if (enabled) {
      _log('DEBUG', message);
    }
  }

  void warning(String message) {
    if (enabled) {
      _log('WARN', message);
    }
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (enabled) {
      _log('ERROR', message);
      if (error != null) {
        _log('ERROR', error.toString());
      }
    }
  }

  void _log(String level, String message) {
    final output = '[Pulseboard][$level] $message';
    if (printOverride != null) {
      printOverride!(output);
    } else {
      print(output);
    }
  }
}
