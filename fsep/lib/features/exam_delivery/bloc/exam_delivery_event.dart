import 'package:equatable/equatable.dart';

abstract class ExamDeliveryEvent extends Equatable {
  const ExamDeliveryEvent();

  @override
  List<Object?> get props => [];
}

class StartExamSession extends ExamDeliveryEvent {
  const StartExamSession(this.examId);
  final int examId;

  @override
  List<Object?> get props => [examId];
}

class TimerTicked extends ExamDeliveryEvent {
  const TimerTicked(this.remainingTime);
  final Duration remainingTime;

  @override
  List<Object?> get props => [remainingTime];
}

class SelectQuestion extends ExamDeliveryEvent {
  const SelectQuestion(this.index);
  final int index;

  @override
  List<Object?> get props => [index];
}

class SaveAnswer extends ExamDeliveryEvent {
  const SaveAnswer({required this.questionId, required this.option});
  final int questionId;
  final String option;

  @override
  List<Object?> get props => [questionId, option];
}

class ToggleFlagQuestion extends ExamDeliveryEvent {
  const ToggleFlagQuestion(this.questionId);
  final int questionId;

  @override
  List<Object?> get props => [questionId];
}

class HandleProctorViolation extends ExamDeliveryEvent {
  const HandleProctorViolation(this.eventType, {this.metadata});
  final String eventType;
  final Map<String, dynamic>? metadata;

  @override
  List<Object?> get props => [eventType, metadata];
}

class SubmitExam extends ExamDeliveryEvent {
  const SubmitExam();
}
