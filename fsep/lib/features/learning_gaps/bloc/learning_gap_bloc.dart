import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/learning_gap_repository.dart';
import 'learning_gap_event.dart';
import 'learning_gap_state.dart';

class LearningGapBloc extends Bloc<LearningGapEvent, LearningGapState> {
  LearningGapBloc({required LearningGapRepository repository})
      : _repository = repository,
        super(LearningGapInitial()) {
    on<LoadLearningGap>(_onLoadLearningGap);
    on<RefreshLearningGap>(_onRefreshLearningGap);
  }

  final LearningGapRepository _repository;

  Future<void> _onLoadLearningGap(
    LoadLearningGap event,
    Emitter<LearningGapState> emit,
  ) async {
    emit(LearningGapLoading());
    await _fetchReport(event.sessionId, emit);
  }

  Future<void> _onRefreshLearningGap(
    RefreshLearningGap event,
    Emitter<LearningGapState> emit,
  ) async {
    // For refresh, we might want to keep the current data visible if we had it,
    // but the requirement is simple loading/error/success.
    await _fetchReport(event.sessionId, emit);
  }

  Future<void> _fetchReport(int? sessionId, Emitter<LearningGapState> emit) async {
    try {
      final report = sessionId != null
          ? await _repository.getLearningReport(sessionId)
          : await _repository.getLearningGaps();
      emit(LearningGapLoaded(report));
    } catch (e) {
      emit(LearningGapError(e.toString()));
    }
  }
}
