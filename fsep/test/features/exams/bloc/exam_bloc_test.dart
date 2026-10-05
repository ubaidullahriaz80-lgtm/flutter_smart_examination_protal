import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/data/models/exam_model.dart';
import 'package:fsep/data/repositories/exam_repository.dart';
import 'package:fsep/features/exams/bloc/exam_bloc.dart';
import 'package:fsep/features/exams/bloc/exam_event.dart';
import 'package:fsep/features/exams/bloc/exam_state.dart';

class _MockExamRepository extends ExamRepository {
  _MockExamRepository({
    this.shouldFail = false,
    this.exams = const [],
    this.exam,
  });

  final bool shouldFail;
  final List<ExamModel> exams;
  final ExamModel? exam;

  @override
  Future<List<ExamModel>> getExams() async {
    if (shouldFail) throw Exception('failed');
    return exams;
  }

  @override
  Future<ExamModel> createExam({
    required String title,
    String? description,
    String? courseCode,
    required int durationMinutes,
    required double totalMarks,
    required double negativeMarkingWeight,
    required double passPercentage,
    required String status,
    List<String>? allowedPlatforms,
    bool bcdEnabled = true,
    bool randomizeQuestions = false,
    bool shuffleChoices = false,
    bool isOfflineReady = false,
    String? startsAt,
    String? endsAt,
    int? departmentId,
    int? semester,
  }) async {
    if (shouldFail) throw Exception('failed');
    return exam!;
  }

  @override
  Future<ExamModel> updateExam({
    required int examId,
    required String title,
    String? description,
    String? courseCode,
    required int durationMinutes,
    required double totalMarks,
    required double negativeMarkingWeight,
    required double passPercentage,
    required String status,
    List<String>? allowedPlatforms,
    bool bcdEnabled = true,
    bool randomizeQuestions = false,
    bool shuffleChoices = false,
    bool isOfflineReady = false,
    String? startsAt,
    String? endsAt,
    int? departmentId,
    int? semester,
  }) async {
    if (shouldFail) throw Exception('failed');
    return exam!;
  }

  @override
  Future<void> deleteExam(int examId) async {
    if (shouldFail) throw Exception('failed');
  }
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  const mockExam = ExamModel(
    id: 1,
    createdBy: 1,
    title: 'Test Exam',
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

  test('initial state is ExamInitial', () {
    final bloc = ExamBloc(repository: _MockExamRepository());
    expect(bloc.state, isA<ExamInitial>());
    bloc.close();
  });

  group('LoadExams', () {
    test('emits [Loading, Loaded] when repository succeeds', () async {
      final bloc = ExamBloc(
        repository: _MockExamRepository(exams: [mockExam]),
      );
      final states = <ExamState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadExams());
      await _flush();

      expect(states, [
        isA<ExamLoading>(),
        isA<ExamLoaded>(),
      ]);

      await sub.cancel();
      await bloc.close();
    });

    test('emits [Loading, Error] when repository fails', () async {
      final bloc = ExamBloc(
        repository: _MockExamRepository(shouldFail: true),
      );
      final states = <ExamState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const LoadExams());
      await _flush();

      expect(states, [
        isA<ExamLoading>(),
        isA<ExamError>(),
      ]);

      await sub.cancel();
      await bloc.close();
    });
  });

  group('CreateExam', () {
    test('emits [Loading, OperationSuccess] on success', () async {
      final bloc = ExamBloc(
        repository: _MockExamRepository(exam: mockExam),
      );
      final states = <ExamState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const CreateExam(
        title: 'New',
        durationMinutes: 60,
        totalMarks: 100,
        negativeMarkingWeight: 0,
        passPercentage: 50,
        status: 'published',
      ));
      await _flush();

      expect(states, [
        isA<ExamLoading>(),
        isA<ExamOperationSuccess>(),
      ]);

      await sub.cancel();
      await bloc.close();
    });
  });

  group('DeleteExam', () {
    test('emits [Loaded] after successful deletion', () async {
      final bloc = ExamBloc(
        repository: _MockExamRepository(exams: []),
      );
      final states = <ExamState>[];
      final sub = bloc.stream.listen(states.add);

      bloc.add(const DeleteExam(1));
      await _flush();

      expect(states, [
        isA<ExamLoaded>(),
      ]);

      await sub.cancel();
      await bloc.close();
    });
  });
}
