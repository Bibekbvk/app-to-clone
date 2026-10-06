// lib/clone_app.dart

import 'dart:async';
import 'package:flutter/services.dart';
import 'models/clone_info.dart';
import 'models/app_info.dart';

export 'models/clone_info.dart';
export 'models/app_info.dart';

/// Flutter Bridge plugin for interacting with the Android Multi-Instance
/// Virtual Runtime Engine over Method and Event Channels.
class CloneApp {
  static const MethodChannel _methodsChannel =
      MethodChannel('com.virtual.clone_app/methods');
  static const MethodChannel _appsChannel =
      MethodChannel('com.virtual.clone_app/apps');
  static const EventChannel _progressChannel =
      EventChannel('com.virtual.clone_app/progress');

  /// Creates a new isolated clone instance of the target package.
  /// Generates a new clone ID, allocates a dedicated stub activity,
  /// copies the base APK to isolated container storage, and updates the manifest.
  /// Creates a new isolated clone instance of the target package.
  /// Mode can be 'standalone' (mutated package & 100% UID isolation) or 'sandbox' (in-process worker).
  static Future<int> createClone({
    required String packageName,
    String? displayName,
    String? profileLabel,
    bool isSingleTask = false,
    bool silentInstall = false,
    bool keepDataIsolated = true,
    String mode = 'standalone',
    String? devicePreset,
    String? androidId,
  }) async {
    final result = await _methodsChannel.invokeMethod<dynamic>('createClone', {
      'packageName': packageName,
      'displayName': displayName,
      'profileLabel': profileLabel,
      'isSingleTask': isSingleTask,
      'silentInstall': silentInstall,
      'keepDataIsolated': keepDataIsolated,
      'mode': mode,
      'devicePreset': devicePreset,
      'androidId': androidId,
    });
    if (result is num) {
      return result.toInt();
    }
    return -1;
  }

  /// Launches the designated clone instance into its isolated worker sub-process.
  static Future<void> launchClone(int cloneId, {bool isSingleTask = false}) async {
    await _methodsChannel.invokeMethod('launchClone', {
      'cloneId': cloneId,
      'isSingleTask': isSingleTask,
    });
  }

  /// Lists all registered clones and their container metadata.
  static Future<List<CloneInfo>> listClones() async {
    final dynamic raw = await _methodsChannel.invokeMethod('listClones');
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((item) => CloneInfo.fromMap(item))
          .toList();
    }
    return [];
  }

  /// Removes the specified clone instance, its virtual file sandbox, and manifest entries.
  static Future<void> deleteClone(int cloneId) async {
    await _methodsChannel.invokeMethod('deleteClone', {
      'cloneId': cloneId,
    });
  }

  /// Lists installed applications on the Android host device.
  static Future<List<AppInfo>> listInstalledApps() async {
    try {
      final dynamic raw = await _appsChannel.invokeMethod('listInstalledApps');
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((item) => AppInfo.fromMap(item))
            .toList();
      }
    } catch (_) {
      // Fallback if apps channel is invoked via methods channel
      try {
        final dynamic fallback = await _methodsChannel.invokeMethod('listInstalledApps');
        if (fallback is List) {
          return fallback
              .whereType<Map>()
              .map((item) => AppInfo.fromMap(item))
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }

  /// Fetches base64 encoded app icon for a specific package on demand.
  static Future<String?> getAppIcon(String packageName) async {
    try {
      final result = await _methodsChannel.invokeMethod<String>('getAppIcon', {
        'packageName': packageName,
      });
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Opens application settings or virtual details for a cloned or target package.
  static Future<void> openAppSettings(int cloneId, String packageName) async {
    await _methodsChannel.invokeMethod('openAppSettings', {
      'cloneId': cloneId,
      'packageName': packageName,
    });
  }

  /// Requests the Android OS to pin a standalone launcher shortcut for this clone to the phone's Home Screen / Desktop.
  static Future<bool> pinToHomeScreen(int cloneId) async {
    try {
      final dynamic result = await _methodsChannel.invokeMethod('pinToHomeScreen', {
        'cloneId': cloneId,
      });
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Prompts Android Native PackageInstaller to install the standalone mutated clone APK.
  static Future<bool> installStandaloneApk(int cloneId) async {
    try {
      final dynamic result = await _methodsChannel.invokeMethod('installStandaloneApk', {
        'cloneId': cloneId,
      });
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Exports the standalone clone APK to the public Downloads folder.
  static Future<String?> exportStandaloneApk(int cloneId) async {
    try {
      final dynamic result = await _methodsChannel.invokeMethod('exportStandaloneApk', {
        'cloneId': cloneId,
      });
      return result as String?;
    } catch (_) {
      return null;
    }
  }

  /// Stream of real-time progress events from the EventChannel during batch operations.
  /// Formatted as "stage_index:status_message" (e.g., "0:Extracting APK...").
  static Stream<String> get progressStream {
    return _progressChannel
        .receiveBroadcastStream()
        .map((event) => event.toString());
  }
}
