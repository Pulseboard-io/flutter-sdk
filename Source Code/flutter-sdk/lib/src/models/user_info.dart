/// User identity included in every batch.
class UserInfo {
  final String anonymousId;
  final String? userId;

  const UserInfo({
    required this.anonymousId,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'anonymous_id': anonymousId,
    };
    if (userId != null) json['user_id'] = userId;
    return json;
  }

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      anonymousId: json['anonymous_id'] as String,
      userId: json['user_id'] as String?,
    );
  }

  UserInfo copyWith({String? anonymousId, String? userId}) {
    return UserInfo(
      anonymousId: anonymousId ?? this.anonymousId,
      userId: userId ?? this.userId,
    );
  }
}
