import '../utils/id_generator.dart';

/// A performance trace event.
class TraceEvent {
  final String type;
  final String eventId;
  final String timestamp;
  final TraceData trace;

  TraceEvent({
    this.type = 'trace',
    String? eventId,
    String? timestamp,
    required this.trace,
  })  : eventId = eventId ?? IdGenerator.uuid(),
        timestamp = timestamp ?? DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> toJson() => {
        'type': type,
        'event_id': eventId,
        'timestamp': timestamp,
        'trace': trace.toJson(),
      };

  factory TraceEvent.fromJson(Map<String, dynamic> json) {
    return TraceEvent(
      type: json['type'] as String? ?? 'trace',
      eventId: json['event_id'] as String?,
      timestamp: json['timestamp'] as String?,
      trace: TraceData.fromJson(json['trace'] as Map<String, dynamic>),
    );
  }
}

/// Trace data within a trace event.
class TraceData {
  final String traceId;
  final String name;
  final int durationMs;
  final Map<String, dynamic>? attributes;

  const TraceData({
    required this.traceId,
    required this.name,
    required this.durationMs,
    this.attributes,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'trace_id': traceId,
      'name': name,
      'duration_ms': durationMs,
    };
    if (attributes != null) json['attributes'] = attributes;
    return json;
  }

  factory TraceData.fromJson(Map<String, dynamic> json) {
    return TraceData(
      traceId: json['trace_id'] as String,
      name: json['name'] as String,
      durationMs: json['duration_ms'] as int,
      attributes: json['attributes'] as Map<String, dynamic>?,
    );
  }
}
