import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Wraps native platform channel for fullscreen kiosk lockdown.
class KioskService {
  KioskService._();

  static const MethodChannel _channel = MethodChannel('com.fsep.app/kiosk');

  static bool get isSupportedOnThisPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.android);

  static Future<bool> enterKioskMode() => _invoke('enterKioskMode');

  static Future<bool> exitKioskMode() => _invoke('exitKioskMode');

  static Future<bool> isKioskModeActive() => _invoke('isKioskModeActive');

  static Future<bool> _invoke(String method) async {
    if (!isSupportedOnThisPlatform) {
      throw UnsupportedError(
        'KioskService.$method is only supported on Windows and Android.',
      );
    }
    final result = await _channel.invokeMethod<bool>(method);
    return result ?? false;
  }
}
