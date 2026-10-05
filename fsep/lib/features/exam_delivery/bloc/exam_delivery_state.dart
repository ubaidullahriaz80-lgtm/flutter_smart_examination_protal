import '../../../data/models/exam_model.dart';
import '../../../data/models/question_model.dart';
import '../../../data/models/result_model.dart';

abstract class ExamDeliveryState {
  const ExamDeliveryState();
}

class ExamDeliveryInitial extends ExamDeliveryState {}

class ExamDeliveryLoading extends ExamDeliveryState {}

class ExamDeliveryActive extends ExamDeliveryState {
  const ExamDeliveryActive({
    required this.exam,
    required this.sessionId,
    this.currentIndex = 0,
    this.answers = const {},
    this.flaggedQuestionIds = const {},
    required this.remainingTime,
    this.suspicionScore = 0,
    this.suspicionStatus = 'normal',
    this.isSubmitting = false,
    this.errorMessage,
    this.savingQuestionIds = const {},
    this.failedQuestionIds = const {},
    this.displayQuestions,
    this.shuffledOptions = const {},
  });

  final ExamModel exam;
  final int sessionId;
  final int currentIndex;
  final Map<int, String> answers;
  final Set<int> flaggedQuestionIds;
  final Duration remainingTime;
  final int suspicionScore;
  final String suspicionStatus;
  final bool isSubmitting;
  final String? errorMessage;
  final Set<int> savingQuestionIds;
  final Set<int> failedQuestionIds;

  /// Ordered list of questions (after randomization)
  final List<QuestionModel>? displayQuestions;

  /// Map of question id to shuffled option list
  final Map<int, List<String>> shuffledOptions;

  bool get isExpired => remainingTime == Duration.zero;

  ExamDeliveryActive copyWith({
    ExamModel? exam,
    int? sessionId,
    int? currentIndex,
    Map<int, String>? answers,
    Set<int>? flaggedQuestionIds,
    Duration? remainingTime,
    int? suspicionScore,
    String? suspicionStatus,
    bool? isSubmitting,
    String? errorMessage,
    Set<int>? savingQuestionIds,
    Set<int>? failedQuestionIds,
    List<QuestionModel>? displayQuestions,
    Map<int, List<String>>? shuffledOptions,
  }) {
    return ExamDeliveryActive(
      exam: exam ?? this.exam,
      sessionId: sessionId ?? this.sessionId,
      currentIndex: currentIndex ?? this.currentIndex,
      answers: answers ?? this.answers,
      flaggedQuestionIds: flaggedQuestionIds ?? this.flaggedQuestionIds,
      remainingTime: remainingTime ?? this.remainingTime,
      suspicionScore: suspicionScore ?? this.suspicionScore,
      suspicionStatus: suspicionStatus ?? this.suspicionStatus,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage ?? this.errorMessage,
      savingQuestionIds: savingQuestionIds ?? this.savingQuestionIds,
      failedQuestionIds: failedQuestionIds ?? this.failedQuestionIds,
      displayQuestions: displayQuestions ?? this.displayQuestions,
      shuffledOptions: shuffledOptions ?? this.shuffledOptions,
    );
  }
}

class ExamDeliverySubmitted extends ExamDeliveryState {
  const ExamDeliverySubmitted({this.result});
  final ResultModel? result;
}

class ExamDeliveryError extends ExamDeliveryState {
  const ExamDeliveryError(this.message);
  final String message;
}
