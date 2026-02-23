/// Device metadata included in every batch.
class DeviceInfoModel {
  final String deviceId;
  final String platform;
  final String osVersion;
  final String model;

  const DeviceInfoModel({
    required this.deviceId,
    required this.platform,
    required this.osVersion,
    required this.model,
  });

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'platform': platform,
        'os_version': osVersion,
        'model': model,
      };

  factory DeviceInfoModel.fromJson(Map<String, dynamic> json) {
    return DeviceInfoModel(
      deviceId: json['device_id'] as String,
      platform: json['platform'] as String,
      osVersion: json['os_version'] as String,
      model: json['model'] as String,
    );
  }
}
