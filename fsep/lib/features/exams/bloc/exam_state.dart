import '../../../data/models/exam_model.dart';

abstract class ExamState {
  const ExamState();
}

class ExamInitial extends ExamState {}

class ExamLoading extends ExamState {}

class ExamLoaded extends ExamState {
  const ExamLoaded(this.exams);

  final List<ExamModel> exams;
}

class ExamError extends ExamState {
  const ExamError(this.message);

  final String message;
}

class ExamOperationSuccess extends ExamState {
  const ExamOperationSuccess({required this.message});

  final String message;
}
