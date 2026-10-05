import '../../../data/models/exam_question_configuration_model.dart';

abstract class ExamQuestionConfigurationState {
  final List<ExamQuestionConfigurationModel> configurations;
  const ExamQuestionConfigurationState(this.configurations);
}

class ExamQuestionConfigurationInitial extends ExamQuestionConfigurationState {
  const ExamQuestionConfigurationInitial() : super(const []);
}

class ExamQuestionConfigurationLoading extends ExamQuestionConfigurationState {
  const ExamQuestionConfigurationLoading(super.configurations);
}

class ExamQuestionConfigurationLoaded extends ExamQuestionConfigurationState {
  const ExamQuestionConfigurationLoaded(super.configurations);
}

class ExamQuestionConfigurationSaved extends ExamQuestionConfigurationState {
  const ExamQuestionConfigurationSaved(super.configurations);
}

class ExamQuestionConfigurationError extends ExamQuestionConfigurationState {
  final String message;
  const ExamQuestionConfigurationError(super.configurations, this.message);
}
