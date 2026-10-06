// lib/models/device_preset.dart

import 'dart:math';

/// Hardware Identity Profile for virtual device spoofing.
class DevicePreset {
  final String id;
  final String displayName;
  final String brand;
  final String manufacturer;
  final String model;
  final String device;
  final String product;
  final String board;
  final String hardware;
  final String fingerprint;

  const DevicePreset({
    required this.id,
    required this.displayName,
    required this.brand,
    required this.manufacturer,
    required this.model,
    required this.device,
    required this.product,
    required this.board,
    required this.hardware,
    required this.fingerprint,
  });

  static const List<DevicePreset> presets = [
    DevicePreset(
      id: 'samsung_s24_ultra',
      displayName: 'Samsung Galaxy S24 Ultra',
      brand: 'samsung',
      manufacturer: 'samsung',
      model: 'SM-S928B',
      device: 'e3q',
      product: 'e3qxxx',
      board: 'e3q',
      hardware: 'qcom',
      fingerprint: 'samsung/e3qxxx/e3q:14/UP1A.231005.007/S928BXXU1AXB5:user/release-keys',
    ),
    DevicePreset(
      id: 'pixel_8_pro',
      displayName: 'Google Pixel 8 Pro',
      brand: 'google',
      manufacturer: 'Google',
      model: 'Pixel 8 Pro',
      device: 'husky',
      product: 'husky',
      board: 'husky',
      hardware: 'zuma',
      fingerprint: 'google/husky/husky:14/UD1A.230803.041/10808477:user/release-keys',
    ),
    DevicePreset(
      id: 'xiaomi_14_pro',
      displayName: 'Xiaomi 14 Pro',
      brand: 'Xiaomi',
      manufacturer: 'Xiaomi',
      model: '23116PN5BC',
      device: 'shennong',
      product: 'shennong',
      board: 'shennong',
      hardware: 'qcom',
      fingerprint: 'Xiaomi/shennong/shennong:14/UKQ1.230804.001/V816.0.4.0.UNBCNXM:user/release-keys',
    ),
    DevicePreset(
      id: 'oneplus_12',
      displayName: 'OnePlus 12',
      brand: 'OnePlus',
      manufacturer: 'OnePlus',
      model: 'CPH2581',
      device: 'OP595DL1',
      product: 'CPH2581',
      board: 'kalama',
      hardware: 'qcom',
      fingerprint: 'OnePlus/CPH2581/OP595DL1:14/UKQ1.230924.001/U.18d6e3c-1-2:user/release-keys',
    ),
  ];

  /// Generates a randomized 16-character hexadecimal Android ID (e.g. 7f3a8b2c4e1d9065).
  static String generateRandomAndroidId() {
    final random = Random.secure();
    final bytes = List<int>.generate(8, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generates a synthetic Advertising ID (UUID v4 format).
  static String generateRandomGaid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant RFC4122
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Generates a valid 15-digit 3GPP IMEI with Luhn checksum digit.
  static String generateRandomImei([String tac = '35848231']) {
    final random = Random.secure();
    final cleanTac = tac.replaceAll(RegExp(r'\D'), '').padRight(8, '0').substring(0, 8);
    final snr = List.generate(6, (_) => random.nextInt(10)).join();
    final body = '$cleanTac$snr';
    var sum = 0;
    for (var i = 0; i < body.length; i++) {
      var d = int.parse(body[i]);
      if (i % 2 == 1) {
        d *= 2;
        if (d > 9) d = (d ~/ 10) + (d % 10);
      }
      sum += d;
    }
    final checkDigit = (10 - (sum % 10)) % 10;
    return '$body$checkDigit';
  }

  /// Generates a synthetic 15-digit IMSI (MCC 310 + MNC 260 + 9-digit MSIN).
  static String generateRandomImsi() {
    final random = Random.secure();
    final msin = List.generate(9, (_) => random.nextInt(10)).join();
    return '310260$msin';
  }

  /// Generates a synthetic locally administered unicast Wi-Fi MAC address.
  static String generateRandomMac() {
    final random = Random.secure();
    final bytes = List<int>.generate(6, (_) => random.nextInt(256));
    bytes[0] = (bytes[0] & 0xFE) | 0x02; // Locally administered, unicast
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');
  }
}

