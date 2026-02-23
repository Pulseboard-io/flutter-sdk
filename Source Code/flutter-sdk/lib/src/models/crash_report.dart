import '../utils/id_generator.dart';
import 'breadcrumb.dart';

/// A crash report event.
class CrashReport {
  final String type;
  final String eventId;
  final String timestamp;
  final String fingerprint;
  final bool? fatal;
  final CrashException exception;
  final List<Breadcrumb>? breadcrumbs;

  CrashReport({
    this.type = 'crash',
    String? eventId,
    String? timestamp,
    required this.fingerprint,
    this.fatal,
    required this.exception,
    this.breadcrumbs,
  })  : eventId = eventId ?? IdGenerator.uuid(),
        timestamp = timestamp ?? DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': type,
      'event_id': eventId,
      'timestamp': timestamp,
      'fingerprint': fingerprint,
      'exception': exception.toJson(),
    };
    if (fatal != null) json['fatal'] = fatal;
    if (breadcrumbs != null && breadcrumbs!.isNotEmpty) {
      json['breadcrumbs'] = breadcrumbs!.map((b) => b.toJson()).toList();
    }
    return json;
  }

  factory CrashReport.fromJson(Map<String, dynamic> json) {
    return CrashReport(
      type: json['type'] as String? ?? 'crash',
      eventId: json['event_id'] as String?,
      timestamp: json['timestamp'] as String?,
      fingerprint: json['fingerprint'] as String,
      fatal: json['fatal'] as bool?,
      exception: CrashException.fromJson(
        json['exception'] as Map<String, dynamic>,
      ),
      breadcrumbs: (json['breadcrumbs'] as List<dynamic>?)
          ?.map((b) => Breadcrumb.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Exception details within a crash report.
class CrashException {
  final String type;
  final String message;
  final String? stacktrace;

  const CrashException({
    required this.type,
    required this.message,
    this.stacktrace,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': type,
      'message': message,
    };
    if (stacktrace != null) json['stacktrace'] = stacktrace;
    return json;
  }

  factory CrashException.fromJson(Map<String, dynamic> json) {
    return CrashException(
      type: json['type'] as String,
      message: json['message'] as String,
      stacktrace: json['stacktrace'] as String?,
    );
  }
}
