import 'package:uuid/uuid.dart';

/// Generates UUIDs and idempotency keys for the SDK.
class IdGenerator {
  static const Uuid _uuid = Uuid();

  /// Generate a v4 UUID string.
  static String uuid() => _uuid.v4();

  /// Generate an idempotency key for batch submissions.
  static String idempotencyKey() => _uuid.v4();
}
