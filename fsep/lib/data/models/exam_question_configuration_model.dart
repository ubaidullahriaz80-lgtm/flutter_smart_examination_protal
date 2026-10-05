class ExamQuestionConfigurationModel {
  final int? id;
  final int? examId;
  final String questionType;
  final int questionCount;
  final String bloomTaxonomy;
  final double marks;

  const ExamQuestionConfigurationModel({
    this.id,
    this.examId,
    required this.questionType,
    required this.questionCount,
    required this.bloomTaxonomy,
    required this.marks,
  });

  factory ExamQuestionConfigurationModel.fromJson(Map<String, dynamic> json) {
    return ExamQuestionConfigurationModel(
      id: json['id'] as int?,
      examId: json['exam_id'] as int?,
      questionType: json['question_type'] as String,
      questionCount: json['question_count'] as int,
      bloomTaxonomy: json['bloom_taxonomy'] as String,
      marks: (json['marks'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (examId != null) 'exam_id': examId,
      'question_type': questionType,
      'question_count': questionCount,
      'bloom_taxonomy': bloomTaxonomy,
      'marks': marks,
    };
  }

  ExamQuestionConfigurationModel copyWith({
    int? id,
    int? examId,
    String? questionType,
    int? questionCount,
    String? bloomTaxonomy,
    double? marks,
  }) {
    return ExamQuestionConfigurationModel(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      questionType: questionType ?? this.questionType,
      questionCount: questionCount ?? this.questionCount,
      bloomTaxonomy: bloomTaxonomy ?? this.bloomTaxonomy,
      marks: marks ?? this.marks,
    );
  }
}
