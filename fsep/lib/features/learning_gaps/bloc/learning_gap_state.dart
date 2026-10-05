import '../../../data/models/learning_gap_model.dart';

abstract class LearningGapState {
  const LearningGapState();
}

class LearningGapInitial extends LearningGapState {}

class LearningGapLoading extends LearningGapState {}

class LearningGapLoaded extends LearningGapState {
  const LearningGapLoaded(this.report);

  final LearningGapReport report;
}

class LearningGapError extends LearningGapState {
  const LearningGapError(this.message);

  final String message;
}
