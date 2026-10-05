import 'package:equatable/equatable.dart';
import '../../../data/models/generated_question_draft.dart';

abstract class AiGeneratorEvent extends Equatable {
  const AiGeneratorEvent();

  @override
  List<Object?> get props => [];
}

class AiGeneratorGenerateFromTopic extends AiGeneratorEvent {
  const AiGeneratorGenerateFromTopic({
    required this.examIds,
    required this.topic,
    required this.questionTypes,
    required this.difficulty,
    required this.bloomTaxonomy,
    required this.count,
    required this.marks,
  });

  final List<int> examIds;
  final String topic;
  final List<String> questionTypes;
  final String difficulty;
  final String bloomTaxonomy;
  final int count;
  final int marks;

  @override
  List<Object?> get props => [examIds, topic, questionTypes, difficulty, bloomTaxonomy, count, marks];
}

class AiGeneratorUploadDocuments extends AiGeneratorEvent {
  const AiGeneratorUploadDocuments({
    required this.filePaths,
    required this.examIds,
    required this.questionTypes,
    required this.difficulty,
    required this.bloomTaxonomy,
    required this.count,
    required this.marks,
  });

  final List<String> filePaths;
  final List<int> examIds;
  final List<String> questionTypes;
  final String difficulty;
  final String bloomTaxonomy;
  final int count;
  final int marks;

  @override
  List<Object?> get props => [filePaths, examIds, questionTypes, difficulty, bloomTaxonomy, count, marks];
}

class AiGeneratorPollJobStatus extends AiGeneratorEvent {
  const AiGeneratorPollJobStatus(this.jobId);
  final int jobId;

  @override
  List<Object?> get props => [jobId];
}

class AiGeneratorSaveDraft extends AiGeneratorEvent {
  const AiGeneratorSaveDraft(this.draft, this.index);
  final GeneratedQuestionDraft draft;
  final int index;

  @override
  List<Object?> get props => [draft, index];
}

class AiGeneratorDiscardDraft extends AiGeneratorEvent {
  const AiGeneratorDiscardDraft(this.index);
  final int index;

  @override
  List<Object?> get props => [index];
}
