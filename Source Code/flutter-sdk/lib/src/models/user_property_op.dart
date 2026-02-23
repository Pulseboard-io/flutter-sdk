import '../utils/id_generator.dart';

/// A user properties event containing one or more operations.
class UserPropertiesEvent {
  final String type;
  final String eventId;
  final String timestamp;
  final List<UserPropertyOp> operations;

  UserPropertiesEvent({
    this.type = 'user_properties',
    String? eventId,
    String? timestamp,
    required this.operations,
  })  : eventId = eventId ?? IdGenerator.uuid(),
        timestamp = timestamp ?? DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> toJson() => {
        'type': type,
        'event_id': eventId,
        'timestamp': timestamp,
        'operations': operations.map((o) => o.toJson()).toList(),
      };

  factory UserPropertiesEvent.fromJson(Map<String, dynamic> json) {
    return UserPropertiesEvent(
      type: json['type'] as String? ?? 'user_properties',
      eventId: json['event_id'] as String?,
      timestamp: json['timestamp'] as String?,
      operations: (json['operations'] as List<dynamic>)
          .map((o) => UserPropertyOp.fromJson(o as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A single user property operation.
class UserPropertyOp {
  final String op;
  final String key;
  final dynamic value;

  const UserPropertyOp({
    required this.op,
    required this.key,
    this.value,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'op': op,
      'key': key,
    };
    if (op != 'unset' && value != null) {
      json['value'] = value;
    }
    return json;
  }

  factory UserPropertyOp.fromJson(Map<String, dynamic> json) {
    return UserPropertyOp(
      op: json['op'] as String,
      key: json['key'] as String,
      value: json['value'],
    );
  }
}
