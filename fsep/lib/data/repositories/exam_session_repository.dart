import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/bcd_update_model.dart';
import '../models/exam_session_model.dart';
import '../models/result_model.dart';
import 'local_behavior_event_repository.dart';
import 'local_session_repository.dart';
import 'pending_answer_repository.dart';

class ExamSessionRepository {
  ExamSessionRepository({
    ApiClient? apiClient,
    PendingAnswerRepository? pendingAnswerRepository,
    LocalSessionRepository? localSessionRepository,
    LocalBehaviorEventRepository? localBehaviorEvents,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _pendingAnswers = pendingAnswerRepository ?? PendingAnswerRepository(),
        _localSessions = localSessionRepository ?? LocalSessionRepository(),
        _localBehaviorEvents =
            localBehaviorEvents ?? LocalBehaviorEventRepository();

  final ApiClient _apiClient;
  final PendingAnswerRepository _pendingAnswers;
  final LocalSessionRepository _localSessions;
  final LocalBehaviorEventRepository _localBehaviorEvents;

  Future<ExamSessionModel> startOrResumeSession(int examId) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/exams/$examId/session',
      );

      final data = response.data;

      if (data == null || data['session'] == null) {
        throw const ApiException('Empty response from server');
      }

      final session =
          ExamSessionModel.fromJson(data['session'] as Map<String, dynamic>);

      await _cacheSessionBestEffort(session);

      return session;
    } on ApiException catch (error) {
      if (error.statusCode == null) {
        final cached = await _tryGetCachedSession(examId);
        if (cached != null) {
          return cached;
        }
      }
      rethrow;
    }
  }

  Future<void> _cacheSessionBestEffort(ExamSessionModel session) async {
    try {
      await _localSessions.saveSession(
        serverSessionId: session.id,
        examId: session.examId,
        status: session.status,
        startedAt: session.startedAt,
        expiresAt: session.expiresAt,
        serverClockOffsetMs:
            session.serverTime.difference(DateTime.now()).inMilliseconds,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'ExamSessionRepository: failed to cache session locally '
          '(non-fatal): $error\n$stackTrace',
        );
      }
    }
  }

  Future<ExamSessionModel?> _tryGetCachedSession(int examId) async {
    try {
      final record = await _localSessions.getSessionByExamId(examId);
      if (record == null || record.serverSessionId == null) {
        return null;
      }

      final answers = await _pendingAnswers.getAnswersForSession(
        sessionId: record.serverSessionId!,
      );

      return record.toModel(answers);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'ExamSessionRepository: offline recovery failed: $error\n$stackTrace',
        );
      }
      return null;
    }
  }

  Future<void> saveAnswer({
    required int sessionId,
    required int questionId,
    required String selectedOption,
  }) async {
    try {
      await _apiClient.put<Map<String, dynamic>>(
        '/exam-sessions/$sessionId/answers/$questionId',
        data: {'selected_option': selectedOption},
      );
    } catch (error) {
      await _queuePendingAnswerBestEffort(
        sessionId: sessionId,
        questionId: questionId,
        selectedOption: selectedOption,
      );
      rethrow;
    }
  }

  Future<void> _queuePendingAnswerBestEffort({
    required int sessionId,
    required int questionId,
    required String selectedOption,
  }) async {
    try {
      await _pendingAnswers.savePendingAnswer(
        sessionId: sessionId,
        questionId: questionId,
        selectedOption: selectedOption,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'ExamSessionRepository: failed to queue answer locally '
          '(non-fatal): $error\n$stackTrace',
        );
      }
    }
  }

  Future<ExamSessionModel> submitSession(int sessionId) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/exam-sessions/$sessionId/submit',
    );

    final data = response.data;

    if (data == null || data['session'] == null) {
      throw const ApiException('Empty response from server');
    }

    return ExamSessionModel.fromJson(data['session'] as Map<String, dynamic>);
  }

  Future<SuspicionSummary> recordBehaviorEvent({
    required int sessionId,
    required String eventType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/exam-sessions/$sessionId/behavior-events',
        data: {
          'event_type': eventType,
          'metadata': metadata,
        },
      );

      final data = response.data;
      if (data == null) {
        throw const ApiException('Empty response from server');
      }

      return SuspicionSummary.fromJson(data);
    } catch (error) {
      await _queueBehaviorEventBestEffort(
        sessionId: sessionId,
        eventType: eventType,
        metadata: metadata,
      );
      rethrow;
    }
  }

  Future<void> _queueBehaviorEventBestEffort({
    required int sessionId,
    required String eventType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _localBehaviorEvents.saveEvent(
        sessionId: sessionId,
        eventType: eventType,
        metadata: metadata,
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'ExamSessionRepository: failed to queue behavior event locally '
          '(non-fatal): $error\n$stackTrace',
        );
      }
    }
  }

  Future<ResultModel> getResult(int sessionId) async {
    final response =
        await _apiClient.get<Map<String, dynamic>>('/results/$sessionId');

    final data = response.data;
    if (data == null || data['result'] == null) {
      throw const ApiException('Empty response from server');
    }

    return ResultModel.fromJson(data['result'] as Map<String, dynamic>);
  }

  Future<List<InvigilatorSessionModel>> getActiveSessions() async {
    final response =
        await _apiClient.get<Map<String, dynamic>>('/exam-sessions');

    final data = response.data;
    final sessions = data?['sessions'];
    if (sessions is! List) {
      throw const ApiException('Invalid response from server');
    }

    return sessions
        .map((s) =>
            InvigilatorSessionModel.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<BehaviorEventLog> getBehaviorEvents(int sessionId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/exam-sessions/$sessionId/behavior-events',
    );

    final data = response.data;
    if (data == null) {
      throw const ApiException('Empty response from server');
    }

    return BehaviorEventLog.fromJson(data);
  }

  Future<void> reviewBehavioralEvent({
    required int eventId,
    required String action,
    String? note,
  }) async {
    await _apiClient.post<void>(
      '/behavioral/review',
      data: {
        'event_id': eventId,
        'action': action,
        'note': note,
      },
    );
  }

  Future<Uint8List> getResultPdf(int sessionId) async {
    final response = await _apiClient.get<List<int>>(
      '/results/$sessionId/pdf',
      responseType: ResponseType.bytes,
    );

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const ApiException('Empty response from server');
    }

    return Uint8List.fromList(data);
  }

  Future<Uint8List> getResultExcel(int sessionId) async {
    final response = await _apiClient.get<List<int>>(
      '/results/$sessionId/excel',
      responseType: ResponseType.bytes,
    );

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const ApiException('Empty response from server');
    }

    return Uint8List.fromList(data);
  }

  Future<PendingAnswerModel> getPendingAnswer({
    required int sessionId,
    required int questionId,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/exam-sessions/$sessionId/answers/$questionId/manual-grade',
    );

    final data = response.data;
    if (data == null || data['answer'] == null) {
      throw const ApiException('Empty response from server');
    }

    return PendingAnswerModel.fromJson(data['answer'] as Map<String, dynamic>);
  }

  Future<ResultModel> submitManualGrade({
    required int sessionId,
    required int questionId,
    required double obtainedMarks,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/exam-sessions/$sessionId/answers/$questionId/manual-grade',
      data: {'obtained_marks': obtainedMarks},
    );

    final data = response.data;
    if (data == null || data['result'] == null) {
      throw const ApiException('Empty response from server');
    }

    return ResultModel.fromJson(data['result'] as Map<String, dynamic>);
  }

  Future<List<AnswerSyncResultItem>> syncAnswers({
    required int sessionId,
    required List<PendingAnswerRecord> answers,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/exam-sessions/$sessionId/answers/sync',
      data: {
        'answers': answers
            .map((a) => {
                  'question_id': a.questionId,
                  'selected_option': a.selectedOption,
                  'client_updated_at': a.updatedAt.toIso8601String(),
                })
            .toList(),
      },
    );

    final data = response.data;
    final results = data?['results'];
    if (results is! List) {
      throw const ApiException('Invalid sync response from server');
    }

    return results
        .map((r) => AnswerSyncResultItem.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<BehaviorSyncResultItem>> syncBehaviorEvents({
    required int sessionId,
    required List<LocalBehaviorEventRecord> events,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/exam-sessions/$sessionId/behavior-events/sync',
      data: {
        'events': events
            .map((e) => {
                  'client_uuid': e.clientUuid,
                  'event_type': e.eventType,
                  'metadata': e.metadata,
                  'occurred_at': e.createdAt.toIso8601String(),
                })
            .toList(),
      },
    );

    final data = response.data;
    final results = data?['results'];
    if (results is! List) {
      throw const ApiException('Invalid BCD sync response from server');
    }

    return results
        .map((r) => BehaviorSyncResultItem.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Stream<BcdUpdateModel> getBehavioralStream(int examId) async* {
    final response = await _apiClient.dio.get<ResponseBody>(
      '/exams/$examId/behavioral-dashboard',
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      ),
    );

    final stream = response.data?.stream;
    if (stream == null) return;

    await for (final chunk in stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter())) {
      if (chunk.startsWith('data: ')) {
        final rawJson = chunk.substring(6);
        try {
          final data = jsonDecode(rawJson) as Map<String, dynamic>;
          yield BcdUpdateModel.fromJson(data);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('ExamSessionRepository: failed to decode SSE chunk: $e');
          }
        }
      }
    }
  }
}

