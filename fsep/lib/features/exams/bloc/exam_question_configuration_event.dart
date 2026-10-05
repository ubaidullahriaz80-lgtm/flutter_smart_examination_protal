import '../../../data/models/exam_question_configuration_model.dart';

abstract class ExamQuestionConfigurationEvent {
  const ExamQuestionConfigurationEvent();
}

class LoadConfigurations extends ExamQuestionConfigurationEvent {
  final int examId;
  const LoadConfigurations(this.examId);
}

class AddConfiguration extends ExamQuestionConfigurationEvent {
  final ExamQuestionConfigurationModel configuration;
  const AddConfiguration(this.configuration);
}

class UpdateConfiguration extends ExamQuestionConfigurationEvent {
  final int index;
  final ExamQuestionConfigurationModel configuration;
  const UpdateConfiguration(this.index, this.configuration);
}

class RemoveConfiguration extends ExamQuestionConfigurationEvent {
  final int index;
  const RemoveConfiguration(this.index);
}

class SaveConfigurations extends ExamQuestionConfigurationEvent {
  final int examId;
  const SaveConfigurations(this.examId);
}
