import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure token storage for JWT sessions.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static final TokenStorage instance = TokenStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'fsep_jwt_token';
  static const _roleKey = 'fsep_user_role';
  static const _userIdKey = 'fsep_user_id';

  Future<void> saveSession({
    required String token,
    required String role,
    required String userId,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _roleKey, value: role);
    await _storage.write(key: _userIdKey, value: userId);
  }

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<String?> readRole() => _storage.read(key: _roleKey);

  Future<String?> readUserId() => _storage.read(key: _userIdKey);

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _userIdKey);
  }
}
