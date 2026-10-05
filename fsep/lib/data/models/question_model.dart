/// One left/right pair in a 'matching' question. The backend stores these
/// directly in the existing `options` JSON column (a list of
/// {left, right} objects) instead of the flat string list mcq uses there —
/// see QuestionController::validatedQuestionData.
class MatchingPair {
  const MatchingPair({required this.left, required this.right});

  final String left;
  final String right;

  factory MatchingPair.fromJson(Map<String, dynamic> json) {
    return MatchingPair(
      left: json['left'] as String,
      right: json['right'] as String,
    );
  }

  Map<String, String> toJson() => {'left': left, 'right': right};
}

class QuestionModel {
  final int id;
  final int examId;

  /// Only present on the examiner-facing Question Bank response
  /// (QuestionBankResource eager-loads the owning exam); null elsewhere.
  final String? courseCode;

  /// Null on candidate-facing responses: QuestionResource (backend)
  /// deliberately omits this field there, alongside correct_answer.
  final int? createdBy;
  final String questionText;
  final String questionType;
  final double marks;
  final String? difficulty;
  final String? bloomTaxonomy;
  final String? topicTag;

  /// mcq's option choices, or code_snippet's single-element
  /// [programming language] list. Empty for every other type, including
  /// matching — matching's pairs are in [matchingPairs] instead, since
  /// they aren't plain strings.
  final List<String> options;

  /// Only non-empty when questionType == 'matching'.
  final List<MatchingPair> matchingPairs;
  final String? correctAnswer;
  final List<String> keywords;
  final List<String> regexPatterns;
  final bool isAiGenerated;
  final bool isEdited;
  final int? generationJobId;
  final String reviewStatus;
  final int? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  const QuestionModel({
    required this.id,
    required this.examId,
    this.courseCode,
    this.createdBy,
    required this.questionText,
    required this.questionType,
    required this.marks,
    this.difficulty,
    this.bloomTaxonomy,
    this.topicTag,
    required this.options,
    this.matchingPairs = const [],
    this.correctAnswer,
    this.keywords = const [],
    this.regexPatterns = const [],
    required this.isAiGenerated,
    this.isEdited = false,
    this.generationJobId,
    required this.reviewStatus,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    final questionType = json['question_type'] as String;
    final rawOptions = json['options'] as List<dynamic>?;

    return QuestionModel(
      id: json['id'] is int ? json['id'] as int : int.parse(json['id'].toString()),
      examId: json['exam_id'] is int ? json['exam_id'] as int : int.parse(json['exam_id'].toString()),
      courseCode: json['course_code'] as String?,
      createdBy: json['created_by'] as int?,
      questionText: json['question_text'] as String,
      questionType: questionType,
      marks: json['marks'] is num ? (json['marks'] as num).toDouble() : double.parse(json['marks'].toString()),
      difficulty: json['difficulty'] as String?,
      bloomTaxonomy: json['bloom_taxonomy'] as String?,
      topicTag: json['topic_tag'] as String?,
      options: questionType == 'matching'
          ? const []
          : (rawOptions?.map((e) => e.toString()).toList() ?? const []),
      matchingPairs: questionType == 'matching'
          ? (rawOptions
                  ?.map((e) => MatchingPair.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              const [])
          : const [],
      correctAnswer: json['correct_answer'] as String?,
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      regexPatterns: (json['regex_patterns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isAiGenerated: json['is_ai_generated'] == true ||
          json['is_ai_generated'] == 1 ||
          json['is_ai_generated'] == '1',
      isEdited: json['is_edited'] == true ||
          json['is_edited'] == 1 ||
          json['is_edited'] == '1',
      generationJobId: json['generation_job_id'] as int?,
      reviewStatus: json['review_status']?.toString() ?? 'pending',
      reviewedBy: json['reviewed_by'] as int?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }
}
