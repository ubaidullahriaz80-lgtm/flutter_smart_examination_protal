import 'package:local_auth/local_auth.dart';

/// Wraps `local_auth` for secondary biometric verification.
class BiometricService {
  BiometricService({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  static final BiometricService instance = BiometricService();

  final LocalAuthentication _localAuth;

  static const _degradeCodes = {
    LocalAuthExceptionCode.noBiometricHardware,
    LocalAuthExceptionCode.noBiometricsEnrolled,
    LocalAuthExceptionCode.noCredentialsSet,
    LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable,
  };

  Future<bool> authenticate({required String reason}) async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!supported || !canCheck) {
        return true;
      }

      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } on LocalAuthException catch (error) {
      return _degradeCodes.contains(error.code);
    }
  }
}
