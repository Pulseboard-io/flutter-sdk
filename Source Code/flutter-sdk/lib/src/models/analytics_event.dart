import '../utils/id_generator.dart';

/// Represents a single analytics event.
class AnalyticsEvent {
  final String type;
  final String eventId;
  final String timestamp;
  final String? name;
  final String? sessionId;
  final Map<String, dynamic>? properties;

  AnalyticsEvent({
    this.type = 'event',
    String? eventId,
    String? timestamp,
    this.name,
    this.sessionId,
    this.properties,
  })  : eventId = eventId ?? IdGenerator.uuid(),
        timestamp = timestamp ?? DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'type': type,
      'event_id': eventId,
      'timestamp': timestamp,
    };
    if (name != null) json['name'] = name;
    if (sessionId != null) json['session_id'] = sessionId;
    if (properties != null) json['properties'] = properties;
    return json;
  }

  factory AnalyticsEvent.fromJson(Map<String, dynamic> json) {
    return AnalyticsEvent(
      type: json['type'] as String? ?? 'event',
      eventId: json['event_id'] as String?,
      timestamp: json['timestamp'] as String?,
      name: json['name'] as String?,
      sessionId: json['session_id'] as String?,
      properties: json['properties'] as Map<String, dynamic>?,
    );
  }
}
