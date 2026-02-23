/// A breadcrumb entry for crash context.
class Breadcrumb {
  final String ts;
  final String type;
  final String message;

  Breadcrumb({
    String? ts,
    required this.type,
    required this.message,
  }) : ts = ts ?? DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> toJson() => {
        'ts': ts,
        'type': type,
        'message': message,
      };

  factory Breadcrumb.fromJson(Map<String, dynamic> json) {
    return Breadcrumb(
      ts: json['ts'] as String?,
      type: json['type'] as String,
      message: json['message'] as String,
    );
  }
}
