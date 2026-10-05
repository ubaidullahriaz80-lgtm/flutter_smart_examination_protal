import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/database/database_key_storage.dart';
import 'package:fsep/core/database/local_database_service.dart';
import 'package:fsep/core/network/api_client.dart';
import 'package:fsep/data/repositories/exam_session_repository.dart';
import 'package:fsep/data/repositories/local_behavior_event_repository.dart';

class _FixedKeyStorage extends DatabaseKeyStorage {
  _FixedKeyStorage(this.key);
  final String key;
  @override
  Future<String> getOrCreateKey() async => key;
}

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
  late Directory tempDir;
  late LocalDatabaseService dbService;
  late LocalBehaviorEventRepository localBcd;
  late ExamSessionRepository repository;

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    tempDir = Directory.systemTemp.createTempSync('fsep_bcd_offline_test_');
    dbService = LocalDatabaseService(
      keyStorage: _FixedKeyStorage('f'.padRight(64, 'f')),
      testDbPath: '${tempDir.path}/test.db',
    );
    localBcd = LocalBehaviorEventRepository(databaseService: dbService);
    repository = ExamSessionRepository(
      localBehaviorEvents: localBcd,
    );
  });

  tearDown(() async {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    await dbService.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('ONLINE — recordBehaviorEvent still uses the backend', () async {
    ApiClient.instance.dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
      return ResponseBody.fromString(
        jsonEncode({
          'suspicion_score': 10,
          'suspicion_status': 'normal',
          'event': {
            'event_type': 'focus_lost',
            'suspicion_points': 10,
            'occurred_at': DateTime.now().toIso8601String(),
          }
        }),
        201,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    final summary = await repository.recordBehaviorEvent(
      sessionId: 100,
      eventType: 'focus_lost',
    );

    expect(summary.score, 10);
    // Locally should remain empty.
    expect(await localBcd.getEventsForSession(100), isEmpty);
  });

  test('OFFLINE — recordBehaviorEvent persists locally on failure', () async {
    ApiClient.instance.dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });

    await expectLater(
      () => repository.recordBehaviorEvent(sessionId: 100, eventType: 'focus_lost'),
      throwsA(anything),
    );

    final localEvents = await localBcd.getEventsForSession(100);
    expect(localEvents, hasLength(1));
    expect(localEvents.first.eventType, 'focus_lost');
    expect(localEvents.first.sessionId, 100);
  });
}
