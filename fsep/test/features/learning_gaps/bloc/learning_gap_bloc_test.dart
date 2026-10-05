import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/data/models/learning_gap_model.dart';
import 'package:fsep/data/repositories/learning_gap_repository.dart';
import 'package:fsep/features/learning_gaps/bloc/learning_gap_bloc.dart';
import 'package:fsep/features/learning_gaps/bloc/learning_gap_event.dart';
import 'package:fsep/features/learning_gaps/bloc/learning_gap_state.dart';

class _MockLearningGapRepository extends LearningGapRepository {
  _MockLearningGapRepository({
    this.shouldFail = false,
    this.report,
  });

  final bool shouldFail;
  final LearningGapReport? report;

  @override
  Future<LearningGapReport> getLearningGaps() async {
    if (shouldFail) throw Exception('failed');
    return report!;
  }

  @override
  Future<LearningGapReport> getLearningReport(int sessionId) async {
    if (shouldFail) throw Exception('failed');
    return report!;
  }
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  const mockReport = LearningGapReport(
    gaps: [],
    allTopics: [],
    topicsAnalyzed: 0,
    questionsAttempted: 0,
    bloomProfile: {},
    difficultyProfile: {},
    improvementRoadmap: [],
  );

  test('initial state is LearningGapInitial', () {
    final bloc = LearningGapBloc(repository: _MockLearningGapRepository());
    expect(bloc.state, isA<LearningGapInitial>());
    bloc.close();
  });

  group('LoadLearningGap', () {
    test('emits [Loading, Loaded] when repository succeeds (no sessionId)', () async {
      final bloc = LearningGapBloc(
        repository: _MockLearningGapRepository(report: mockReport),
      );
      final states = <LearningGapState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadLearningGap());
      await _flush();

      expect(states, [
        isA<LearningGapLoading>(),
        isA<LearningGapLoaded>(),
      ]);

      await sub.cancel();
      await bloc.close();
    });

    test('emits [Loading, Loaded] when repository succeeds (with sessionId)', () async {
      final bloc = LearningGapBloc(
        repository: _MockLearningGapRepository(report: mockReport),
      );
      final states = <LearningGapState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadLearningGap(sessionId: 123));
      await _flush();

      expect(states, [
        isA<LearningGapLoading>(),
        isA<LearningGapLoaded>(),
      ]);

      await sub.cancel();
      await bloc.close();
    });

    test('emits [Loading, Error] when repository fails', () async {
      final bloc = LearningGapBloc(
        repository: _MockLearningGapRepository(shouldFail: true),
      );
      final states = <LearningGapState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadLearningGap());
      await _flush();

      expect(states, [
        isA<LearningGapLoading>(),
        isA<LearningGapError>(),
      ]);

      await sub.cancel();
      await bloc.close();
    });
  });

  group('RefreshLearningGap', () {
    test('emits [Loaded] when repository succeeds', () async {
      final bloc = LearningGapBloc(
        repository: _MockLearningGapRepository(report: mockReport),
      );
      final states = <LearningGapState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const RefreshLearningGap());
      await _flush();

      expect(states, [isA<LearningGapLoaded>()]);

      await sub.cancel();
      await bloc.close();
    });
  });
}
