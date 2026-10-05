import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/exam_model.dart';
import '../../../data/models/question_model.dart';
import '../../../data/models/result_model.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../data/repositories/exam_session_repository.dart';
import '../../../data/repositories/local_session_repository.dart';
import 'exam_delivery_event.dart';
import 'exam_delivery_state.dart';

class ExamDeliveryBloc extends Bloc<ExamDeliveryEvent, ExamDeliveryState> {
  ExamDeliveryBloc({
    required ExamRepository examRepository,
    required ExamSessionRepository sessionRepository,
    required LocalSessionRepository localSessionRepository,
  })  : _examRepository = examRepository,
        _sessionRepository = sessionRepository,
        _localSessionRepository = localSessionRepository,
        super(ExamDeliveryInitial()) {
    on<StartExamSession>(_onStartExamSession);
    on<TimerTicked>(_onTimerTicked);
    on<SelectQuestion>(_onSelectQuestion);
    on<SaveAnswer>(_onSaveAnswer);
    on<ToggleFlagQuestion>(_onToggleFlagQuestion);
    on<HandleProctorViolation>(_onHandleProctorViolation);
    on<SubmitExam>(_onSubmitExam);
  }

  final ExamRepository _examRepository;
  final ExamSessionRepository _sessionRepository;
  final LocalSessionRepository _localSessionRepository;

  Timer? _countdownTimer;
  DateTime? _sessionExpiresAt;
  Duration _clockOffset = Duration.zero;

