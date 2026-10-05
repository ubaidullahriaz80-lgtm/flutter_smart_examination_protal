abstract class LearningGapEvent {
  const LearningGapEvent();
}

class LoadLearningGap extends LearningGapEvent {
  const LoadLearningGap({this.sessionId});

  final int? sessionId;
}

class RefreshLearningGap extends LearningGapEvent {
  const RefreshLearningGap({this.sessionId});

  final int? sessionId;
}
