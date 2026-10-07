class GeneratedQuestionDraft {
  const GeneratedQuestionDraft({
    required this.examId,
    required this.questionText,
    required this.questionType,
    required this.marks,
    required this.difficulty,
    required this.bloomTaxonomy,
    this.topicTag,
    required this.options,
    this.correctAnswer,
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
  final List<Object> options;
  final String? correctAnswer;
  final List<String> keywords;
  final List<String> regexPatterns;
  final bool isAiGenerated;

  factory GeneratedQuestionDraft.fromJson(Map<String, dynamic> json) {
    return GeneratedQuestionDraft(
      examId: (json['exam_id'] as num?)?.toInt() ?? 0,
      questionText: json['question_text'] as String? ?? '',
      questionType: json['question_type'] as String? ?? 'short_answer',
      marks: (json['marks'] as num?)?.toInt() ?? 1,
      difficulty: json['difficulty'] as String? ?? 'medium',
      bloomTaxonomy: json['bloom_taxonomy'] as String? ?? 'understand',
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
      isAiGenerated: json['is_ai_generated'] == true || json['is_ai_generated'] == 1,
    );
  }
}
