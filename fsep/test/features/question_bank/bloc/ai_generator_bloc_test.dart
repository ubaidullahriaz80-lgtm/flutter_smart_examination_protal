import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/data/models/generated_question_draft.dart';
import 'package:fsep/data/repositories/question_bank_repository.dart';
import 'package:fsep/features/question_bank/bloc/ai_generator_bloc.dart';
import 'package:fsep/features/question_bank/bloc/ai_generator_event.dart';
import 'package:fsep/features/question_bank/bloc/ai_generator_state.dart';

class _MockAiRepository extends QuestionBankRepository {
  _MockAiRepository({this.shouldFail = false, this.drafts = const []});
  final bool shouldFail;
  final List<GeneratedQuestionDraft> drafts;

  @override
  Future<List<GeneratedQuestionDraft>> generateQuestions({
    required List<int> examIds,
    required String topic,
    required List<String> questionTypes,
    required String difficulty,
    required String bloomTaxonomy,
    required int count,
    required int marks,
  }) async {
    if (shouldFail) throw Exception('failed');
    return drafts;
  }
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('initial state is AiGeneratorInitial', () {
    final bloc = AiGeneratorBloc(repository: _MockAiRepository());
    expect(bloc.state, isA<AiGeneratorInitial>());
    bloc.close();
  });

  group('AiGeneratorGenerateFromTopic', () {
    test('emits [Loading, ResultReady] on success', () async {
      final bloc = AiGeneratorBloc(repository: _MockAiRepository(drafts: []));
      final states = <AiGeneratorState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const AiGeneratorGenerateFromTopic(
        examIds: [1],
        topic: 'T',
        questionTypes: ['mcq'],
        difficulty: 'easy',
        bloomTaxonomy: 'remember',
        count: 1,
        marks: 1,
      ));
      await _flush();

      expect(states, [isA<AiGeneratorLoading>(), isA<AiGeneratorResultReady>()]);
      await sub.cancel();
      bloc.close();
    });
  });
}
