/// GET /api/analytics/cohort?exam_id= — read-only aggregate over the
/// existing ExamSession/Result data. No score here is recalculated; it's
/// all sourced from the same Result rows GradingService already wrote.
class CohortAnalytics {
  const CohortAnalytics({
    required this.summary,
    required this.examStatistics,
    required this.scoreDistribution,
    required this.behavioralRiskDistribution,
    required this.deviceReliability,
  });

  final CohortSummary summary;
  final List<ExamStatistic> examStatistics;
  final List<ScoreDistributionBucket> scoreDistribution;
  final List<ScoreDistributionBucket> behavioralRiskDistribution;
  final DeviceReliability deviceReliability;

  factory CohortAnalytics.fromJson(Map<String, dynamic> json) {
    return CohortAnalytics(
      summary: CohortSummary.fromJson(json['summary'] as Map<String, dynamic>),
      examStatistics: (json['exam_statistics'] as List<dynamic>)
          .map((e) => ExamStatistic.fromJson(e as Map<String, dynamic>))
          .toList(),
      scoreDistribution: (json['score_distribution'] as List<dynamic>)
          .map((e) => ScoreDistributionBucket.fromJson(e as Map<String, dynamic>))
          .toList(),
      behavioralRiskDistribution: (json['behavioral_risk_distribution'] as List<dynamic>?)
              ?.map((e) => ScoreDistributionBucket.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      deviceReliability: DeviceReliability.fromJson(
        json['device_reliability'] as Map<String, dynamic>? ??
            {'reliable_sessions_count': 0, 'reliability_rate': 0.0},
      ),
    );
  }
}

class DeviceReliability {
  const DeviceReliability({
    required this.reliableSessionsCount,
    required this.reliabilityRate,
  });

  final int reliableSessionsCount;
  final double reliabilityRate;

  factory DeviceReliability.fromJson(Map<String, dynamic> json) {
    return DeviceReliability(
      reliableSessionsCount: json['reliable_sessions_count'] as int,
      reliabilityRate: (json['reliability_rate'] as num).toDouble(),
    );
  }
}

class CohortSummary {
  const CohortSummary({
    required this.examId,
    required this.examTitle,
    required this.candidateCount,
    required this.totalEligibleCandidates,
    required this.completionRate,
    required this.submissionCount,
    required this.pendingManualReviewCount,
    required this.averageScore,
    required this.averagePercentage,
    required this.highestPercentage,
    required this.lowestPercentage,
    required this.medianCompletionTime,
  });

  final int? examId;
  final String? examTitle;
  final int candidateCount;
  final int totalEligibleCandidates;
  final double completionRate;
  final int submissionCount;
  final int pendingManualReviewCount;
  final double? averageScore;
  final double? averagePercentage;
  final double? highestPercentage;
  final double? lowestPercentage;
  final double? medianCompletionTime;

  factory CohortSummary.fromJson(Map<String, dynamic> json) {
    return CohortSummary(
      examId: json['exam_id'] as int?,
      examTitle: json['exam_title'] as String?,
      candidateCount: json['candidate_count'] as int,
      totalEligibleCandidates: json['total_eligible_candidates'] as int? ?? 0,
      completionRate: (json['completion_rate'] as num? ?? 0.0).toDouble(),
      submissionCount: json['submission_count'] as int,
      pendingManualReviewCount: json['pending_manual_review_count'] as int,
      averageScore: (json['average_score'] as num?)?.toDouble(),
      averagePercentage: (json['average_percentage'] as num?)?.toDouble(),
      highestPercentage: (json['highest_percentage'] as num?)?.toDouble(),
      lowestPercentage: (json['lowest_percentage'] as num?)?.toDouble(),
      medianCompletionTime: (json['median_completion_time'] as num?)?.toDouble(),
    );
  }
}

class ExamStatistic {
  const ExamStatistic({
    required this.examId,
    required this.examTitle,
    required this.courseCode,
    required this.submissionCount,
    required this.averageMarks,
    required this.averagePercentage,
    required this.highestScore,
    required this.lowestScore,
  });

  final int examId;
  final String examTitle;
  final String? courseCode;
  final int submissionCount;
  final double? averageMarks;
  final double? averagePercentage;
  final double? highestScore;
  final double? lowestScore;

  factory ExamStatistic.fromJson(Map<String, dynamic> json) {
    return ExamStatistic(
      examId: json['exam_id'] as int,
      examTitle: json['exam_title'] as String,
      courseCode: json['course_code'] as String?,
      submissionCount: json['submission_count'] as int,
      averageMarks: (json['average_marks'] as num?)?.toDouble(),
      averagePercentage: (json['average_percentage'] as num?)?.toDouble(),
      highestScore: (json['highest_score'] as num?)?.toDouble(),
      lowestScore: (json['lowest_score'] as num?)?.toDouble(),
    );
  }
}

class ScoreDistributionBucket {
  const ScoreDistributionBucket({required this.range, required this.count});

  final String range;
  final int count;

  factory ScoreDistributionBucket.fromJson(Map<String, dynamic> json) {
    return ScoreDistributionBucket(
      range: json['range'] as String,
      count: json['count'] as int,
    );
  }
}
