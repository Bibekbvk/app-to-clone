// lib/providers/clone_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../clone_app.dart';

const String _kPrefsClonesKey = 'app_multiplicator_clones_cache';
const String _kPrefsThemeKey = 'app_multiplicator_theme_mode';

// -----------------------------------------------------------------------------
// Theme Provider (Light / Dark / System with persistent storage)
// -----------------------------------------------------------------------------
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _loadFromPrefs();
    return ThemeMode.system;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_kPrefsThemeKey);
      if (modeStr == 'dark') {
        state = ThemeMode.dark;
      } else if (modeStr == 'light') {
        state = ThemeMode.light;
      } else {
        state = ThemeMode.system;
      }
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsThemeKey, next == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsThemeKey, mode.name);
    } catch (_) {}
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// -----------------------------------------------------------------------------
// Installed Apps Provider
// -----------------------------------------------------------------------------
final installedAppsProvider = FutureProvider<List<AppInfo>>((ref) async {
  final apps = await CloneApp.listInstalledApps();
  if (apps.isNotEmpty) {
    return apps;
  }
  // Provide sample fallback apps for testing/emulators without full Play Services
  return [
    const AppInfo(
      packageName: 'com.paypal.android.p2pmobile',
      appName: 'PayPal',
      versionCode: 85200,
      versionName: '8.52.0',
    ),
    const AppInfo(
      packageName: 'com.whatsapp',
      appName: 'WhatsApp Messenger',
      versionCode: 22409,
      versionName: '2.24.9',
    ),
    const AppInfo(
      packageName: 'com.facebook.katana',
      appName: 'Facebook',
      versionCode: 42001,
      versionName: '420.0.1',
    ),
    const AppInfo(
      packageName: 'com.instagram.android',
      appName: 'Instagram',
      versionCode: 31500,
      versionName: '315.0.0',
    ),
    const AppInfo(
      packageName: 'org.telegram.messenger',
      appName: 'Telegram',
      versionCode: 10800,
      versionName: '10.8.0',
    ),
    const AppInfo(
      packageName: 'com.twitter.android',
      appName: 'X (Twitter)',
      versionCode: 10300,
      versionName: '10.3.0',
    ),
    const AppInfo(
      packageName: 'com.spotify.music',
      appName: 'Spotify',
      versionCode: 89000,
      versionName: '8.9.0',
    ),
  ];
});

// -----------------------------------------------------------------------------
// Clones State Notifier
// -----------------------------------------------------------------------------
class CloneListNotifier extends AsyncNotifier<List<CloneInfo>> {
  @override
  Future<List<CloneInfo>> build() async {
    return _fetchClones();
  }

  Future<List<CloneInfo>> _fetchClones() async {
    try {
      final nativeClones = await CloneApp.listClones();
      if (nativeClones.isNotEmpty) {
        await _saveToPrefs(nativeClones);
        return nativeClones;
      }
    } catch (_) {}

    // Fallback / sync from persistent SharedPreferences
    return _loadFromPrefs();
  }

