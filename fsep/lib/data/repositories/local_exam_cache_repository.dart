import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi' show ConflictAlgorithm;

import '../../core/database/local_database_schema.dart';
import '../../core/database/local_database_service.dart';
import '../models/exam_model.dart';
import '../models/question_model.dart';

/// Local repository for caching exams and questions into SQLite.
class LocalExamCacheRepository {
  LocalExamCacheRepository({LocalDatabaseService? databaseService})
      : _db = databaseService ?? LocalDatabaseService.instance;

  final LocalDatabaseService _db;

  Future<void> cacheExam(ExamModel exam) async {
    if (!LocalDatabaseService.isSupportedOnThisPlatform) {
      return;
    }

    final cachedAt = DateTime.now().toIso8601String();

    await _db.transaction((txn) async {
      await txn.insert(
        LocalDatabaseSchema.tableExams,
        {
          'id': exam.id,
          'created_by': exam.createdBy,
          'title': exam.title,
          'description': exam.description,
          'course_code': exam.courseCode,
          'duration_minutes': exam.durationMinutes,
          'total_marks': exam.totalMarks,
          'negative_marking_weight': exam.negativeMarkingWeight,
          'pass_percentage': exam.passPercentage,
          'status': exam.status,
          'bcd_enabled': exam.bcdEnabled ? 1 : 0,
          'randomize_questions': exam.randomizeQuestions ? 1 : 0,
          'shuffle_choices': exam.shuffleChoices ? 1 : 0,
          'is_offline_ready': exam.isOfflineReady ? 1 : 0,
          'question_count': exam.questions.length,
          'cached_at': cachedAt,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        LocalDatabaseSchema.tableQuestions,
        where: 'exam_id = ?',
        whereArgs: [exam.id],
      );

      for (var i = 0; i < exam.questions.length; i++) {
        await txn.insert(
          LocalDatabaseSchema.tableQuestions,
          _questionRow(exam.questions[i], sortOrder: i, cachedAt: cachedAt),
        );
      }
    });
  }

  Future<ExamModel?> getCachedExam(int examId) async {
    final examRow = await _db.getExam(examId);
    if (examRow == null) {
      return null;
    }

    final questionRows = List<Map<String, dynamic>>.of(
      await _db.getQuestionsForExam(examId),
    )..sort(
        (a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int),
      );

    return ExamModel(
      id: examRow['id'] as int,
      createdBy: examRow['created_by'] as int,
      title: examRow['title'] as String,
      description: examRow['description'] as String?,
      courseCode: examRow['course_code'] as String?,
      durationMinutes: examRow['duration_minutes'] as int,
      totalMarks: (examRow['total_marks'] as num).toDouble(),
      negativeMarkingWeight:
          (examRow['negative_marking_weight'] as num).toDouble(),
      passPercentage: (examRow['pass_percentage'] as num).toDouble(),
      status: examRow['status'] as String,
      bcdEnabled: (examRow['bcd_enabled'] as int) == 1,
      randomizeQuestions: (examRow['randomize_questions'] as int) == 1,
      shuffleChoices: (examRow['shuffle_choices'] as int) == 1,
      isOfflineReady: (examRow['is_offline_ready'] as int) == 1,
      questions: questionRows.map(_questionFromRow).toList(),
    );
  }

  Future<bool> isExamFullyCached(int examId) async {
    final examRow = await _db.getExam(examId);
    if (examRow == null) {
      return false;
    }
    final expected = examRow['question_count'] as int;
    final actual = await _db.getQuestionsForExam(examId);
    return actual.length == expected;
  }

  Map<String, dynamic> _questionRow(
    QuestionModel question, {
    required int sortOrder,
    required String cachedAt,
  }) {
    String? options;
    if (question.questionType == 'matching') {
      if (question.matchingPairs.isNotEmpty) {
        options = jsonEncode(
          question.matchingPairs.map((p) => p.toJson()).toList(),
        );
      }
    } else if (question.options.isNotEmpty) {
      options = jsonEncode(question.options);
    }

    return {
      'id': question.id,
      'exam_id': question.examId,
      'question_text': question.questionText,
      'question_type': question.questionType,
      'marks': question.marks,
      'difficulty': question.difficulty,
      'bloom_taxonomy': question.bloomTaxonomy,
      'topic_tag': question.topicTag,
      'options': options,
      'review_status': question.reviewStatus,
      'is_ai_generated': question.isAiGenerated ? 1 : 0,
      'sort_order': sortOrder,
      'cached_at': cachedAt,
    };
  }

  QuestionModel _questionFromRow(Map<String, dynamic> row) {
    final questionType = row['question_type'] as String;
    final optionsJson = row['options'] as String?;
    final decoded = optionsJson != null ? jsonDecode(optionsJson) : null;

    return QuestionModel(
      id: row['id'] as int,
      examId: row['exam_id'] as int,
      questionText: row['question_text'] as String,
      questionType: questionType,
      marks: (row['marks'] as num).toDouble(),
      difficulty: row['difficulty'] as String?,
      bloomTaxonomy: row['bloom_taxonomy'] as String?,
      topicTag: row['topic_tag'] as String?,
      options: questionType != 'matching' && decoded is List
          ? decoded.map((e) => e.toString()).toList()
          : const <String>[],
      matchingPairs: questionType == 'matching' && decoded is List
          ? decoded
              .map((e) => MatchingPair.fromJson(e as Map<String, dynamic>))
              .toList()
          : const <MatchingPair>[],
      correctAnswer: null,
      isAiGenerated: (row['is_ai_generated'] as int) == 1,
      reviewStatus: row['review_status'] as String? ?? 'approved',
    );
  }
}
