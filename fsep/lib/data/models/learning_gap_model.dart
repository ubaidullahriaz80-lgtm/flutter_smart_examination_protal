class LearningGapModel {
  const LearningGapModel({
    required this.topic,
    required this.courseCode,
    required this.questionsAttempted,
    required this.correctAnswers,
    required this.obtainedMarks,
    required this.totalMarks,
    required this.percentage,
    required this.severity,
    required this.explanation,
    required this.bloomBreakdown,
  });

  final String topic;
  final String? courseCode;
  final int questionsAttempted;
  final int correctAnswers;
  final num obtainedMarks;
  final num totalMarks;
  final double percentage;
  final String severity;
  final String explanation;
  final Map<String, double?> bloomBreakdown;

  factory LearningGapModel.fromJson(Map<String, dynamic> json) {
    final bloom = json['bloom_breakdown'] as Map<String, dynamic>? ?? {};

    return LearningGapModel(
      topic: json['topic'] as String,
      courseCode: json['course_code'] as String?,
      questionsAttempted: json['questions_attempted'] as int? ?? 0,
      correctAnswers: json['correct_answers'] as int? ?? 0,
      obtainedMarks: json['obtained_marks'] as num,
      totalMarks: json['total_marks'] as num,
      percentage: (json['percentage'] as num).toDouble(),
      severity: json['severity'] as String,
      explanation: json['explanation'] as String,
      bloomBreakdown: bloom.map((k, v) => MapEntry(k, v != null ? (v as num).toDouble() : null)),
    );
  }
}

class RoadmapStep {
  const RoadmapStep({
    required this.rank,
    required this.topic,
    required this.mastery,
    required this.severity,
    required this.bloomBreakdown,
    required this.suggestion,
  });

  final int rank;
  final String topic;
  final double mastery;
  final String severity;
  final Map<String, double?> bloomBreakdown;
  final String suggestion;

  factory RoadmapStep.fromJson(Map<String, dynamic> json) {
    final bloom = json['bloom_breakdown'] as Map<String, dynamic>? ?? {};
    return RoadmapStep(
      rank: json['rank'] as int,
      topic: json['topic'] as String,
      mastery: (json['mastery'] as num).toDouble(),
      severity: json['severity'] as String,
      bloomBreakdown: bloom.map((k, v) => MapEntry(k, v != null ? (v as num).toDouble() : null)),
      suggestion: json['suggestion'] as String,
    );
  }
}

class LearningGapReport {
  const LearningGapReport({
    required this.gaps,
    required this.allTopics,
    required this.topicsAnalyzed,
    required this.questionsAttempted,
    required this.bloomProfile,
    required this.difficultyProfile,
    required this.improvementRoadmap,
  });

  final List<LearningGapModel> gaps;
  final List<LearningGapModel> allTopics;
  final int topicsAnalyzed;
  final int questionsAttempted;
  final Map<String, double?> bloomProfile;
  final Map<String, double?> difficultyProfile;
  final List<RoadmapStep> improvementRoadmap;

  factory LearningGapReport.fromJson(Map<String, dynamic> json) {
    final gapsJson = json['learning_gaps'] as List<dynamic>? ?? [];
    final allTopicsJson = json['all_topics'] as List<dynamic>? ?? [];
    final roadmapJson = json['improvement_roadmap'] as List<dynamic>? ?? [];

    final bloom = json['bloom_profile'] as Map<String, dynamic>? ?? {};
    final difficulty = json['difficulty_profile'] as Map<String, dynamic>? ?? {};

    return LearningGapReport(
      gaps: gapsJson
          .map((g) => LearningGapModel.fromJson(g as Map<String, dynamic>))
          .toList(),
      allTopics: allTopicsJson
          .map((g) => LearningGapModel.fromJson(g as Map<String, dynamic>))
          .toList(),
      topicsAnalyzed: json['topics_analyzed'] as int? ?? 0,
      questionsAttempted: json['questions_attempted'] as int? ?? 0,
      bloomProfile: bloom.map((k, v) => MapEntry(k, v != null ? (v as num).toDouble() : null)),
      difficultyProfile: difficulty.map((k, v) => MapEntry(k, v != null ? (v as num).toDouble() : null)),
      improvementRoadmap: roadmapJson.map((s) => RoadmapStep.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}
