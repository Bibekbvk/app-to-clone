// lib/models/clone_info.dart

import 'dart:convert';

/// Model representing a cloned application instance.
class CloneInfo {
  final int id;
  final String packageName;
  final String? displayName;
  final String installPath;
  final bool isSingleTask;
  final String mode;
  final int createdAt;

  CloneInfo({
    required this.id,
    required this.packageName,
    this.displayName,
    required this.installPath,
    this.isSingleTask = false,
    this.mode = 'standalone',
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  String get effectiveName => displayName?.isNotEmpty == true ? displayName! : packageName;
  bool get isStandalone => mode == 'standalone';
  bool get isSandbox => mode == 'sandbox';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'packageName': packageName,
      'displayName': displayName,
      'installPath': installPath,
      'isSingleTask': isSingleTask,
      'mode': mode,
      'createdAt': createdAt,
    };
  }

  factory CloneInfo.fromMap(Map<dynamic, dynamic> map) {
    return CloneInfo(
      id: (map['id'] as num?)?.toInt() ?? 0,
      packageName: (map['packageName'] as String?) ?? '',
      displayName: map['displayName'] as String?,
      installPath: (map['installPath'] as String?) ?? '',
      isSingleTask: (map['isSingleTask'] as bool?) ?? false,
      mode: (map['mode'] as String?) ?? 'standalone',
      createdAt: (map['createdAt'] as num?)?.toInt(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory CloneInfo.fromJson(String source) =>
      CloneInfo.fromMap(jsonDecode(source) as Map<String, dynamic>);

  CloneInfo copyWith({
    int? id,
    String? packageName,
    String? displayName,
    String? installPath,
    bool? isSingleTask,
    String? mode,
    int? createdAt,
  }) {
    return CloneInfo(
      id: id ?? this.id,
      packageName: packageName ?? this.packageName,
      displayName: displayName ?? this.displayName,
      installPath: installPath ?? this.installPath,
      isSingleTask: isSingleTask ?? this.isSingleTask,
      mode: mode ?? this.mode,
      createdAt: createdAt ?? this.createdAt,
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
