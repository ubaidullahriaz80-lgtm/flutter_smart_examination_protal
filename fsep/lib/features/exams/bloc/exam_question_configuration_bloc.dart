import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/exam_question_configuration_model.dart';
import '../../../data/repositories/exam_repository.dart';
import 'exam_question_configuration_event.dart';
import 'exam_question_configuration_state.dart';

class ExamQuestionConfigurationBloc extends Bloc<ExamQuestionConfigurationEvent, ExamQuestionConfigurationState> {
  final ExamRepository _repository;

  ExamQuestionConfigurationBloc({required ExamRepository repository})
      : _repository = repository,
        super(const ExamQuestionConfigurationInitial()) {
    on<LoadConfigurations>(_onLoadConfigurations);
    on<AddConfiguration>(_onAddConfiguration);
    on<UpdateConfiguration>(_onUpdateConfiguration);
    on<RemoveConfiguration>(_onRemoveConfiguration);
    on<SaveConfigurations>(_onSaveConfigurations);
  }

  Future<void> _onLoadConfigurations(LoadConfigurations event, Emitter<ExamQuestionConfigurationState> emit) async {
    emit(ExamQuestionConfigurationLoading(state.configurations));
    try {
      final exam = await _repository.getExam(event.examId);
      emit(ExamQuestionConfigurationLoaded(exam.questionConfigurations));
    } catch (e) {
      emit(ExamQuestionConfigurationError(state.configurations, e.toString()));
    }
  }

  void _onAddConfiguration(AddConfiguration event, Emitter<ExamQuestionConfigurationState> emit) {
    final updated = List<ExamQuestionConfigurationModel>.from(state.configurations)..add(event.configuration);
    emit(ExamQuestionConfigurationLoaded(updated));
  }

  void _onUpdateConfiguration(UpdateConfiguration event, Emitter<ExamQuestionConfigurationState> emit) {
    final updated = List<ExamQuestionConfigurationModel>.from(state.configurations);
    updated[event.index] = event.configuration;
    emit(ExamQuestionConfigurationLoaded(updated));
  }

  void _onRemoveConfiguration(RemoveConfiguration event, Emitter<ExamQuestionConfigurationState> emit) {
    final updated = List<ExamQuestionConfigurationModel>.from(state.configurations)..removeAt(event.index);
    emit(ExamQuestionConfigurationLoaded(updated));
  }

  Future<void> _onSaveConfigurations(SaveConfigurations event, Emitter<ExamQuestionConfigurationState> emit) async {
    emit(ExamQuestionConfigurationLoading(state.configurations));
    try {
      final updated = await _repository.syncQuestionConfigurations(
        examId: event.examId,
        configurations: state.configurations,
      );
      emit(ExamQuestionConfigurationSaved(updated));
    } catch (e) {
      emit(ExamQuestionConfigurationError(state.configurations, e.toString()));
    }
  }
}
