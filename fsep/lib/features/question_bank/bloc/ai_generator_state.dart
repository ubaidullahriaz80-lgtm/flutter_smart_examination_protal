import 'package:equatable/equatable.dart';
import '../../../data/models/generated_question_draft.dart';

abstract class AiGeneratorState extends Equatable {
  const AiGeneratorState();

  @override
  List<Object?> get props => [];
}

class AiGeneratorInitial extends AiGeneratorState {}

class AiGeneratorLoading extends AiGeneratorState {}

class AiGeneratorResultReady extends AiGeneratorState {
  const AiGeneratorResultReady({
    required this.drafts,
    this.savingIndexes = const {},
    this.savedIndexes = const {},
  });

  final List<GeneratedQuestionDraft> drafts;
  final Set<int> savingIndexes;
  final Set<int> savedIndexes;

  @override
  List<Object?> get props => [drafts, savingIndexes, savedIndexes];

  AiGeneratorResultReady copyWith({
    List<GeneratedQuestionDraft>? drafts,
    Set<int>? savingIndexes,
    Set<int>? savedIndexes,
  }) {
    return AiGeneratorResultReady(
      drafts: drafts ?? this.drafts,
      savingIndexes: savingIndexes ?? this.savingIndexes,
      savedIndexes: savedIndexes ?? this.savedIndexes,
    );
  }
}

class AiGeneratorJobStarted extends AiGeneratorState {
  const AiGeneratorJobStarted({required this.jobId, required this.status});
  final int jobId;
  final String status;

  @override
  List<Object?> get props => [jobId, status];
}

class AiGeneratorError extends AiGeneratorState {
  const AiGeneratorError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class AiGeneratorSuccess extends AiGeneratorState {
  const AiGeneratorSuccess({required this.message});
  final String message;

  @override
  List<Object?> get props => [message];
}
