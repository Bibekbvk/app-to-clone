// test/clone_app_test.dart

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clone_app_flutter/clone_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('com.virtual.clone_app/methods');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'createClone':
          // Returns generated clone ID
          final args = methodCall.arguments as Map?;
          final pkg = args?['packageName'] as String?;
          if (pkg == 'com.invalid') {
            return -1;
          }
          return 42;

        case 'launchClone':
          return null;

        case 'listClones':
          return [
            {
              'id': 1,
              'packageName': 'com.whatsapp',
              'displayName': 'WhatsApp Work',
              'installPath': '/data/user/0/com.virtual.host/files/clones/1/base.apk',
              'isSingleTask': false,
              'createdAt': 1710000000000,
            },
            {
              'id': 2,
              'packageName': 'com.instagram.android',
              'displayName': 'Instagram Alt',
              'installPath': '/data/user/0/com.virtual.host/files/clones/2/base.apk',
              'isSingleTask': true,
              'createdAt': 1710000050000,
            }
          ];

        case 'deleteClone':
          return null;

        case 'openAppSettings':
          return null;

        case 'pinToHomeScreen':
          return true;

        case 'installStandaloneApk':
          return true;

        case 'exportStandaloneApk':
          return '/sdcard/Download/com.whatsapp.c01_signed.apk';

        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('CloneApp MethodChannel Tests', () {
    test('createClone invokes native method and returns integer clone ID', () async {
      final cloneId = await CloneApp.createClone(
        packageName: 'com.whatsapp',
        displayName: 'Work WhatsApp',
        isSingleTask: true,
      );

      expect(cloneId, equals(42));
      expect(log, hasLength(1));
      expect(log.first.method, equals('createClone'));
      expect(log.first.arguments['packageName'], equals('com.whatsapp'));
      expect(log.first.arguments['displayName'], equals('Work WhatsApp'));
      expect(log.first.arguments['isSingleTask'], isTrue);
    });

    test('listClones parses clone metadata correctly into CloneInfo models', () async {
      final clones = await CloneApp.listClones();

      expect(clones, hasLength(2));
      expect(clones.first.id, equals(1));
      expect(clones.first.packageName, equals('com.whatsapp'));
      expect(clones.first.displayName, equals('WhatsApp Work'));
      expect(clones.first.effectiveName, equals('WhatsApp Work'));
      expect(clones.first.installPath, contains('/files/clones/1'));
      expect(clones.first.isSingleTask, isFalse);

      expect(clones[1].id, equals(2));
      expect(clones[1].isSingleTask, isTrue);
    });

    test('launchClone invokes launchClone on native method channel', () async {
      await CloneApp.launchClone(42, isSingleTask: true);

      expect(log, hasLength(1));
      expect(log.first.method, equals('launchClone'));
      expect(log.first.arguments['cloneId'], equals(42));
      expect(log.first.arguments['isSingleTask'], isTrue);
    });

    test('deleteClone invokes deleteClone on native method channel', () async {
      await CloneApp.deleteClone(42);

      expect(log, hasLength(1));
      expect(log.first.method, equals('deleteClone'));
      expect(log.first.arguments['cloneId'], equals(42));
    });

    test('createClone passes mode parameter correctly to native channel', () async {
      final cloneId = await CloneApp.createClone(
        packageName: 'com.whatsapp',
        displayName: 'Standalone WhatsApp',
        isSingleTask: false,
        mode: 'standalone',
      );

      expect(cloneId, equals(42));
      expect(log.last.arguments['mode'], equals('standalone'));
    });

    test('installStandaloneApk invokes native installStandaloneApk method', () async {
      final success = await CloneApp.installStandaloneApk(42);

      expect(success, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, equals('installStandaloneApk'));
      expect(log.first.arguments['cloneId'], equals(42));
    });

    test('exportStandaloneApk invokes native exportStandaloneApk and returns path', () async {
      final exportPath = await CloneApp.exportStandaloneApk(42);

      expect(exportPath, equals('/sdcard/Download/com.whatsapp.c01_signed.apk'));
      expect(log, hasLength(1));
      expect(log.first.method, equals('exportStandaloneApk'));
      expect(log.first.arguments['cloneId'], equals(42));
    });

    test('pinToHomeScreen invokes pinToHomeScreen and returns success boolean', () async {
      final success = await CloneApp.pinToHomeScreen(42);

      expect(success, isTrue);
      expect(log, hasLength(1));
      expect(log.first.method, equals('pinToHomeScreen'));
      expect(log.first.arguments['cloneId'], equals(42));
    });

    test('CloneInfo correctly identifies standalone vs sandbox mode', () {
      final standaloneClone = CloneInfo(
        id: 1,
        packageName: 'com.whatsapp',
        installPath: '/path/base.apk',
        mode: 'standalone',
      );
      expect(standaloneClone.isStandalone, isTrue);
      expect(standaloneClone.isSandbox, isFalse);

      final sandboxClone = CloneInfo(
        id: 2,
        packageName: 'com.facebook.katana',
        installPath: '/path/base.apk',
        mode: 'sandbox',
      );
      expect(sandboxClone.isStandalone, isFalse);
      expect(sandboxClone.isSandbox, isTrue);
    });
  });
}