class PendingAnswerModel {
  const PendingAnswerModel({
    required this.sessionId,
    required this.questionId,
    required this.questionText,
    required this.questionType,
    required this.maxMarks,
    required this.selectedOption,
    required this.gradingStatus,
    required this.obtainedMarks,
  });

  final int sessionId;
  final int questionId;
  final String questionText;
  final String questionType;
  final double maxMarks;
  final String selectedOption;
  final String gradingStatus;
  final double? obtainedMarks;

  factory PendingAnswerModel.fromJson(Map<String, dynamic> json) {
    return PendingAnswerModel(
      sessionId: json['session_id'] as int,
      questionId: json['question_id'] as int,
      questionText: json['question_text'] as String,
      questionType: json['question_type'] as String,
      maxMarks: (json['max_marks'] as num).toDouble(),
      selectedOption: json['selected_option'] as String,
      gradingStatus: json['grading_status'] as String,
      obtainedMarks: (json['obtained_marks'] as num?)?.toDouble(),
    );
  }
}

class SuspicionSummary {
  const SuspicionSummary({required this.score, required this.status});

  final int score;
  final String status;

  factory SuspicionSummary.fromJson(Map<String, dynamic> json) {
    return SuspicionSummary(
      score: json['suspicion_score'] as int,
      status: json['suspicion_status'] as String,
    );
  }
}

