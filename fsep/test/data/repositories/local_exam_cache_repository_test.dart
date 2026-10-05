import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/database/database_key_storage.dart';
import 'package:fsep/core/database/local_database_service.dart';
import 'package:fsep/data/models/exam_model.dart';
import 'package:fsep/data/models/question_model.dart';
import 'package:fsep/data/repositories/local_exam_cache_repository.dart';

/// Same in-memory key-storage double used in the Phase A test suite
/// (test/core/database/local_database_service_test.dart) — avoids
/// touching the real flutter_secure_storage platform channel.
class _FixedKeyStorage extends DatabaseKeyStorage {
  _FixedKeyStorage(this.key);
  final String key;

  @override
  Future<String> getOrCreateKey() async => key;
}

void main() {
  late Directory tempDir;
  late LocalDatabaseService dbService;
  late LocalExamCacheRepository cache;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fsep_exam_cache_test_');
    dbService = LocalDatabaseService(
      keyStorage: _FixedKeyStorage('c'.padRight(64, 'c')),
      testDbPath: '${tempDir.path}/test.db',
    );
    cache = LocalExamCacheRepository(databaseService: dbService);
  });

  tearDown(() async {
    await dbService.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  /// One question of every currently supported type, with realistic
  /// per-type field shapes matching exactly what QuestionModel.fromJson
  /// (i.e. the real server response) produces — see
  /// QuestionController::validatedQuestionData on the backend for the
  /// canonical shape each type is built from.
  ExamModel sixTypeExam({int id = 1}) {
    return ExamModel(
      id: id,
      createdBy: 7,
      title: 'Approval Gate Test Exam',
      description: 'A cached exam for Phase B tests',
      courseCode: 'CS101',
      durationMinutes: 60,
      totalMarks: 30,
      negativeMarkingWeight: 0.25,
      passPercentage: 50.0,
      status: 'published',
      bcdEnabled: true,
      randomizeQuestions: false,
      shuffleChoices: false,
      isOfflineReady: false,
      questions: [
        QuestionModel(
          id: 101,
          examId: id,
          questionText: 'What does CPU stand for?',
          questionType: 'mcq',
          marks: 5,
          difficulty: 'easy',
          bloomTaxonomy: 'remember',
          topicTag: 'Basics',
          options: const [
            'Central Processing Unit',
            'Computer Personal Unit',
          ],
          isAiGenerated: false,
          reviewStatus: 'approved',
        ),
        QuestionModel(
          id: 102,
          examId: id,
          questionText: 'RAM is volatile.',
          questionType: 'true_false',
          marks: 5,
          difficulty: 'easy',
          bloomTaxonomy: 'remember',
          topicTag: 'Basics',
          options: const [],
          isAiGenerated: false,
          reviewStatus: 'approved',
        ),
        QuestionModel(
          id: 103,
          examId: id,
          questionText: 'What does GPU stand for?',
          questionType: 'short_answer',
          marks: 5,
          difficulty: 'medium',
          bloomTaxonomy: 'understand',
          topicTag: 'Basics',
          options: const [],
          isAiGenerated: false,
          reviewStatus: 'approved',
        ),
        QuestionModel(
          id: 104,
          examId: id,
          questionText: 'Explain RAM vs ROM.',
          questionType: 'essay',
          marks: 5,
          difficulty: 'medium',
          bloomTaxonomy: 'analyze',
          topicTag: 'Basics',
          options: const [],
          isAiGenerated: false,
          reviewStatus: 'approved',
        ),
        QuestionModel(
          id: 105,
          examId: id,
          questionText: 'Match component to function.',
          questionType: 'matching',
          marks: 5,
          difficulty: 'medium',
          bloomTaxonomy: 'understand',
          topicTag: 'Basics',
          options: const [],
          matchingPairs: const [
            MatchingPair(left: 'CPU', right: 'Executes instructions'),
            MatchingPair(left: 'RAM', right: 'Temporary memory'),
          ],
          isAiGenerated: false,
          reviewStatus: 'approved',
        ),
        QuestionModel(
          id: 106,
          examId: id,
          questionText: 'Write a function that sums two integers.',
          questionType: 'code_snippet',
          marks: 5,
          difficulty: 'medium',
          bloomTaxonomy: 'apply',
          topicTag: 'Basics',
          options: const ['python'],
          isAiGenerated: false,
          reviewStatus: 'approved',
        ),
      ],
    );
  }

  test('Test 1 — an online exam can be cached', () async {
    await cache.cacheExam(sixTypeExam());
    final cached = await cache.getCachedExam(1);

    expect(cached, isNotNull);
    expect(cached!.title, 'Approval Gate Test Exam');
    expect(cached.courseCode, 'CS101');
    expect(cached.durationMinutes, 60);
  });

  test('Test 2 — every question belonging to the exam is cached', () async {
    await cache.cacheExam(sixTypeExam());
    final cached = await cache.getCachedExam(1);

    expect(cached!.questions, hasLength(6));
  });

  test(
    'Test 3 — all six question types round-trip correctly through the '
    'local database',
    () async {
      await cache.cacheExam(sixTypeExam());
      final cached = await cache.getCachedExam(1);

      final byType = {
        for (final q in cached!.questions) q.questionType: q,
      };

      expect(byType['mcq']!.options, [
        'Central Processing Unit',
        'Computer Personal Unit',
      ]);
      expect(byType['true_false'], isNotNull);
      expect(byType['short_answer'], isNotNull);
      expect(byType['essay'], isNotNull);
      expect(byType['matching']!.matchingPairs, hasLength(2));
      expect(byType['matching']!.matchingPairs.first.left, 'CPU');
      expect(byType['matching']!.matchingPairs.first.right,
          'Executes instructions');
      expect(byType['code_snippet']!.options, ['python']);
    },
  );

  test('Test 4 — the exam/question relationship is preserved', () async {
    final examA = sixTypeExam(id: 1);
    final examB = ExamModel(
      id: 2,
      createdBy: 7,
      title: 'A Different Exam',
      durationMinutes: 30,
      totalMarks: 5,
      negativeMarkingWeight: 0,
      passPercentage: 50.0,
      status: 'draft',
      bcdEnabled: true,
      randomizeQuestions: false,
      shuffleChoices: false,
      isOfflineReady: false,
      questions: [
        QuestionModel(
          id: 201,
          examId: 2,
          questionText: 'Unrelated question',
          questionType: 'mcq',
          marks: 5,
          options: const ['A', 'B'],
          isAiGenerated: false,
          reviewStatus: 'approved',
        ),
      ],
    );

    await cache.cacheExam(examA);
    await cache.cacheExam(examB);

    final cachedA = await cache.getCachedExam(1);
    final cachedB = await cache.getCachedExam(2);

    expect(cachedA!.questions, hasLength(6));
    expect(cachedA.questions.every((q) => q.examId == 1), isTrue);
    expect(cachedB!.questions, hasLength(1));
    expect(cachedB.questions.single.questionText, 'Unrelated question');
  });

  test('Test 5 — question ordering is preserved', () async {
    await cache.cacheExam(sixTypeExam());
    final cached = await cache.getCachedExam(1);

    expect(
      cached!.questions.map((q) => q.questionType).toList(),
      ['mcq', 'true_false', 'short_answer', 'essay', 'matching', 'code_snippet'],
    );
  });

  test('Test 6 — marks are preserved', () async {
    final exam = ExamModel(
      id: 1,
      createdBy: 7,
      title: 'Marks Test',
      durationMinutes: 30,
      totalMarks: 15,
      negativeMarkingWeight: 0.25,
      passPercentage: 50.0,
      status: 'published',
      bcdEnabled: true,
      randomizeQuestions: false,
      shuffleChoices: false,
      isOfflineReady: false,
      questions: [
        QuestionModel(
          id: 1,
          examId: 1,
          questionText: 'Q1',
          questionType: 'mcq',
          marks: 7.5,
          options: const ['A', 'B'],
          isAiGenerated: false,
          reviewStatus: 'approved',
        ),
      ],
    );
    await cache.cacheExam(exam);
    final cached = await cache.getCachedExam(1);

    expect(cached!.totalMarks, 15);
    expect(cached.questions.single.marks, 7.5);
  });

  test('Test 7 — a cached exam can be retrieved by id', () async {
    await cache.cacheExam(sixTypeExam(id: 42));
    expect(await cache.getCachedExam(42), isNotNull);
    expect(await cache.getCachedExam(999), isNull);
  });

  test('Test 8 — cached questions can be retrieved by exam id', () async {
    await cache.cacheExam(sixTypeExam(id: 5));
    final rows = await LocalExamCacheRepository(databaseService: dbService)
        .getCachedExam(5);
    expect(rows!.questions.every((q) => q.examId == 5), isTrue);
  });

  test('Test 9 — cache completeness can be determined', () async {
    // Never cached at all.
    expect(await cache.isExamFullyCached(1), isFalse);

    await cache.cacheExam(sixTypeExam());
    expect(await cache.isExamFullyCached(1), isTrue);

    // Re-caching with fewer questions (e.g. one was un-approved
    // server-side) must be reflected — the delete-then-reinsert design
    // means the stale extra question does not linger.
    final shrunk = ExamModel(
      id: 1,
      createdBy: 7,
      title: 'Approval Gate Test Exam',
      durationMinutes: 60,
      totalMarks: 30,
      negativeMarkingWeight: 0.25,
      passPercentage: 50.0,
      status: 'published',
      bcdEnabled: true,
      randomizeQuestions: false,
      shuffleChoices: false,
      isOfflineReady: false,
      questions: [
        QuestionModel(
          id: 101,
          examId: 1,
          questionText: 'What does CPU stand for?',
          questionType: 'mcq',
          marks: 5,
          options: const ['A', 'B'],
          isAiGenerated: false,
          reviewStatus: 'approved',
        ),
      ],
    );
    await cache.cacheExam(shrunk);
    expect(await cache.isExamFullyCached(1), isTrue);
    final reCached = await cache.getCachedExam(1);
    expect(reCached!.questions, hasLength(1));
  });

  test(
    'Test 11 — no candidate-visible correct answers are introduced into '
    'the offline cache',
    () async {
      await cache.cacheExam(sixTypeExam());
      final cached = await cache.getCachedExam(1);

      // Every reconstructed question's correctAnswer must be null — the
      // local schema has no column to store one in, and the source
      // ExamModel here (matching what the real candidate-facing API
      // actually sends) never carries one either.
      for (final q in cached!.questions) {
        expect(
          q.correctAnswer,
          isNull,
          reason: '${q.questionType} question exposed a correct answer',
        );
      }
    },
  );
}