  Future<void> refreshClones() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchClones());
  }

  Future<int> createClone({
    required String packageName,
    String? displayName,
    bool isSingleTask = false,
    bool silentInstall = false,
    bool keepDataIsolated = true,
    bool pinToDesktop = false,
    String mode = 'standalone',
  }) async {
    int newId = -1;
    try {
      newId = await CloneApp.createClone(
        packageName: packageName,
        displayName: displayName,
        isSingleTask: isSingleTask,
        silentInstall: silentInstall,
        keepDataIsolated: keepDataIsolated,
        mode: mode,
      );
    } catch (_) {
      // Fallback ID generation if running without native host
      final current = state.value ?? [];
      newId = (current.map((e) => e.id).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
    }

    final newClone = CloneInfo(
      id: newId > 0 ? newId : 1,
      packageName: packageName,
      displayName: displayName,
      installPath: '/data/user/0/com.virtual.clone_app_flutter/files/clones/$newId/base.apk',
      isSingleTask: isSingleTask,
      mode: mode,
    );

    final current = state.value ?? [];
    final updated = [...current.where((c) => c.id != newClone.id), newClone];
    await _saveToPrefs(updated);
    state = AsyncValue.data(updated);

    if (pinToDesktop && newClone.id > 0) {
      try {
        await CloneApp.pinToHomeScreen(newClone.id);
      } catch (_) {}
    }

    return newClone.id;
  }

  Future<void> launchClone(int cloneId, {bool isSingleTask = false}) async {
    await CloneApp.launchClone(cloneId, isSingleTask: isSingleTask);
  }

  Future<bool> pinToHomeScreen(int cloneId) async {
    return await CloneApp.pinToHomeScreen(cloneId);
  }

  Future<bool> installStandaloneApk(int cloneId) async {
    return await CloneApp.installStandaloneApk(cloneId);
  }

  Future<String?> exportStandaloneApk(int cloneId) async {
    return await CloneApp.exportStandaloneApk(cloneId);
  }

  Future<void> deleteClone(int cloneId) async {
    try {
      await CloneApp.deleteClone(cloneId);
    } catch (_) {}

    final current = state.value ?? [];
    final updated = current.where((c) => c.id != cloneId).toList();
    await _saveToPrefs(updated);
    state = AsyncValue.data(updated);
  }

  Future<void> openSettings(int cloneId, String packageName) async {
    await CloneApp.openAppSettings(cloneId, packageName);
  }

  Future<List<CloneInfo>> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = prefs.getStringList(_kPrefsClonesKey);
      if (listJson != null) {
        return listJson.map((str) => CloneInfo.fromJson(str)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveToPrefs(List<CloneInfo> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final listJson = list.map((c) => c.toJson()).toList();
      await prefs.setStringList(_kPrefsClonesKey, listJson);
    } catch (_) {}
  }
}

final cloneListProvider = AsyncNotifierProvider<CloneListNotifier, List<CloneInfo>>(
  CloneListNotifier.new,
);

// Backward-compatible alias for existing consumers
final cloneProvider = cloneListProvider;

// -----------------------------------------------------------------------------
// UI Control Providers for Batch Clone Sheet
// -----------------------------------------------------------------------------
class CloneCountNotifier extends Notifier<int> {
  @override
  int build() => 1;
  void set(int value) => state = value.clamp(1, 25);
}

final cloneCountProvider = NotifierProvider<CloneCountNotifier, int>(
  CloneCountNotifier.new,
);

class SilentInstallNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle(bool val) => state = val;
}

final silentInstallProvider = NotifierProvider<SilentInstallNotifier, bool>(
  SilentInstallNotifier.new,
);

class KeepDataIsolatedNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle(bool val) => state = val;
}

final keepDataIsolatedProvider = NotifierProvider<KeepDataIsolatedNotifier, bool>(
  KeepDataIsolatedNotifier.new,
);

class SingleTaskModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle(bool val) => state = val;
}

final singleTaskModeProvider = NotifierProvider<SingleTaskModeNotifier, bool>(
  SingleTaskModeNotifier.new,
);

class AutoPinToDesktopNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle(bool val) => state = val;
}

final autoPinToDesktopProvider = NotifierProvider<AutoPinToDesktopNotifier, bool>(
  AutoPinToDesktopNotifier.new,
);

enum CloneMode { standalone, sandbox }

class CloneModeNotifier extends Notifier<CloneMode> {
  @override
  CloneMode build() => CloneMode.standalone; // Default to standalone for 100% zero-bleed isolation
  void setMode(CloneMode mode) => state = mode;
  void toggle() => state = state == CloneMode.standalone ? CloneMode.sandbox : CloneMode.standalone;
}

final cloneModeProvider = NotifierProvider<CloneModeNotifier, CloneMode>(
  CloneModeNotifier.new,
);

// -----------------------------------------------------------------------------
// Real-time EventChannel Progress Stream Provider
// -----------------------------------------------------------------------------
final cloneProgressStreamProvider = StreamProvider.autoDispose<String>((ref) {
  return CloneApp.progressStream;
});
