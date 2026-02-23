/// Testable clock abstraction for the SDK.
abstract class Clock {
  /// Returns the current time.
  DateTime now();
}

/// Default clock using [DateTime.now].
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
