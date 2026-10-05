import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/exam_model.dart';
import '../models/exam_question_configuration_model.dart';
import 'local_exam_cache_repository.dart';

class ExamRepository {
  ExamRepository({
    ApiClient? apiClient,
    LocalExamCacheRepository? localExamCache,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _localExamCache = localExamCache ?? LocalExamCacheRepository();

  final ApiClient _apiClient;
  final LocalExamCacheRepository _localExamCache;

  Future<List<ExamModel>> getExams() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/exams');

    final data = response.data;

    if (data == null) {
      throw const ApiException('Empty response from server');
    }

    final exams = data['exams'];

    if (exams is! List) {
      throw const ApiException('Invalid exams response');
    }

    try {
      final List<ExamModel> examList = exams
          .map((exam) =>
              ExamModel.fromJson(exam as Map<String, dynamic>))
          .toList();

      for (final exam in examList) {
        if (exam.isOfflineReady) {
          unawaited(_cacheExamBestEffort(exam));
        }
      }

      return examList;
    } catch (error, stackTrace) {
      _logParsingError('GET /exams', error, stackTrace);
      rethrow;
    }
  }

  Future<ExamModel> getExam(int examId) async {
    final response =
        await _apiClient.get<Map<String, dynamic>>('/exams/$examId');

    final data = response.data;

    if (data == null || data['exam'] == null) {
      throw const ApiException('Exam not found');
    }

    final ExamModel exam;
    try {
      exam = ExamModel.fromJson(data['exam'] as Map<String, dynamic>);
    } catch (error, stackTrace) {
      _logParsingError('GET /exams/$examId', error, stackTrace);
      rethrow;
    }

    await _cacheExamBestEffort(exam);

    return exam;
  }

  Future<void> _cacheExamBestEffort(ExamModel exam) async {
    try {
      await _localExamCache.cacheExam(exam);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'ExamRepository: local cache failed (non-fatal): $error\n$stackTrace',
        );
      }
    }
  }

  Future<ExamModel> createExam({
    required String title,
    String? description,
    String? courseCode,
    required int durationMinutes,
    required double totalMarks,
    required double negativeMarkingWeight,
    required double passPercentage,
    required String status,
    List<String>? allowedPlatforms,
    bool bcdEnabled = true,
    bool randomizeQuestions = false,
    bool shuffleChoices = false,
    bool isOfflineReady = false,
    String? startsAt,
    String? endsAt,
    int? departmentId,
    int? semester,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/exams',
      data: {
        'title': title,
        'description': description,
        'course_code': courseCode,
        'duration_minutes': durationMinutes,
        'total_marks': totalMarks,
        'negative_marking_weight': negativeMarkingWeight,
        'pass_percentage': passPercentage,
        'status': status,
        'allowed_platforms': allowedPlatforms,
        'bcd_enabled': bcdEnabled,
        'randomize_questions': randomizeQuestions,
        'shuffle_choices': shuffleChoices,
        'is_offline_ready': isOfflineReady,
        'starts_at': startsAt,
        'ends_at': endsAt,
        'department_id': departmentId,
        'semester': semester,
      },
    );

    final data = response.data;
    if (data == null || data['exam'] == null) {
      throw const ApiException('Empty response from server');
    }

    return ExamModel.fromJson(data['exam'] as Map<String, dynamic>);
  }

  Future<ExamModel> updateExam({
    required int examId,
    required String title,
    String? description,
    String? courseCode,
    required int durationMinutes,
    required double totalMarks,
    required double negativeMarkingWeight,
    required double passPercentage,
    required String status,
    List<String>? allowedPlatforms,
    bool bcdEnabled = true,
    bool randomizeQuestions = false,
    bool shuffleChoices = false,
    bool isOfflineReady = false,
    String? startsAt,
    String? endsAt,
    int? departmentId,
    int? semester,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/exams/$examId',
      data: {
        'title': title,
        'description': description,
        'course_code': courseCode,
        'duration_minutes': durationMinutes,
        'total_marks': totalMarks,
        'negative_marking_weight': negativeMarkingWeight,
        'pass_percentage': passPercentage,
        'status': status,
        'allowed_platforms': allowedPlatforms,
        'bcd_enabled': bcdEnabled,
        'randomize_questions': randomizeQuestions,
        'shuffle_choices': shuffleChoices,
        'is_offline_ready': isOfflineReady,
        'starts_at': startsAt,
        'ends_at': endsAt,
        'department_id': departmentId,
        'semester': semester,
      },
    );

    final data = response.data;
    if (data == null || data['exam'] == null) {
      throw const ApiException('Empty response from server');
    }

    return ExamModel.fromJson(data['exam'] as Map<String, dynamic>);
  }

  Future<void> deleteExam(int examId) async {
    await _apiClient.delete<void>('/exams/$examId');
  }

  Future<List<ExamQuestionConfigurationModel>> syncQuestionConfigurations({
    required int examId,
    required List<ExamQuestionConfigurationModel> configurations,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/exams/$examId/question-configurations/sync',
      data: {
        'configurations': configurations.map((e) => e.toJson()).toList(),
      },
    );

    final data = response.data;
    if (data == null || data['question_configurations'] == null) {
      throw const ApiException('Empty response from server');
    }

    return (data['question_configurations'] as List)
        .map((e) => ExamQuestionConfigurationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _logParsingError(String request, Object error, StackTrace stackTrace) {
    if (kDebugMode) {
      debugPrint(
        'ExamRepository: failed to parse response for $request: $error\n$stackTrace',
      );
    }
  }
}
