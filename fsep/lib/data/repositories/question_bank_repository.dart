import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/generated_question_draft.dart';
import '../models/question_model.dart';

/// Question Bank repository.
class QuestionBankRepository {
  QuestionBankRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<List<GeneratedQuestionDraft>> generateQuestions({
    required List<int> examIds,
    required String topic,
    required List<String> questionTypes,
    required String difficulty,
    required String bloomTaxonomy,
    required int count,
    required int marks,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/questions/generate',
      data: {
        'exam_ids': examIds,
        'topic': topic,
        'question_types': questionTypes,
        'difficulty': difficulty,
        'bloom_taxonomy': bloomTaxonomy,
        'count': count,
        'marks': marks,
      },
    );

    final data = response.data;
    final questions = data?['questions'] ?? data?['data'];

    if (questions is! List) {
      throw const ApiException('Invalid response from server (expected a list of questions)');
    }

    return questions
        .map((q) =>
            GeneratedQuestionDraft.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> uploadGenerationDocuments({
    required List<String> filePaths,
    required List<int> examIds,
    required List<String> questionTypes,
    required String difficulty,
    required String bloomTaxonomy,
    required int count,
    required int marks,
  }) async {
    final formData = FormData.fromMap({
      'exam_ids': examIds,
      'question_types': questionTypes,
      'difficulty': difficulty,
      'bloom_taxonomy': bloomTaxonomy,
      'count': count,
      'marks': marks,
    });

    for (final path in filePaths) {
      formData.files.add(MapEntry(
        'files[]',
        await MultipartFile.fromFile(path),
      ));
    }

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/questions/generate/upload',
      data: formData,
    );

    final data = response.data;
    if (data == null) {
      throw const ApiException('Empty response from server');
    }

    return data;
  }

  Future<Map<String, dynamic>> getJobStatus(int jobId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/questions/generate/job/$jobId',
    );

    final data = response.data;
    if (data == null) {
      throw const ApiException('Empty response from server');
    }

    return data;
  }

  Future<List<QuestionModel>> getQuestions({int? examId}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/questions',
      queryParameters: examId != null ? {'exam_id': examId} : null,
    );

    final data = response.data;
    final questions = data?['questions'] ?? data?['data'];

    if (questions is! List) {
      throw const ApiException('Invalid response from server (expected a list of questions)');
    }

    try {
      return questions
          .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
          .toList();
    } catch (error, stackTrace) {
      _logParsingError('GET /questions', error, stackTrace);
      rethrow;
    }
  }

  Future<QuestionModel> createQuestion(GeneratedQuestionDraft draft) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/questions',
      data: {
        'exam_id': draft.examId,
        'question_text': draft.questionText,
        'question_type': draft.questionType,
        'marks': draft.marks,
        'difficulty': draft.difficulty,
        'bloom_taxonomy': draft.bloomTaxonomy,
        'topic_tag': draft.topicTag,
        'options': draft.options.isEmpty ? null : draft.options,
        'correct_answer': draft.correctAnswer,
        'keywords': draft.keywords.isEmpty ? null : draft.keywords,
        'regex_patterns': draft.regexPatterns.isEmpty ? null : draft.regexPatterns,
        'is_ai_generated': draft.isAiGenerated,
      },
    );

    final data = response.data;
    if (data == null || data['question'] == null) {
      throw const ApiException('Empty response from server');
    }

    return QuestionModel.fromJson(data['question'] as Map<String, dynamic>);
  }

  Future<QuestionModel> updateQuestion(
    QuestionModel question, {
    required String reviewStatus,
    String? rejectionReason,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/questions/${question.id}',
      data: {
        'exam_id': question.examId,
        'question_text': question.questionText,
        'question_type': question.questionType,
        'marks': question.marks.round(),
        'difficulty': question.difficulty,
        'bloom_taxonomy': question.bloomTaxonomy,
        'topic_tag': question.topicTag,
        'options': question.questionType == 'matching'
            ? (question.matchingPairs.isEmpty
                ? null
                : question.matchingPairs.map((p) => p.toJson()).toList())
            : (question.options.isEmpty ? null : question.options),
        'correct_answer': question.correctAnswer,
        'keywords': question.keywords.isEmpty ? null : question.keywords,
        'regex_patterns':
            question.regexPatterns.isEmpty ? null : question.regexPatterns,
        'is_ai_generated': question.isAiGenerated,
        'review_status': reviewStatus,
        'rejection_reason': rejectionReason,
      },
    );

    final data = response.data;
    if (data == null || data['question'] == null) {
      throw const ApiException('Empty response from server');
    }

    return QuestionModel.fromJson(data['question'] as Map<String, dynamic>);
  }

  Future<List<QuestionModel>> getReviewQueue(int jobId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/questions/generate/review/$jobId',
    );

    final data = response.data;
    final questions = data?['questions'] ?? data?['data'];

    if (questions is! List) {
      throw const ApiException('Invalid response from server (expected a list of questions)');
    }

    return questions
        .map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> bulkReviewQuestions({
    required List<int> questionIds,
    required String action,
    String? rejectionReason,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/questions/generate/approve',
      data: {
        'question_ids': questionIds,
        'action': action,
        'rejection_reason': rejectionReason,
      },
    );

    final data = response.data;
    if (data == null) {
      throw const ApiException('Empty response from server');
    }

    return data;
  }

  Future<void> deleteQuestion(int questionId) async {
    await _apiClient.delete<void>('/questions/$questionId');
  }

  void _logParsingError(String request, Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint(
        'QuestionBankRepository: failed to parse response for $request: $error\n$stackTrace',
      );
    }
  }
}
