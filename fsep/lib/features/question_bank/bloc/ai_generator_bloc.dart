import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/generated_question_draft.dart';
import '../../../data/repositories/question_bank_repository.dart';
import 'ai_generator_event.dart';
import 'ai_generator_state.dart';

class AiGeneratorBloc extends Bloc<AiGeneratorEvent, AiGeneratorState> {
  AiGeneratorBloc({required QuestionBankRepository repository})
      : _repository = repository,
        super(AiGeneratorInitial()) {
    on<AiGeneratorGenerateFromTopic>(_onGenerateFromTopic);
    on<AiGeneratorUploadDocuments>(_onUploadDocuments);
    on<AiGeneratorPollJobStatus>(_onPollJobStatus);
    on<AiGeneratorSaveDraft>(_onSaveDraft);
    on<AiGeneratorDiscardDraft>(_onDiscardDraft);
  }

  final QuestionBankRepository _repository;

  Future<void> _onGenerateFromTopic(
    AiGeneratorGenerateFromTopic event,
    Emitter<AiGeneratorState> emit,
  ) async {
    emit(AiGeneratorLoading());
    try {
      final job = await _repository.generateQuestions(
        examIds: event.examIds,
        topic: event.topic,
        questionTypes: event.questionTypes,
        difficulty: event.difficulty,
        bloomTaxonomy: event.bloomTaxonomy,
        count: event.count,
        marks: event.marks,
      );
      final jobId = (job['job_id'] as num?)?.toInt();
      if (jobId == null) {
        throw Exception('The server did not return a generation job ID.');
      }
      emit(AiGeneratorJobStarted(
        jobId: jobId,
        status: job['status']?.toString() ?? 'GENERATING',
      ));
    } catch (e) {
      emit(AiGeneratorError(e.toString()));
    }
  }

  Future<void> _onUploadDocuments(
    AiGeneratorUploadDocuments event,
    Emitter<AiGeneratorState> emit,
  ) async {
    emit(AiGeneratorLoading());
    try {
      final result = await _repository.uploadGenerationDocuments(
        filePaths: event.filePaths,
        examIds: event.examIds,
        questionTypes: event.questionTypes,
        difficulty: event.difficulty,
        bloomTaxonomy: event.bloomTaxonomy,
        count: event.count,
        marks: event.marks,
      );
      emit(AiGeneratorJobStarted(
        jobId: result['job_id'],
        status: result['status'],
      ));
    } catch (e) {
      emit(AiGeneratorError(e.toString()));
    }
  }

  Future<void> _onPollJobStatus(
    AiGeneratorPollJobStatus event,
    Emitter<AiGeneratorState> emit,
  ) async {
    // Ignore stale timer events, including polls from a previous generation.
    final stateBeforeRequest = state;
    if (stateBeforeRequest is! AiGeneratorJobStarted ||
        stateBeforeRequest.jobId != event.jobId) {
      return;
    }

    try {
      final job = await _repository.getJobStatus(event.jobId);

      // Poll requests can overlap if the network is slow. A late response
      // must not replace a completed result (or a newer generation state).
      final stateAfterRequest = state;
      if (stateAfterRequest is! AiGeneratorJobStarted ||
          stateAfterRequest.jobId != event.jobId) {
        return;
      }

      final status = job['status']?.toString() ?? 'GENERATING';
      if (status == 'COMPLETED') {
        final questions = job['questions'];
        if (questions is! List) {
          throw Exception('The completed generation job did not return questions.');
        }
        emit(AiGeneratorResultReady(
          drafts: questions
              .map((question) => GeneratedQuestionDraft.fromJson(
                  (question as Map).cast<String, dynamic>()))
              .toList(),
        ));
      } else if (status == 'FAILED') {
        emit(AiGeneratorError(
          job['last_error']?.toString() ?? 'Question generation failed.',
        ));
      } else if (stateAfterRequest.status != status) {
        emit(AiGeneratorJobStarted(jobId: event.jobId, status: status));
      }
    } catch (e) {
      emit(AiGeneratorError(e.toString()));
    }
  }

  Future<void> _onSaveDraft(
    AiGeneratorSaveDraft event,
    Emitter<AiGeneratorState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AiGeneratorResultReady) return;

    final savingIndexes = Set<int>.from(currentState.savingIndexes)..add(event.index);
    emit(currentState.copyWith(savingIndexes: savingIndexes));

    try {
      await _repository.createQuestion(event.draft);
      
      final updatedState = state;
      if (updatedState is AiGeneratorResultReady) {
        final newSaving = Set<int>.from(updatedState.savingIndexes)..remove(event.index);
        final newSaved = Set<int>.from(updatedState.savedIndexes)..add(event.index);
        emit(updatedState.copyWith(savingIndexes: newSaving, savedIndexes: newSaved));
      }
    } catch (e) {
      final updatedState = state;
      if (updatedState is AiGeneratorResultReady) {
        final newSaving = Set<int>.from(updatedState.savingIndexes)..remove(event.index);
        emit(updatedState.copyWith(savingIndexes: newSaving));
      }
      // Transient error for save
      // emit(AiGeneratorError(e.toString())); 
    }
  }

  void _onDiscardDraft(
    AiGeneratorDiscardDraft event,
    Emitter<AiGeneratorState> emit,
  ) {
    final currentState = state;
    if (currentState is AiGeneratorResultReady) {
      final drafts = List.of(currentState.drafts)..removeAt(event.index);
      // Adjust saved/saving indexes if necessary, but removing is simpler
      emit(AiGeneratorResultReady(drafts: drafts));
    }
  }
}
