import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/kiosk/kiosk_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.fsep.app/kiosk');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('enterKioskMode invokes the native channel method', () async {
    final result = await KioskService.enterKioskMode();

    expect(result, isTrue);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'enterKioskMode');
  });

  test('exitKioskMode invokes the native channel method', () async {
    await KioskService.exitKioskMode();

    expect(calls.single.method, 'exitKioskMode');
  });

  test('isKioskModeActive invokes the native channel method', () async {
    await KioskService.isKioskModeActive();

    expect(calls.single.method, 'isKioskModeActive');
  });

  test('enterKioskMode invokes the native channel method on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final result = await KioskService.enterKioskMode();

    expect(result, isTrue);
    expect(calls.single.method, 'enterKioskMode');
  });

  test('throws UnsupportedError on an unsupported platform (iOS)', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    expect(KioskService.enterKioskMode, throwsUnsupportedError);
    expect(calls, isEmpty);
  });
}
