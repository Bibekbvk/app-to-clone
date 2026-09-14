// lib/models/app_info.dart

import 'dart:convert';
import 'dart:typed_data';

/// Represents an installed application on the host device.
class AppInfo {
  final String packageName;
  final String appName;
  final int versionCode;
  final String? versionName;
  final Uint8List? iconBytes;
  final bool isSystemApp;
  final String? sourceDir;

  const AppInfo({
    required this.packageName,
    required this.appName,
    required this.versionCode,
    this.versionName,
    this.iconBytes,
    this.isSystemApp = false,
    this.sourceDir,
  });

  factory AppInfo.fromMap(Map<dynamic, dynamic> map) {
    Uint8List? icon;
    final iconData = map['iconBase64'];
    if (iconData is String && iconData.isNotEmpty) {
      try {
        icon = base64Decode(iconData);
      } catch (_) {
        icon = null;
      }
    } else if (map['iconBytes'] is Uint8List) {
      icon = map['iconBytes'] as Uint8List;
    }

    return AppInfo(
      packageName: (map['packageName'] as String?) ?? '',
      appName: (map['appName'] as String?) ?? (map['packageName'] as String? ?? 'Unknown'),
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
      versionName: map['versionName'] as String?,
      iconBytes: icon,
      isSystemApp: (map['isSystemApp'] as bool?) ?? false,
      sourceDir: map['sourceDir'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'packageName': packageName,
      'appName': appName,
      'versionCode': versionCode,
      'versionName': versionName,
      'iconBase64': iconBytes != null ? base64Encode(iconBytes!) : null,
      'isSystemApp': isSystemApp,
      'sourceDir': sourceDir,
    };
  }
}
