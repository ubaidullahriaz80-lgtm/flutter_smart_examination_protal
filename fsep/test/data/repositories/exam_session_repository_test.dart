import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/database/database_key_storage.dart';
import 'package:fsep/core/database/local_database_service.dart';
import 'package:fsep/core/network/api_client.dart';
import 'package:fsep/core/network/api_exception.dart';
import 'package:fsep/data/repositories/exam_session_repository.dart';
import 'package:fsep/data/repositories/pending_answer_repository.dart';

/// Same "HTTP-transport-layer fake" pattern used across this suite (see
/// auth_repository_test.dart / exam_repository_test.dart).
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
  ) =>
      handler(options);
}

class _FixedKeyStorage extends DatabaseKeyStorage {
  _FixedKeyStorage(this.key);
  final String key;

  @override
  Future<String> getOrCreateKey() async => key;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpClientAdapter originalAdapter;
  late Directory tempDir;
  late LocalDatabaseService dbService;
  late PendingAnswerRepository pendingAnswers;

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    tempDir =
        Directory.systemTemp.createTempSync('fsep_exam_session_repo_test_');
    dbService = LocalDatabaseService(
      keyStorage: _FixedKeyStorage('e'.padRight(64, 'e')),
      testDbPath: '${tempDir.path}/test.db',
    );
    pendingAnswers = PendingAnswerRepository(databaseService: dbService);
  });

  tearDown(() async {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    await dbService.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'saveAnswer succeeds online exactly as before — no local queue entry '
    'is created when the save reaches the server',
    () async {
      ApiClient.instance.dio.httpClientAdapter =
          _FakeHttpClientAdapter((options) async {
        expect(options.path, '/exam-sessions/1/answers/11');
        return ResponseBody.fromString(
          jsonEncode({'answer': {'question_id': 11, 'selected_option': 'B'}}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repository = ExamSessionRepository(
        pendingAnswerRepository: pendingAnswers,
      );

      await repository.saveAnswer(
        sessionId: 1,
        questionId: 11,
        selectedOption: 'B',
      );

      final queued = await pendingAnswers.getPendingAnswers(sessionId: 1);
      expect(queued, isEmpty);
    },
  );

  test(
    'when the online save fails, the answer is queued locally AND the '
    'original exception is still rethrown unchanged (existing failure '
    'behavior is preserved)',
    () async {
      ApiClient.instance.dio.httpClientAdapter =
          _FakeHttpClientAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'message': 'This exam session has expired.'}),
          422,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repository = ExamSessionRepository(
        pendingAnswerRepository: pendingAnswers,
      );

      await expectLater(
        () => repository.saveAnswer(
          sessionId: 1,
          questionId: 11,
          selectedOption: 'B',
        ),
        throwsA(isA<ApiException>()),
      );

      final queued = await pendingAnswers.getPendingAnswer(
        sessionId: 1,
        questionId: 11,
      );
      expect(queued, isNotNull);
      expect(queued!.selectedOption, 'B');
    },
  );
}
