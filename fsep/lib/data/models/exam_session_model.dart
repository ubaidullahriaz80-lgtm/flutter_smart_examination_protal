/// A candidate's exam attempt (POST /exams/{exam}/session), including any
/// answers already saved for it — used to restore selections when the
/// delivery screen is reopened, not just to survive an in-memory rebuild.
class ExamSessionModel {
  const ExamSessionModel({
    required this.id,
    required this.examId,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    required this.serverTime,
    required this.answers,
  });

  final int id;
  final int examId;
  final String status;

  /// The moment this session was actually first created.
  final DateTime startedAt;

  /// Server-authoritative deadline for this attempt.
  final DateTime expiresAt;

  /// The server's own clock at the moment this session was returned.
  final DateTime serverTime;

  /// question id -> previously saved selected option.
  final Map<int, String> answers;

  factory ExamSessionModel.fromJson(Map<String, dynamic> json) {
    final answersJson = json['answers'] as List<dynamic>? ?? [];

    final answers = <int, String>{
      for (final item in answersJson)
        (item as Map<String, dynamic>)['question_id'] as int:
            item['selected_option'] as String,
    };

    return ExamSessionModel(
      id: json['id'] as int,
      examId: json['exam_id'] as int,
      status: json['status'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      serverTime: DateTime.parse(json['server_time'] as String),
      answers: answers,
    );
  }
}
