import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Generates and persists the local database passphrase using secure storage.
class DatabaseKeyStorage {
  DatabaseKeyStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static final DatabaseKeyStorage instance = DatabaseKeyStorage();

  final FlutterSecureStorage _storage;

  static const _keyStorageKey = 'fsep_local_db_key';

  String _generateKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: _keyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated = _generateKey();
    await _storage.write(key: _keyStorageKey, value: generated);
    return generated;
  }
}
