abstract class ExamEvent {
  const ExamEvent();
}

class LoadExams extends ExamEvent {
  const LoadExams();
}

class RefreshExams extends ExamEvent {
  const RefreshExams();
}

class CreateExam extends ExamEvent {
  const CreateExam({
    required this.title,
    this.description,
    this.courseCode,
    required this.durationMinutes,
    required this.totalMarks,
    required this.negativeMarkingWeight,
    required this.passPercentage,
    required this.status,
    this.allowedPlatforms,
    this.bcdEnabled = true,
    this.randomizeQuestions = false,
    this.shuffleChoices = false,
    this.isOfflineReady = false,
    this.startsAt,
    this.endsAt,
    this.departmentId,
    this.semester,
  });

  final String title;
  final String? description;
  final String? courseCode;
  final int durationMinutes;
  final double totalMarks;
  final double negativeMarkingWeight;
  final double passPercentage;
  final String status;
  final List<String>? allowedPlatforms;
  final bool bcdEnabled;
  final bool randomizeQuestions;
  final bool shuffleChoices;
  final bool isOfflineReady;
  final String? startsAt;
  final String? endsAt;
  final int? departmentId;
  final int? semester;
}

class UpdateExam extends ExamEvent {
  const UpdateExam({
    required this.examId,
    required this.title,
    this.description,
    this.courseCode,
    required this.durationMinutes,
    required this.totalMarks,
    required this.negativeMarkingWeight,
    required this.passPercentage,
    required this.status,
    this.allowedPlatforms,
    this.bcdEnabled = true,
    this.randomizeQuestions = false,
    this.shuffleChoices = false,
    this.isOfflineReady = false,
    this.startsAt,
    this.endsAt,
    this.departmentId,
    this.semester,
  });

  final int examId;
  final String title;
  final String? description;
  final String? courseCode;
  final int durationMinutes;
  final double totalMarks;
  final double negativeMarkingWeight;
  final double passPercentage;
  final String status;
  final List<String>? allowedPlatforms;
  final bool bcdEnabled;
  final bool randomizeQuestions;
  final bool shuffleChoices;
  final bool isOfflineReady;
  final String? startsAt;
  final String? endsAt;
  final int? departmentId;
  final int? semester;
}

class DeleteExam extends ExamEvent {
  const DeleteExam(this.examId);

  final int examId;
}
