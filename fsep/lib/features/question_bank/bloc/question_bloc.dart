import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/question_bank_repository.dart';
import 'question_event.dart';
import 'question_state.dart';

class QuestionBloc extends Bloc<QuestionEvent, QuestionState> {
  QuestionBloc({required QuestionBankRepository repository})
      : _repository = repository,
        super(QuestionInitial()) {
    on<LoadQuestions>(_onLoadQuestions);
    on<RefreshQuestions>(_onRefreshQuestions);
    on<CreateQuestion>(_onCreateQuestion);
    on<UpdateQuestion>(_onUpdateQuestion);
    on<DeleteQuestion>(_onDeleteQuestion);
    on<LoadReviewQueue>(_onLoadReviewQueue);
    on<BulkReviewQuestions>(_onBulkReviewQuestions);
  }

  final QuestionBankRepository _repository;

  Future<void> _onLoadQuestions(LoadQuestions event, Emitter<QuestionState> emit) async {
    emit(QuestionLoading());
    try {
      final questions = await _repository.getQuestions(examId: event.examId);
      emit(QuestionLoaded(questions));
    } catch (e) {
      emit(QuestionError(e.toString()));
    }
  }

  Future<void> _onRefreshQuestions(RefreshQuestions event, Emitter<QuestionState> emit) async {
    try {
      final questions = await _repository.getQuestions(examId: event.examId);
      emit(QuestionLoaded(questions));
    } catch (e) {
      emit(QuestionError(e.toString()));
    }
  }

  Future<void> _onCreateQuestion(CreateQuestion event, Emitter<QuestionState> emit) async {
    emit(QuestionLoading());
    try {
      await _repository.createQuestion(event.draft);
      emit(const QuestionOperationSuccess(message: 'Question created successfully'));
    } catch (e) {
      emit(QuestionError(e.toString()));
    }
  }

  Future<void> _onUpdateQuestion(UpdateQuestion event, Emitter<QuestionState> emit) async {
    emit(QuestionLoading());
    try {
      await _repository.updateQuestion(
        event.question,
        reviewStatus: event.reviewStatus,
        rejectionReason: event.rejectionReason,
      );
      emit(const QuestionOperationSuccess(message: 'Question updated successfully'));
    } catch (e) {
      emit(QuestionError(e.toString()));
    }
  }

  Future<void> _onDeleteQuestion(DeleteQuestion event, Emitter<QuestionState> emit) async {
    try {
      await _repository.deleteQuestion(event.questionId);
      // After deletion, we refresh the list if we are in bank view.
      // The view will typically handle what happens next.
      emit(const QuestionOperationSuccess(message: 'Question deleted successfully'));
    } catch (e) {
      emit(QuestionError(e.toString()));
    }
  }

  Future<void> _onLoadReviewQueue(LoadReviewQueue event, Emitter<QuestionState> emit) async {
    emit(QuestionLoading());
    try {
      final questions = await _repository.getReviewQueue(event.jobId);
      emit(QuestionLoaded(questions));
    } catch (e) {
      emit(QuestionError(e.toString()));
    }
  }

  Future<void> _onBulkReviewQuestions(BulkReviewQuestions event, Emitter<QuestionState> emit) async {
    emit(QuestionLoading());
    try {
      await _repository.bulkReviewQuestions(
        questionIds: event.questionIds,
        action: event.action,
        rejectionReason: event.rejectionReason,
      );
      // Reload the queue after bulk action
      final questions = await _repository.getReviewQueue(event.jobId);
      emit(QuestionLoaded(questions));
    } catch (e) {
      emit(QuestionError(e.toString()));
    }
  }
}
