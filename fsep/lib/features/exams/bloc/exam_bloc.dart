import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/exam_repository.dart';
import 'exam_event.dart';
import 'exam_state.dart';

class ExamBloc extends Bloc<ExamEvent, ExamState> {
  ExamBloc({required ExamRepository repository})
      : _repository = repository,
        super(ExamInitial()) {
    on<LoadExams>(_onLoadExams);
    on<RefreshExams>(_onRefreshExams);
    on<CreateExam>(_onCreateExam);
    on<UpdateExam>(_onUpdateExam);
    on<DeleteExam>(_onDeleteExam);
  }

  final ExamRepository _repository;

  Future<void> _onLoadExams(LoadExams event, Emitter<ExamState> emit) async {
    emit(ExamLoading());
    try {
      final exams = await _repository.getExams();
      emit(ExamLoaded(exams));
    } catch (e) {
      emit(ExamError(e.toString()));
    }
  }

  Future<void> _onRefreshExams(RefreshExams event, Emitter<ExamState> emit) async {
    try {
      final exams = await _repository.getExams();
      emit(ExamLoaded(exams));
    } catch (e) {
      emit(ExamError(e.toString()));
    }
  }

  Future<void> _onCreateExam(CreateExam event, Emitter<ExamState> emit) async {
    emit(ExamLoading());
    try {
      await _repository.createExam(
        title: event.title,
        description: event.description,
        courseCode: event.courseCode,
        durationMinutes: event.durationMinutes,
        totalMarks: event.totalMarks,
        negativeMarkingWeight: event.negativeMarkingWeight,
        passPercentage: event.passPercentage,
        status: event.status,
        allowedPlatforms: event.allowedPlatforms,
        bcdEnabled: event.bcdEnabled,
        randomizeQuestions: event.randomizeQuestions,
        shuffleChoices: event.shuffleChoices,
        isOfflineReady: event.isOfflineReady,
        startsAt: event.startsAt,
        endsAt: event.endsAt,
        departmentId: event.departmentId,
        semester: event.semester,
      );
      emit(const ExamOperationSuccess(message: 'Exam created successfully'));
    } catch (e) {
      emit(ExamError(e.toString()));
    }
  }

  Future<void> _onUpdateExam(UpdateExam event, Emitter<ExamState> emit) async {
    emit(ExamLoading());
    try {
      await _repository.updateExam(
        examId: event.examId,
        title: event.title,
        description: event.description,
        courseCode: event.courseCode,
        durationMinutes: event.durationMinutes,
        totalMarks: event.totalMarks,
        negativeMarkingWeight: event.negativeMarkingWeight,
        passPercentage: event.passPercentage,
        status: event.status,
        allowedPlatforms: event.allowedPlatforms,
        bcdEnabled: event.bcdEnabled,
        randomizeQuestions: event.randomizeQuestions,
        shuffleChoices: event.shuffleChoices,
        isOfflineReady: event.isOfflineReady,
        startsAt: event.startsAt,
        endsAt: event.endsAt,
        departmentId: event.departmentId,
        semester: event.semester,
      );
      emit(const ExamOperationSuccess(message: 'Exam updated successfully'));
    } catch (e) {
      emit(ExamError(e.toString()));
    }
  }

  Future<void> _onDeleteExam(DeleteExam event, Emitter<ExamState> emit) async {
    try {
      await _repository.deleteExam(event.examId);
      final exams = await _repository.getExams();
      emit(ExamLoaded(exams));
    } catch (e) {
      emit(ExamError(e.toString()));
    }
  }
}