  // BCD internal tracking
  final Map<int, DateTime> _questionViewStartTimes = {};
  final Map<int, DateTime> _lastAnswerTimes = {};
  int _switchCount = 0;

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    return super.close();
  }

  Future<void> _onStartExamSession(
    StartExamSession event,
    Emitter<ExamDeliveryState> emit,
  ) async {
    emit(ExamDeliveryLoading());

    try {
      final exam = await _examRepository.getExam(event.examId);
      final session = await _sessionRepository.startOrResumeSession(event.examId);

      if (session.status == 'submitted') {
        final result = await _tryFetchResult(session.id);
        emit(ExamDeliverySubmitted(result: result));
        return;
      }

      int restoredIndex = 0;
      final localRecord = await _localSessionRepository.getSessionByServerId(session.id);
      if (localRecord != null) {
        restoredIndex = localRecord.currentQuestionIndex;
      }

      _sessionExpiresAt = session.expiresAt;
      _clockOffset = session.serverTime.difference(DateTime.now());

      final remaining = _computeRemaining();

      // Randomization
      final layout = _processExamLayout(exam, session.id);

      final activeState = ExamDeliveryActive(
        exam: exam,
        sessionId: session.id,
        currentIndex: restoredIndex,
        answers: Map<int, String>.from(session.answers),
        remainingTime: remaining,
        displayQuestions: layout.questions,
        shuffledOptions: layout.shuffledOptions,
      );

      emit(activeState);

      if (remaining > Duration.zero) {
        _startTimer();
      }
    } catch (e) {
      emit(ExamDeliveryError(e.toString()));
    }
  }

  Duration _computeRemaining() {
    final expiresAt = _sessionExpiresAt;
    if (expiresAt == null) return Duration.zero;
    final estimatedServerNow = DateTime.now().add(_clockOffset);
    final remaining = expiresAt.difference(estimatedServerNow);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      add(TimerTicked(_computeRemaining()));
    });
  }

  void _onTimerTicked(TimerTicked event, Emitter<ExamDeliveryState> emit) {
    final currentState = state;
    if (currentState is ExamDeliveryActive) {
      emit(currentState.copyWith(remainingTime: event.remainingTime));
      if (event.remainingTime == Duration.zero) {
        _countdownTimer?.cancel();
        add(const SubmitExam());
      }
    }
  }

  void _onSelectQuestion(SelectQuestion event, Emitter<ExamDeliveryState> emit) async {
    final currentState = state;
    if (currentState is ExamDeliveryActive) {
      final fromId = currentState.currentIndex;
      emit(currentState.copyWith(currentIndex: event.index));

      // BCD & Persistence
      _switchCount++;
      _questionViewStartTimes[event.index] = DateTime.now();
      if (_switchCount > 15) {
        add(HandleProctorViolation('ExcessiveQuestionSwitch', metadata: {
          'from_index': fromId,
          'to_index': event.index,
          'switch_count': _switchCount,
        }));
      }

      // We need localId to update index. If missing, we find it.
      final localRecord = await _localSessionRepository.getSessionByServerId(currentState.sessionId);
      if (localRecord != null) {
        unawaited(_localSessionRepository.updateQuestionIndex(
          localId: localRecord.localId,
          questionIndex: event.index,
        ));
      }
    }
  }

  Future<void> _onSaveAnswer(SaveAnswer event, Emitter<ExamDeliveryState> emit) async {
    final currentState = state;
    if (currentState is! ExamDeliveryActive) return;

    // BCD checks
    _handleBcdOnSave(event.questionId);

    final updatedAnswers = Map<int, String>.from(currentState.answers)
      ..[event.questionId] = event.option;
    final updatedSaving = Set<int>.from(currentState.savingQuestionIds)..add(event.questionId);
    final updatedFailed = Set<int>.from(currentState.failedQuestionIds)..remove(event.questionId);

    emit(currentState.copyWith(
      answers: updatedAnswers,
      savingQuestionIds: updatedSaving,
      failedQuestionIds: updatedFailed,
    ));

    try {
      await _sessionRepository.saveAnswer(
        sessionId: currentState.sessionId,
        questionId: event.questionId,
        selectedOption: event.option,
      );
      
      final nextState = state;
      if (nextState is ExamDeliveryActive) {
        emit(nextState.copyWith(
          savingQuestionIds: Set<int>.from(nextState.savingQuestionIds)..remove(event.questionId),
        ));
      }
    } catch (e) {
      final nextState = state;
      if (nextState is ExamDeliveryActive) {
        emit(nextState.copyWith(
          savingQuestionIds: Set<int>.from(nextState.savingQuestionIds)..remove(event.questionId),
          failedQuestionIds: Set<int>.from(nextState.failedQuestionIds)..add(event.questionId),
        ));
      }
    }
  }

  void _handleBcdOnSave(int questionId) {
    if (state is! ExamDeliveryActive) return;
    final now = DateTime.now();

    // UnusualAnsweringSpeed (< 3s)
    final viewStart = _questionViewStartTimes[questionId];
    if (viewStart != null) {
      final duration = now.difference(viewStart).inSeconds;
      if (duration < 3) {
        add(HandleProctorViolation('UnusualAnsweringSpeed', metadata: {
          'question_id': questionId,
          'duration_seconds': duration,
        }));
      }
    }

    // RapidAnswerChange (< 3s between changes)
    final lastChange = _lastAnswerTimes[questionId];
    if (lastChange != null) {
      final interval = now.difference(lastChange).inSeconds;
      if (interval < 3) {
        add(HandleProctorViolation('RapidAnswerChange', metadata: {
          'question_id': questionId,
          'interval_seconds': interval,
        }));
      }
    }
    _lastAnswerTimes[questionId] = now;
  }

  void _onToggleFlagQuestion(ToggleFlagQuestion event, Emitter<ExamDeliveryState> emit) {
    final currentState = state;
    if (currentState is ExamDeliveryActive) {
      final flagged = Set<int>.from(currentState.flaggedQuestionIds);
      if (flagged.contains(event.questionId)) {
        flagged.remove(event.questionId);
      } else {
        flagged.add(event.questionId);
      }
      emit(currentState.copyWith(flaggedQuestionIds: flagged));
    }
  }

  Future<void> _onHandleProctorViolation(
    HandleProctorViolation event,
    Emitter<ExamDeliveryState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ExamDeliveryActive) return;

    try {
      final summary = await _sessionRepository.recordBehaviorEvent(
        sessionId: currentState.sessionId,
        eventType: event.eventType,
        metadata: event.metadata,
      );
      emit(currentState.copyWith(
        suspicionScore: summary.score,
        suspicionStatus: summary.status,
      ));
    } catch (e) {
      // Best-effort silent
    }
  }

  Future<void> _onSubmitExam(SubmitExam event, Emitter<ExamDeliveryState> emit) async {
    final currentState = state;
    if (currentState is! ExamDeliveryActive || currentState.isSubmitting) return;

    emit(currentState.copyWith(isSubmitting: true));

    try {
      await _sessionRepository.submitSession(currentState.sessionId);
      _countdownTimer?.cancel();
      final result = await _tryFetchResult(currentState.sessionId);
      emit(ExamDeliverySubmitted(result: result));
    } catch (e) {
      emit(currentState.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<ResultModel?> _tryFetchResult(int sessionId) async {
    try {
      return await _sessionRepository.getResult(sessionId);
    } catch (_) {
      return null;
    }
  }

  _ExamLayout _processExamLayout(ExamModel exam, int sessionId) {
    final random = Random(sessionId);
    final questions = List<QuestionModel>.from(exam.questions);
    if (exam.randomizeQuestions) {
      questions.shuffle(random);
    }

    final Map<int, List<String>> shuffledOptions = {};
    if (exam.shuffleChoices) {
      for (final q in questions) {
        if (q.questionType == 'mcq') {
          final options = List<String>.from(q.options)..shuffle(random);
          shuffledOptions[q.id] = options;
        } else if (q.questionType == 'true_false') {
          final options = ['True', 'False']..shuffle(random);
          shuffledOptions[q.id] = options;
        }
      }
    }
    return _ExamLayout(questions, shuffledOptions);
  }
}

class _ExamLayout {
  _ExamLayout(this.questions, this.shuffledOptions);
  final List<QuestionModel> questions;
  final Map<int, List<String>> shuffledOptions;
}
