import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/network/api_client.dart';
import 'package:fsep/core/network/api_exception.dart';
import 'package:fsep/core/network/token_storage.dart';
import 'package:fsep/data/models/user_model.dart';
import 'package:fsep/data/repositories/auth_repository.dart';

/// Fakes Dio at the HTTP-transport layer only — the real ApiClient/Dio
/// pipeline (interceptors, error handling) still runs, just without a real
/// network call. This is the "HTTP-layer mock" allowed in automated tests.
class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);
}

/// In-memory TokenStorage double so the test doesn't touch the real
/// flutter_secure_storage platform channel.
class _InMemoryTokenStorage extends TokenStorage {
  String? token;
  String? role;
  String? userId;

  @override
  Future<void> saveSession({
    required String token,
    required String role,
    required String userId,
  }) async {
    this.token = token;
    this.role = role;
    this.userId = userId;
  }

  @override
  Future<String?> readToken() async => token;

  @override
  Future<String?> readRole() async => role;

  @override
  Future<String?> readUserId() async => userId;

  @override
  Future<void> clearSession() async {
    token = null;
    role = null;
    userId = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter originalAdapter;

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  test(
    'login calls POST /auth/login, persists the session, and returns a UserModel',
    () async {
      ApiClient.instance.dio.httpClientAdapter =
          _FakeHttpClientAdapter((options) async {
        expect(options.path, '/auth/login');
        expect(options.method, 'POST');

        final body = jsonEncode({
          'jwt_token': 'fake.token.value',
          'role': 'candidate',
          'user_id': 'user-123',
        });
        return ResponseBody.fromString(
          body,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final storage = _InMemoryTokenStorage();
      final repository = AuthRepository(tokenStorage: storage);

      final user = await repository.login(
        email: 'a@b.com',
        password: 'secret',
      );

      expect(user.id, 'user-123');
      expect(user.role, UserRole.candidate);
      expect(storage.token, 'fake.token.value');
      expect(storage.role, 'candidate');
      expect(storage.userId, 'user-123');
    },
  );

  test('login throws ApiException on a server error response', () async {
    ApiClient.instance.dio.httpClientAdapter =
        _FakeHttpClientAdapter((options) async {
      return ResponseBody.fromString(
        jsonEncode({'message': 'Invalid credentials'}),
        401,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    });

    final repository = AuthRepository(tokenStorage: _InMemoryTokenStorage());

    await expectLater(
      () => repository.login(email: 'a@b.com', password: 'wrong'),
      throwsA(isA<ApiException>()),
    );
  });

  test('restoreSession returns null when nothing is stored', () async {
    final repository = AuthRepository(tokenStorage: _InMemoryTokenStorage());

    final user = await repository.restoreSession();

    expect(user, isNull);
  });
}
