import 'package:equatable/equatable.dart';
import '../../../data/models/question_model.dart';

abstract class QuestionState extends Equatable {
  const QuestionState();

  @override
  List<Object?> get props => [];
}

class QuestionInitial extends QuestionState {}

class QuestionLoading extends QuestionState {}

class QuestionLoaded extends QuestionState {
  const QuestionLoaded(this.questions);
  final List<QuestionModel> questions;

  @override
  List<Object?> get props => [questions];
}

class QuestionError extends QuestionState {
  const QuestionError(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}

class QuestionOperationSuccess extends QuestionState {
  const QuestionOperationSuccess({required this.message});
  final String message;

  @override
  List<Object?> get props => [message];
}
