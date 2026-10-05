import 'exam_question_configuration_model.dart';
import 'question_model.dart';

/// Laravel serializes `decimal` DB columns (e.g. total_marks,
/// negative_marking_weight) as JSON strings like `"100.00"` — unlike plain
/// integer columns, which come through as real JSON numbers. Accept both so
/// this doesn't break if that ever changes.
double _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value);
  throw FormatException('Expected a number, got: $value (${value.runtimeType})');
}

class ExamModel {
  final int id;
  final int createdBy;
  final int? departmentId;
  final int? semester;
  final String title;
  final String? description;
  final String? courseCode;
  final int durationMinutes;
  final double totalMarks;
  final double negativeMarkingWeight;
  final double passPercentage;
  final String status;
  final bool bcdEnabled;
  final bool randomizeQuestions;
  final bool shuffleChoices;
  final bool isOfflineReady;
  final List<String> allowedPlatforms;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final List<QuestionModel> questions;
  final List<ExamQuestionConfigurationModel> questionConfigurations;

  const ExamModel({
    required this.id,
    required this.createdBy,
    this.departmentId,
    this.semester,
    required this.title,
    this.description,
    this.courseCode,
    required this.durationMinutes,
    required this.totalMarks,
    required this.negativeMarkingWeight,
    required this.passPercentage,
    required this.status,
    required this.bcdEnabled,
    required this.randomizeQuestions,
    required this.shuffleChoices,
    required this.isOfflineReady,
    this.allowedPlatforms = const [],
    this.startsAt,
    this.endsAt,
    required this.questions,
    this.questionConfigurations = const [],
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    return ExamModel(
      id: json['id'] as int,
      createdBy: json['created_by'] as int,
      departmentId: json['department_id'] as int?,
      semester: json['semester'] as int?,
      title: json['title'] as String,
      description: json['description'] as String?,
      courseCode: json['course_code'] as String?,
      durationMinutes: json['duration_minutes'] as int,
      totalMarks: _parseDouble(json['total_marks']),
      negativeMarkingWeight: _parseDouble(json['negative_marking_weight']),
      passPercentage: _parseDouble(json['pass_percentage'] ?? 50.0),
      status: json['status'] as String,
      bcdEnabled: json['bcd_enabled'] == true || json['bcd_enabled'] == 1,
      randomizeQuestions: json['randomize_questions'] == true || json['randomize_questions'] == 1,
      shuffleChoices: json['shuffle_choices'] == true || json['shuffle_choices'] == 1,
      isOfflineReady: json['is_offline_ready'] == true || json['is_offline_ready'] == 1,
      allowedPlatforms: (json['allowed_platforms'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      startsAt: json['starts_at'] != null
          ? DateTime.tryParse(json['starts_at'].toString())
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at'].toString())
          : null,
      questionConfigurations: (json['question_configurations'] as List<dynamic>? ?? [])
          .map((item) =>
              ExamQuestionConfigurationModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      questions: (json['questions'] as List<dynamic>? ?? [])
          .map((item) =>
              QuestionModel.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}
