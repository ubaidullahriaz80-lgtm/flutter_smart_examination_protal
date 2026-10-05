import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/database/database_key_storage.dart';
import 'package:fsep/core/database/local_database_service.dart';
import 'package:fsep/core/network/api_client.dart';
import 'package:fsep/core/network/api_exception.dart';
import 'package:fsep/data/repositories/exam_session_repository.dart';
import 'package:fsep/data/repositories/local_session_repository.dart';
import 'package:fsep/data/repositories/pending_answer_repository.dart';

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
  late LocalSessionRepository localSessions;
  late PendingAnswerRepository pendingAnswers;
  late ExamSessionRepository repository;

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    tempDir = Directory.systemTemp.createTempSync('fsep_exam_session_offline_test_');
    dbService = LocalDatabaseService(
      keyStorage: _FixedKeyStorage('f'.padRight(64, 'f')),
      testDbPath: '${tempDir.path}/test.db',
    );
    localSessions = LocalSessionRepository(databaseService: dbService);
    pendingAnswers = PendingAnswerRepository(databaseService: dbService);
    repository = ExamSessionRepository(
      localSessionRepository: localSessions,
      pendingAnswerRepository: pendingAnswers,
    );
  });

  tearDown(() async {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    await dbService.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('Test A — Online session successfully caches locally', () async {
    final now = DateTime.now().toIso8601String();
    ApiClient.instance.dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
      return ResponseBody.fromString(
        jsonEncode({
          'session': {
            'id': 100,
            'exam_id': 1,
            'status': 'in_progress',
            'started_at': now,
            'expires_at': now,
            'server_time': now,
            'answers': [],
          }
        }),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    await repository.startOrResumeSession(1);

    final cached = await localSessions.getSessionByExamId(1);
    expect(cached, isNotNull);
    expect(cached!.serverSessionId, 100);
    expect(cached.examId, 1);
  });

  test('Test B — Network failure with an existing local session returns the cached session', () async {
    final now = DateTime.now();
    await localSessions.saveSession(
      serverSessionId: 100,
      examId: 1,
      status: 'in_progress',
      startedAt: now,
      expiresAt: now.add(const Duration(hours: 1)),
    );
    await pendingAnswers.savePendingAnswer(sessionId: 100, questionId: 11, selectedOption: 'C');

    // Simulate network error (ApiException with null statusCode)
    ApiClient.instance.dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
      throw DioException(
        requestOptions: options,
        error: 'Network failure',
        type: DioExceptionType.connectionTimeout,
      );
    });

    final session = await repository.startOrResumeSession(1);

    expect(session.id, 100);
    expect(session.answers[11], 'C');
  });

  test('Test C — Network failure without a cached session preserves the original error', () async {
    ApiClient.instance.dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
      throw DioException(
        requestOptions: options,
        error: 'Network failure',
        type: DioExceptionType.connectionError,
      );
    });

    await expectLater(
      () => repository.startOrResumeSession(1),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', isNull)),
    );
  });

  test('Test D — Cached session for a different exam is not returned', () async {
    final now = DateTime.now();
    await localSessions.saveSession(
      serverSessionId: 100,
      examId: 2, // Different exam
      status: 'in_progress',
      startedAt: now,
    );

    ApiClient.instance.dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });

    await expectLater(
      () => repository.startOrResumeSession(1),
      throwsA(isA<ApiException>()),
    );
  });

  test('Test E — Existing successful online start/resume behavior still works', () async {
    final now = DateTime.now().toIso8601String();
    ApiClient.instance.dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
      return ResponseBody.fromString(
        jsonEncode({
          'session': {
            'id': 200,
            'exam_id': 1,
            'status': 'in_progress',
            'started_at': now,
            'expires_at': now,
            'server_time': now,
            'answers': [{'question_id': 5, 'selected_option': 'A'}],
          }
        }),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    final session = await repository.startOrResumeSession(1);
    expect(session.id, 200);
    expect(session.answers[5], 'A');
  });

  test('Test F — Server-side HTTP errors are not incorrectly converted into offline fallbacks', () async {
    // Even if a local session exists...
    await localSessions.saveSession(
      serverSessionId: 100,
      examId: 1,
      status: 'in_progress',
      startedAt: DateTime.now(),
    );

    // ...a 403 Forbidden must still be rethrown, not hidden by a fallback.
    ApiClient.instance.dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
      return ResponseBody.fromString(
        jsonEncode({'message': 'Unauthorized'}),
        403,
      );
    });

    await expectLater(
      () => repository.startOrResumeSession(1),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403)),
    );
  });
}
