// lib/models/clone_info.dart

import 'dart:convert';

/// Model representing a cloned application instance.
class CloneInfo {
  final int id;
  final String packageName;
  final String? displayName;
  /// Optional user-defined profile label (e.g., "Work", "Personal", "Account 2").
  /// This appears as a badge on the clone card so users know which profile is which.
  final String? profileLabel;
  final String installPath;
  final bool isSingleTask;
  final String mode;
  final bool isInstalled;
  final int createdAt;
  final String? deviceModel;
  final String? androidId;
  final String? advertisingId;

  CloneInfo({
    required this.id,
    required this.packageName,
    this.displayName,
    this.profileLabel,
    required this.installPath,
    this.isSingleTask = false,
    this.mode = 'standalone',
    this.isInstalled = false,
    int? createdAt,
    this.deviceModel,
    this.androidId,
    this.advertisingId,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  /// Returns the display name or falls back to the package name.
  String get effectiveName => displayName?.isNotEmpty == true ? displayName! : packageName;

  /// Returns the profile label badge text (e.g., "Work", "Personal", "Slot 1").
  String get effectiveProfileLabel =>
      profileLabel?.isNotEmpty == true ? profileLabel! : 'Profile ${id.toString().padLeft(2, '0')}';

  bool get isStandalone => mode == 'standalone';
  bool get isSandbox => mode == 'sandbox';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageName': packageName,
      'displayName': displayName,
      'profileLabel': profileLabel,
      'installPath': installPath,
      'isSingleTask': isSingleTask,
      'mode': mode,
      'isInstalled': isInstalled,
      'createdAt': createdAt,
      'deviceModel': deviceModel,
      'androidId': androidId,
      'advertisingId': advertisingId,
    };
  }

  factory CloneInfo.fromMap(Map<dynamic, dynamic> map) {
    return CloneInfo(
      id: (map['id'] as num?)?.toInt() ?? 0,
      packageName: (map['packageName'] as String?) ?? '',
      displayName: map['displayName'] as String?,
      profileLabel: map['profileLabel'] as String?,
      installPath: (map['installPath'] as String?) ?? '',
      isSingleTask: (map['isSingleTask'] as bool?) ?? false,
      mode: (map['mode'] as String?) ?? 'standalone',
      isInstalled: (map['isInstalled'] as bool?) ?? false,
      createdAt: (map['createdAt'] as num?)?.toInt(),
      deviceModel: map['deviceModel'] as String?,
      androidId: map['androidId'] as String?,
      advertisingId: map['advertisingId'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory CloneInfo.fromJson(String source) =>
      CloneInfo.fromMap(jsonDecode(source) as Map<String, dynamic>);

  CloneInfo copyWith({
    int? id,
    String? packageName,
    String? displayName,
    String? profileLabel,
    String? installPath,
    bool? isSingleTask,
    String? mode,
    bool? isInstalled,
    int? createdAt,
    String? deviceModel,
    String? androidId,
    String? advertisingId,
  }) {
    return CloneInfo(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      displayName: displayName ?? this.displayName,
      profileLabel: profileLabel ?? this.profileLabel,
      installPath: installPath ?? this.installPath,
      isSingleTask: isSingleTask ?? this.isSingleTask,
      mode: mode ?? this.mode,
      isInstalled: isInstalled ?? this.isInstalled,
      createdAt: createdAt ?? this.createdAt,
      deviceModel: deviceModel ?? this.deviceModel,
      androidId: androidId ?? this.androidId,
      advertisingId: advertisingId ?? this.advertisingId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloneInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          packageName == other.packageName;

  @override
  int get hashCode => id.hashCode ^ packageName.hashCode;
}
