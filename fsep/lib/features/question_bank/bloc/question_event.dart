import 'package:equatable/equatable.dart';
import '../../../data/models/question_model.dart';
import '../../../data/models/generated_question_draft.dart';

abstract class QuestionEvent extends Equatable {
  const QuestionEvent();

  @override
  List<Object?> get props => [];
}

class LoadQuestions extends QuestionEvent {
  const LoadQuestions({this.examId});
  final int? examId;

  @override
  List<Object?> get props => [examId];
}

class RefreshQuestions extends QuestionEvent {
  const RefreshQuestions({this.examId});
  final int? examId;

  @override
  List<Object?> get props => [examId];
}

class CreateQuestion extends QuestionEvent {
  const CreateQuestion(this.draft);
  final GeneratedQuestionDraft draft;

  @override
  List<Object?> get props => [draft];
}

class UpdateQuestion extends QuestionEvent {
  const UpdateQuestion(this.question, {required this.reviewStatus, this.rejectionReason});
  final QuestionModel question;
  final String reviewStatus;
  final String? rejectionReason;

  @override
  List<Object?> get props => [question, reviewStatus, rejectionReason];
}

class DeleteQuestion extends QuestionEvent {
  const DeleteQuestion(this.questionId);
  final int questionId;

  @override
  List<Object?> get props => [questionId];
}

class LoadReviewQueue extends QuestionEvent {
  const LoadReviewQueue(this.jobId);
  final int jobId;

  @override
  List<Object?> get props => [jobId];
}

class BulkReviewQuestions extends QuestionEvent {
  const BulkReviewQuestions({
    required this.jobId,
    required this.questionIds,
    required this.action,
    this.rejectionReason,
  });
  final int jobId;
  final List<int> questionIds;
  final String action;
  final String? rejectionReason;

  @override
  List<Object?> get props => [jobId, questionIds, action, rejectionReason];
}
