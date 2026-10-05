import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/data/models/exam_model.dart';
import 'package:fsep/data/models/exam_session_model.dart';
import 'package:fsep/data/repositories/exam_repository.dart';
import 'package:fsep/data/repositories/exam_session_repository.dart';
import 'package:fsep/data/repositories/local_session_repository.dart';
import 'package:fsep/features/exam_delivery/bloc/exam_delivery_bloc.dart';
import 'package:fsep/features/exam_delivery/bloc/exam_delivery_event.dart';
import 'package:fsep/features/exam_delivery/bloc/exam_delivery_state.dart';

class _FakeExamRepository extends ExamRepository {
  @override
  Future<ExamModel> getExam(int examId) async {
    return const ExamModel(
      id: 1,
      createdBy: 1,
      title: 'Test',
      durationMinutes: 60,
      totalMarks: 100,
      negativeMarkingWeight: 0,
      passPercentage: 50,
      status: 'published',
      bcdEnabled: true,
      randomizeQuestions: false,
      shuffleChoices: false,
      isOfflineReady: false,
      questions: [],
    );
  }
}

class _FakeExamSessionRepository extends ExamSessionRepository {
  bool saveAnswerCalled = false;

  @override
  Future<ExamSessionModel> startOrResumeSession(int examId) async {
    return ExamSessionModel(
      id: 1,
      examId: 1,
      status: 'in_progress',
      startedAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      serverTime: DateTime.now(),
      answers: {},
    );
  }

  @override
  Future<void> saveAnswer({
    required int sessionId,
    required int questionId,
    required String selectedOption,
  }) async {
    saveAnswerCalled = true;
  }

  @override
  Future<SuspicionSummary> recordBehaviorEvent({
    required int sessionId,
    required String eventType,
    Map<String, dynamic>? metadata,
  }) async {
    return const SuspicionSummary(score: 0, status: 'low');
  }
}

class _FakeLocalSessionRepository extends LocalSessionRepository {
  @override
  Future<void> updateQuestionIndex({
    required int localId,
    required int questionIndex,
  }) async {}

  @override
  Future<LocalSessionRecord?> getSessionByServerId(int serverSessionId) async => null;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('initial state is ExamDeliveryInitial', () {
    final bloc = ExamDeliveryBloc(
      examRepository: _FakeExamRepository(),
      sessionRepository: _FakeExamSessionRepository(),
      localSessionRepository: _FakeLocalSessionRepository(),
    );
    expect(bloc.state, isA<ExamDeliveryInitial>());
    bloc.close();
  });

  group('StartExamSession', () {
    test('emits [Loading, Active] on success', () async {
      final bloc = ExamDeliveryBloc(
        examRepository: _FakeExamRepository(),
        sessionRepository: _FakeExamSessionRepository(),
        localSessionRepository: _FakeLocalSessionRepository(),
      );

      final states = <ExamDeliveryState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const StartExamSession(1));
      await _flush();

      expect(states, [
        isA<ExamDeliveryLoading>(),
        isA<ExamDeliveryActive>(),
      ]);

      await sub.cancel();
      await bloc.close();
    });
  });

  group('SaveAnswer', () {
    test('updates state and calls repository', () async {
      final sessionRepo = _FakeExamSessionRepository();
      final bloc = ExamDeliveryBloc(
        examRepository: _FakeExamRepository(),
        sessionRepository: sessionRepo,
        localSessionRepository: _FakeLocalSessionRepository(),
      );

      final states = <ExamDeliveryState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const StartExamSession(1));
      await _flush();

      bloc.add(const SaveAnswer(questionId: 10, option: 'A'));
      await _flush();

      // Check if state contains the answer
      final active = states.lastWhere((s) => s is ExamDeliveryActive) as ExamDeliveryActive;
      expect(active.answers[10], 'A');
      expect(sessionRepo.saveAnswerCalled, isTrue);

      await sub.cancel();
      await bloc.close();
    });
  });
}
