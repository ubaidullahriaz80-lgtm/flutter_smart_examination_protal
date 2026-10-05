import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/data/models/question_model.dart';
import 'package:fsep/data/models/generated_question_draft.dart';
import 'package:fsep/data/repositories/question_bank_repository.dart';
import 'package:fsep/features/question_bank/bloc/question_bloc.dart';
import 'package:fsep/features/question_bank/bloc/question_event.dart';
import 'package:fsep/features/question_bank/bloc/question_state.dart';

class _MockQuestionBankRepository extends QuestionBankRepository {
  _MockQuestionBankRepository({this.shouldFail = false, this.questions = const []});
  final bool shouldFail;
  final List<QuestionModel> questions;

  @override
  Future<List<QuestionModel>> getQuestions({int? examId}) async {
    if (shouldFail) throw Exception('failed');
    return questions;
  }

  @override
  Future<QuestionModel> createQuestion(GeneratedQuestionDraft draft) async {
    if (shouldFail) throw Exception('failed');
    return QuestionModel(
      id: 1,
      examId: draft.examId,
      questionText: draft.questionText,
      questionType: draft.questionType,
      marks: draft.marks.toDouble(),
      reviewStatus: 'pending',
      options: const [],
      isAiGenerated: draft.isAiGenerated,
    );
  }

  @override
  Future<void> deleteQuestion(int id) async {
    if (shouldFail) throw Exception('failed');
  }
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  const mockQuestion = QuestionModel(
    id: 1,
    examId: 1,
    questionText: 'Test',
    questionType: 'mcq',
    marks: 1,
    reviewStatus: 'approved',
    options: [],
    isAiGenerated: false,
  );

  test('initial state is QuestionInitial', () {
    final bloc = QuestionBloc(repository: _MockQuestionBankRepository());
    expect(bloc.state, isA<QuestionInitial>());
    bloc.close();
  });

  group('LoadQuestions', () {
    test('emits [Loading, Loaded] on success', () async {
      final bloc = QuestionBloc(repository: _MockQuestionBankRepository(questions: [mockQuestion]));
      final states = <QuestionState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadQuestions());
      await _flush();

      expect(states, [isA<QuestionLoading>(), isA<QuestionLoaded>()]);
      await sub.cancel();
      bloc.close();
    });

    test('emits [Loading, Error] on failure', () async {
      final bloc = QuestionBloc(repository: _MockQuestionBankRepository(shouldFail: true));
      final states = <QuestionState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadQuestions());
      await _flush();

      expect(states, [isA<QuestionLoading>(), isA<QuestionError>()]);
      await sub.cancel();
      bloc.close();
    });
  });

  group('DeleteQuestion', () {
    test('emits [OperationSuccess] on success', () async {
      final bloc = QuestionBloc(repository: _MockQuestionBankRepository());
      final states = <QuestionState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const DeleteQuestion(1));
      await _flush();

      expect(states, [isA<QuestionOperationSuccess>()]);
      await sub.cancel();
      bloc.close();
    });
  });
}