class InvigilatorSessionModel {
  const InvigilatorSessionModel({
    required this.sessionId,
    required this.candidateName,
    required this.candidateEmail,
    required this.examId,
    required this.examTitle,
    required this.courseCode,
    required this.status,
    required this.startedAt,
    required this.submittedAt,
    required this.suspicion,
  });

  final int sessionId;
  final String candidateName;
  final String candidateEmail;
  final int examId;
  final String examTitle;
  final String? courseCode;
  final String status;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final SuspicionSummary suspicion;

  factory InvigilatorSessionModel.fromJson(Map<String, dynamic> json) {
    return InvigilatorSessionModel(
      sessionId: json['session_id'] as int,
      candidateName: json['candidate_name'] as String,
      candidateEmail: json['candidate_email'] as String,
      examId: json['exam_id'] as int,
      examTitle: json['exam_title'] as String,
      courseCode: json['course_code'] as String?,
      status: json['status'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      suspicion: SuspicionSummary.fromJson(json),
    );
  }
}

class BehaviorEventEntry {
  const BehaviorEventEntry({
    required this.id,
    required this.eventType,
    required this.suspicionPoints,
    required this.occurredAt,
    this.reviewAction,
    this.reviewNote,
  });

  final int id;
  final String eventType;
  final int suspicionPoints;
  final DateTime occurredAt;
  final String? reviewAction;
  final String? reviewNote;

  factory BehaviorEventEntry.fromJson(Map<String, dynamic> json) {
    return BehaviorEventEntry(
      id: json['id'] as int,
      eventType: json['event_type'] as String,
      suspicionPoints: json['suspicion_points'] as int,
      occurredAt: DateTime.parse(json['occurred_at'] as String),
      reviewAction: json['review_action'] as String?,
      reviewNote: json['review_note'] as String?,
    );
  }
}

class BehaviorEventLog {
  const BehaviorEventLog({
    required this.sessionId,
    required this.events,
    required this.suspicion,
  });

  final int sessionId;
  final List<BehaviorEventEntry> events;
  final SuspicionSummary suspicion;

  factory BehaviorEventLog.fromJson(Map<String, dynamic> json) {
    final rawEvents = json['events'] as List<dynamic>? ?? [];
    return BehaviorEventLog(
      sessionId: json['session_id'] as int,
      events: rawEvents
          .map((e) => BehaviorEventEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      suspicion: SuspicionSummary.fromJson(json),
    );
  }
}

class AnswerSyncResultItem {
  const AnswerSyncResultItem({
    required this.questionId,
    required this.status,
    this.code,
    this.message,
  });

  final int questionId;
  final String status;
  final String? code;
  final String? message;

  bool get isSynced => status == 'synced';
  bool get isConflict => status == 'conflict';

  factory AnswerSyncResultItem.fromJson(Map<String, dynamic> json) {
    return AnswerSyncResultItem(
      questionId: json['question_id'] as int,
      status: json['status'] as String,
      code: json['code'] as String?,
      message: json['message'] as String?,
    );
  }
}

class BehaviorSyncResultItem {
  const BehaviorSyncResultItem({
    required this.clientUuid,
    required this.status,
    this.code,
    this.message,
  });

  final String clientUuid;
  final String status;
  final String? code;
  final String? message;

  bool get isSynced => status == 'synced';
  bool get isConflict => status == 'conflict';

  factory BehaviorSyncResultItem.fromJson(Map<String, dynamic> json) {
    return BehaviorSyncResultItem(
      clientUuid: json['client_uuid'] as String,
      status: json['status'] as String,
      code: json['code'] as String?,
      message: json['message'] as String?,
    );
  }
}
