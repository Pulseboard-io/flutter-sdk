import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_info.dart';
import '../models/device_info_model.dart';
import '../utils/id_generator.dart';

/// Provides cached device and app information.
class DeviceInfoProvider {
  DeviceInfoModel? _deviceInfo;
  AppInfo? _appInfo;

  final DeviceInfoPlugin _deviceInfoPlugin;

  DeviceInfoProvider({DeviceInfoPlugin? deviceInfoPlugin})
      : _deviceInfoPlugin = deviceInfoPlugin ?? DeviceInfoPlugin();

  /// Get cached device info, fetching once if needed.
  Future<DeviceInfoModel> getDeviceInfo() async {
    if (_deviceInfo != null) return _deviceInfo!;

    String deviceId;
    String platform;
    String osVersion;
    String model;

    if (Platform.isAndroid) {
      final info = await _deviceInfoPlugin.androidInfo;
      deviceId = info.id;
      platform = 'android';
      osVersion = info.version.release;
      model = '${info.manufacturer} ${info.model}';
    } else if (Platform.isIOS) {
      final info = await _deviceInfoPlugin.iosInfo;
      deviceId = info.identifierForVendor ?? IdGenerator.uuid();
      platform = 'ios';
      osVersion = info.systemVersion;
      model = info.utsname.machine;
    } else {
      deviceId = IdGenerator.uuid();
      platform = 'android'; // API only accepts android/ios
      osVersion = Platform.operatingSystemVersion;
      model = 'unknown';
    }

    _deviceInfo = DeviceInfoModel(
      deviceId: deviceId,
      platform: platform,
      osVersion: osVersion,
      model: model,
    );

    return _deviceInfo!;
  }

  /// Get cached app info, fetching once if needed.
  Future<AppInfo> getAppInfo() async {
    if (_appInfo != null) return _appInfo!;

    final info = await PackageInfo.fromPlatform();
    _appInfo = AppInfo(
      bundleId: info.packageName,
      versionName: info.version,
      buildNumber: info.buildNumber,
    );

    return _appInfo!;
  }

  /// Clear cached info (useful for testing).
  void clearCache() {
    _deviceInfo = null;
    _appInfo = null;
  }
}
