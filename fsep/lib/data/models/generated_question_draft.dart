/// A single AI-generated question, returned by POST /questions/generate
/// for preview only — it has no `id`/`review_status` because it has not
/// been saved to the Question Bank yet. Saving it (via
/// QuestionBankRepository.createQuestion) is a separate, explicit step so
/// generated output always goes through review before candidates can see
/// it, per the existing Question Bank review_status workflow.
class GeneratedQuestionDraft {
  const GeneratedQuestionDraft({
    required this.examId,
    required this.questionText,
    required this.questionType,
    required this.marks,
    required this.difficulty,
    required this.bloomTaxonomy,
    required this.topicTag,
    required this.options,
    required this.correctAnswer,
    this.keywords = const [],
    this.regexPatterns = const [],
    required this.isAiGenerated,
  });

  final int examId;
  final String questionText;
  final String questionType;
  final int marks;
  final String difficulty;
  final String bloomTaxonomy;
  final String? topicTag;

  /// A flat string list for every AI-generatable type (mcq's choices,
  /// code_snippet's single-element [language] list). Manual creation of a
  /// 'matching' question (never AI-generated) is the one case that puts
  /// {left, right} maps here instead — typed as Object rather than String
  /// so both shapes fit without a second field, since this class's only
  /// job is to carry values straight into the existing POST /questions
  /// body.
  final List<Object> options;
  final String? correctAnswer;
  final List<String> keywords;
  final List<String> regexPatterns;
  final bool isAiGenerated;

  factory GeneratedQuestionDraft.fromJson(Map<String, dynamic> json) {
    return GeneratedQuestionDraft(
      examId: json['exam_id'] as int,
      questionText: json['question_text'] as String,
      questionType: json['question_type'] as String,
      marks: json['marks'] as int,
      difficulty: json['difficulty'] as String,
      bloomTaxonomy: json['bloom_taxonomy'] as String,
      topicTag: json['topic_tag'] as String?,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      correctAnswer: json['correct_answer'] as String?,
      keywords: (json['keywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      regexPatterns: (json['regex_patterns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      isAiGenerated: json['is_ai_generated'] == true,
    );
  }
}
