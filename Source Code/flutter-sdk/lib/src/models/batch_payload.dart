import 'app_info.dart';
import 'device_info_model.dart';
import 'user_info.dart';

/// The full batch payload sent to the API.
///
/// Matches the PRD v1.0 schema and the API's IngestBatchRequest validation.
class BatchPayload {
  static const String currentSchemaVersion = '1.0';

  final String schemaVersion;
  final String sentAt;
  final String environment;
  final AppInfo app;
  final DeviceInfoModel device;
  final UserInfo user;
  final List<Map<String, dynamic>> events;

  BatchPayload({
    this.schemaVersion = currentSchemaVersion,
    String? sentAt,
    required this.environment,
    required this.app,
    required this.device,
    required this.user,
    required this.events,
  }) : sentAt = sentAt ?? DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'sent_at': sentAt,
        'environment': environment,
        'app': app.toJson(),
        'device': device.toJson(),
        'user': user.toJson(),
        'events': events,
      };

  factory BatchPayload.fromJson(Map<String, dynamic> json) {
    return BatchPayload(
      schemaVersion: json['schema_version'] as String? ?? currentSchemaVersion,
      sentAt: json['sent_at'] as String?,
      environment: json['environment'] as String,
      app: AppInfo.fromJson(json['app'] as Map<String, dynamic>),
      device: DeviceInfoModel.fromJson(json['device'] as Map<String, dynamic>),
      user: UserInfo.fromJson(json['user'] as Map<String, dynamic>),
      events: (json['events'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
    );
  }
}
