import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/database/database_key_storage.dart';
import 'package:fsep/core/database/local_database_service.dart';
import 'package:fsep/core/network/api_client.dart';
import 'package:fsep/data/repositories/local_session_repository.dart';
import 'package:fsep/data/repositories/pending_answer_repository.dart';
import 'package:fsep/features/exam_delivery/views/exam_delivery_view.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    tempDir = Directory.systemTemp.createTempSync('fsep_exam_delivery_view_test_');
    dbService = LocalDatabaseService(
      keyStorage: _FixedKeyStorage('g'.padRight(64, 'g')),
      testDbPath: '${tempDir.path}/test.db',
    );
    localSessions = LocalSessionRepository(databaseService: dbService);
    pendingAnswers = PendingAnswerRepository(databaseService: dbService);
  });

  tearDown(() async {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
    await dbService.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget createWidget() {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: localSessions),
        RepositoryProvider.value(value: pendingAnswers),
      ],
      child: const MaterialApp(
        home: ExamDeliveryView(examId: 1),
      ),
    );
  }

  testWidgets('ExamDeliveryView restores and persists question index', (tester) async {
    final now = DateTime.now().toIso8601String();
    
    // 1. Mock API responses for exam and session
    ApiClient.instance.dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
      if (options.path.contains('/exams/1/session')) {
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
      } else if (options.path == '/exams/1') {
        return ResponseBody.fromString(
          jsonEncode({
            'exam': {
              'id': 1,
              'title': 'Test Exam',
              'duration_minutes': 60,
              'status': 'published',
              'total_marks': 10,
              'negative_marking_weight': 0,
              'questions': [
                {'id': 101, 'exam_id': 1, 'question_text': 'Q1', 'question_type': 'mcq', 'marks': 5, 'options': ['A', 'B']},
                {'id': 102, 'exam_id': 1, 'question_text': 'Q2', 'question_type': 'mcq', 'marks': 5, 'options': ['A', 'B']},
                {'id': 103, 'exam_id': 1, 'question_text': 'Q3', 'question_type': 'mcq', 'marks': 5, 'options': ['A', 'B']},
              ]
            }
          }),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      return ResponseBody.fromString('', 404);
    });

    // 2. Pre-seed a local session with cached index 2
    await localSessions.saveSession(
      serverSessionId: 100,
      examId: 1,
      status: 'in_progress',
      startedAt: DateTime.now(),
      currentQuestionIndex: 2,
    );

    // 3. Pump the widget
    await tester.pumpWidget(createWidget());
    // Initial pump to start loading
    await tester.pump(); 
    // Wait for Futures to complete. We don't use pumpAndSettle because of the 1s timer.
    await tester.pump(const Duration(milliseconds: 500)); 
    await tester.pump(const Duration(milliseconds: 500)); 

    // 4. Verify restored position (Question 3 of 3)
    expect(find.text('Question 3 of 3'), findsOneWidget);

    // 5. Move to Question 2 (index 1)
    await tester.tap(find.text('Previous'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Question 2 of 3'), findsOneWidget);

    // 6. Verify persistence in SQLite
    final record = await localSessions.getSessionByServerId(100);
    expect(record!.currentQuestionIndex, 1);
  });

  testWidgets('ExamDeliveryView restores persistent timer offline', (tester) async {
    final expiresAt = DateTime.now().add(const Duration(minutes: 15));
    final startedAt = DateTime.now().subtract(const Duration(minutes: 45));

    // 1. Mock API for exam (fails for session to trigger fallback)
    ApiClient.instance.dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
      if (options.path.contains('/exams/1/session')) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      } else if (options.path == '/exams/1') {
        return ResponseBody.fromString(
          jsonEncode({
            'exam': {
              'id': 1,
              'title': 'Test Exam',
              'duration_minutes': 60,
              'status': 'published',
              'total_marks': 10,
              'negative_marking_weight': 0,
              'questions': [
                {'id': 101, 'exam_id': 1, 'question_text': 'Q1', 'question_type': 'mcq', 'marks': 5, 'options': ['A', 'B']},
              ]
            }
          }),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
      return ResponseBody.fromString('', 404);
    });

    // 2. Pre-seed a local session with 15 mins remaining
    await localSessions.saveSession(
      serverSessionId: 100,
      examId: 1,
      status: 'in_progress',
      startedAt: startedAt,
      expiresAt: expiresAt,
      serverClockOffsetMs: 0,
    );

    // 3. Pump the widget
    await tester.pumpWidget(createWidget());
    await tester.pump(); // Start load
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // 4. Verify timer shows 15:00 (approx)
    // We expect "15:00" or "14:59" depending on exact timing.
    expect(
      find.textContaining('15:00')
          .evaluate()
          .followedBy(find.textContaining('14:59').evaluate())
          .isNotEmpty,
      isTrue,
      reason: 'Timer should show approximately 15 minutes remaining',
    );
  });
}
