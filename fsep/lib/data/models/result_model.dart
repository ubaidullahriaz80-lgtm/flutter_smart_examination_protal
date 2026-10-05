class ResultModel {
  const ResultModel({
    required this.sessionId,
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.percentile,
    required this.passFail,
    required this.status,
    required this.gradedAt,
    required this.questionResults,
  });

  final int sessionId;
  final double totalScore;
  final double maxScore;
  final double percentage;
  final double percentile;
  final String passFail;
  final String status;
  final DateTime gradedAt;
  final List<QuestionResultModel> questionResults;

  bool get isPendingManualReview => status == 'pending_manual_review';

  factory ResultModel.fromJson(Map<String, dynamic> json) {
    final questionResultsJson =
        json['question_results'] as List<dynamic>? ?? [];

    return ResultModel(
      sessionId: json['session_id'] as int,
      totalScore: (json['total_score'] as num).toDouble(),
      maxScore: (json['max_score'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
      percentile: (json['percentile'] as num).toDouble(),
      passFail: json['pass_fail'] as String,
      status: json['status'] as String,
      gradedAt: DateTime.parse(json['graded_at'] as String),
      questionResults: questionResultsJson
          .map((q) =>
              QuestionResultModel.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuestionResultModel {
  const QuestionResultModel({
    required this.questionId,
    required this.isCorrect,
    required this.obtainedMarks,
  });

  final int questionId;
  final bool? isCorrect;
  final double? obtainedMarks;

  factory QuestionResultModel.fromJson(Map<String, dynamic> json) {
    return QuestionResultModel(
      questionId: json['question_id'] as int,
      isCorrect: json['is_correct'] as bool?,
      obtainedMarks: (json['obtained_marks'] as num?)?.toDouble(),
    );
  }
}
