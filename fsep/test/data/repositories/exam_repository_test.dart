import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/network/api_client.dart';
import 'package:fsep/data/models/exam_model.dart';
import 'package:fsep/data/repositories/exam_repository.dart';
import 'package:fsep/data/repositories/local_exam_cache_repository.dart';

/// Same "HTTP-transport-layer fake" pattern as auth_repository_test.dart
/// — the real ApiClient/Dio pipeline still runs, just without a real
/// network call.
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

/// Always fails to cache — proves Phase B's caching side effect can
/// never take down the online exam-loading path it was added to.
class _ThrowingExamCacheRepository extends LocalExamCacheRepository {
  @override
  Future<void> cacheExam(ExamModel exam) async {
    throw StateError('simulated local cache failure');
  }
}

/// Captures cached exams for inspection.
class _SpyExamCacheRepository extends LocalExamCacheRepository {
  final List<int> cachedIds = [];

  @override
  Future<void> cacheExam(ExamModel exam) async {
    cachedIds.add(exam.id);
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

  Map<String, dynamic> examJson({int id = 1, bool offlineReady = false}) => {
        'id': id,
        'created_by': 7,
        'title': 'Exam $id',
        'description': null,
        'course_code': 'CS101',
        'duration_minutes': 60,
        'total_marks': '20.00',
        'negative_marking_weight': '0.25',
        'pass_percentage': '50.00',
        'status': 'published',
        'bcd_enabled': true,
        'randomize_questions': false,
        'shuffle_choices': false,
        'is_offline_ready': offlineReady,
        'starts_at': null,
        'ends_at': null,
        'questions': [
          {
            'id': id * 10,
            'exam_id': id,
            'question_text': 'Q in $id',
            'question_type': 'mcq',
            'marks': 5,
            'difficulty': 'easy',
            'bloom_taxonomy': 'remember',
            'topic_tag': 'Basics',
            'options': ['A', 'B'],
            'is_ai_generated': false,
            'review_status': 'approved',
          },
        ],
      };

  test(
    'Test 10 — a local cache failure does not break the online exam flow',
    () async {
      ApiClient.instance.dio.httpClientAdapter =
          _FakeHttpClientAdapter((options) async {
        expect(options.path, '/exams/1');
        return ResponseBody.fromString(
          jsonEncode({'exam': examJson(id: 1)}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final repository = ExamRepository(
        localExamCache: _ThrowingExamCacheRepository(),
      );

      // Must not throw despite the cache repository always throwing.
      final exam = await repository.getExam(1);

      expect(exam.id, 1);
      expect(exam.title, 'Exam 1');
      expect(exam.questions, hasLength(1));
      expect(exam.questions.single.questionType, 'mcq');
    },
  );

  test(
    'FR-EA-03 — Offline-ready exams are automatically pre-cached from the list',
    () async {
      ApiClient.instance.dio.httpClientAdapter =
          _FakeHttpClientAdapter((options) async {
        expect(options.path, '/exams');
        return ResponseBody.fromString(
          jsonEncode({
            'exams': [
              examJson(id: 1, offlineReady: true),
              examJson(id: 2, offlineReady: false),
            ]
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final spy = _SpyExamCacheRepository();
      final repository = ExamRepository(localExamCache: spy);

      await repository.getExams();

      // Small delay to allow unawaited tasks to fire (though in tests
      // it's usually deterministic).
      await Future.delayed(Duration.zero);

      expect(spy.cachedIds, contains(1), reason: 'Offline-ready exam 1 must be cached');
      expect(spy.cachedIds, isNot(contains(2)), reason: 'Normal exam 2 must not be pre-cached');
    },
  );
}
