import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/network/api_client.dart';
import 'package:fsep/data/repositories/notification_repository.dart';

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions options, dynamic requestStream, dynamic cancelFuture) => handler(options);
}

void main() {
  late HttpClientAdapter originalAdapter;
  late NotificationRepository repository;

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    repository = NotificationRepository();
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  test('registerToken sends correct payload', () async {
    var wasCalled = false;
    ApiClient.instance.dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
      wasCalled = true;
      expect(options.path, '/device-tokens');
      expect(options.method, 'POST');
      expect(options.data['token'], 'test-fcm-token');
      return ResponseBody.fromString(
        jsonEncode({'message': 'ok'}),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    await repository.registerToken('test-fcm-token');
    expect(wasCalled, isTrue);
  });

  test('unregisterToken sends correct payload', () async {
    var wasCalled = false;
    ApiClient.instance.dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
      wasCalled = true;
      expect(options.path, '/device-tokens');
      expect(options.method, 'DELETE');
      expect(options.data['token'], 'test-fcm-token');
      return ResponseBody.fromString('', 204);
    });

    await repository.unregisterToken('test-fcm-token');
    expect(wasCalled, isTrue);
  });
}
