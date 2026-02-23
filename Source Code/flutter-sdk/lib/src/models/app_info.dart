/// App metadata included in every batch.
class AppInfo {
  final String bundleId;
  final String versionName;
  final String buildNumber;

  const AppInfo({
    required this.bundleId,
    required this.versionName,
    required this.buildNumber,
  });

  Map<String, dynamic> toJson() => {
        'bundle_id': bundleId,
        'version_name': versionName,
        'build_number': buildNumber,
      };

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      bundleId: json['bundle_id'] as String,
      versionName: json['version_name'] as String,
      buildNumber: json['build_number'] as String,
    );
  }
}
