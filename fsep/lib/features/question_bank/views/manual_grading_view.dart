import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/question_model.dart';
import '../../../data/repositories/exam_session_repository.dart';
import '../../../data/repositories/question_bank_repository.dart';

/// Manual grading (List 1 Item 2). No dedicated "pending manual reviews"
/// endpoint exists on the backend, so this list is composed client-side
/// from three existing, already-used endpoints: GET /exam-sessions (which
/// answers grading is still pending), GET /results/{session} (whose
/// question_results entries have obtained_marks == null — the backend's
/// own signal for "not yet graded", see GradingService), and
/// GET /questions?exam_id= (for the question's type, to label the card).
/// The examiner never types a session/question id — tapping "Review"
/// carries both ids through navigation into [_ManualGradeDetailView].
class ManualGradingView extends StatefulWidget {
  const ManualGradingView({super.key});

  @override
  State<ManualGradingView> createState() => _ManualGradingViewState();
}

class _PendingReviewItem {
  const _PendingReviewItem({
    required this.sessionId,
    required this.questionId,
    required this.candidateName,
    required this.examTitle,
    required this.questionType,
  });

  final int sessionId;
  final int questionId;
  final String candidateName;
  final String examTitle;
  final String? questionType;
}

class _ManualGradingViewState extends State<ManualGradingView> {
  final ExamSessionRepository _sessionRepository = ExamSessionRepository();
  final QuestionBankRepository _questionRepository = QuestionBankRepository();

  late Future<List<_PendingReviewItem>> _pendingFuture;

  @override
  void initState() {
    super.initState();
    _pendingFuture = _loadPending();
  }

  Future<List<_PendingReviewItem>> _loadPending() async {
    final sessions = await _sessionRepository.getActiveSessions();
    final submitted = sessions.where((s) => s.status == 'submitted');

    final resultEntries = await Future.wait(submitted.map((session) async {
      try {
        final result = await _sessionRepository.getResult(session.sessionId);
        return (session: session, result: result);
      } on ApiException {
        return null;
      }
    }));

    final pending = [
      for (final entry in resultEntries)
        if (entry != null && entry.result.isPendingManualReview) entry,
    ];

    // One /questions fetch per distinct exam among the pending sessions,
    // reused across all of that exam's sessions — not one per session.
    final examIds = pending.map((e) => e.session.examId).toSet();
    final questionsByExam = <int, List<QuestionModel>>{};
    await Future.wait(examIds.map((examId) async {
      questionsByExam[examId] =
          await _questionRepository.getQuestions(examId: examId);
    }));

    final items = <_PendingReviewItem>[];
    for (final entry in pending) {
      final questions = questionsByExam[entry.session.examId] ?? const [];
      for (final questionResult in entry.result.questionResults) {
        if (questionResult.obtainedMarks != null) continue;

        String? questionType;
        for (final question in questions) {
          if (question.id == questionResult.questionId) {
            questionType = question.questionType;
            break;
          }
        }

        items.add(_PendingReviewItem(
          sessionId: entry.session.sessionId,
          questionId: questionResult.questionId,
          candidateName: entry.session.candidateName,
          examTitle: entry.session.examTitle,
          questionType: questionType,
        ));
      }
    }
    return items;
  }

  String _questionTypeLabel(String type) => switch (type) {
        'essay' => 'Essay Question',
        'code_snippet' => 'Code Snippet Question',
        _ => type,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Grading')),
      body: FutureBuilder<List<_PendingReviewItem>>(
        future: _pendingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            return Center(
              child: Text(
                error is ApiException
                    ? error.message
                    : 'Unable to load pending reviews.',
              ),
            );
          }

          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No answers are currently pending manual review.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              final refreshed = _loadPending();
              setState(() => _pendingFuture = refreshed);
              await refreshed;
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.candidateName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(item.examTitle),
                        if (item.questionType != null) ...[
                          const SizedBox(height: 4),
                          Text(_questionTypeLabel(item.questionType!)),
                        ],
                        const SizedBox(height: 8),
                        Chip(
                          label: const Text(
                            'Pending Manual Review',
                            style: TextStyle(fontSize: 12),
                          ),
                          backgroundColor:
                              Colors.orange.withValues(alpha: 0.15),
                          labelStyle: const TextStyle(color: Colors.orange),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () async {
                              final graded =
                                  await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => _ManualGradeDetailView(
                                    sessionId: item.sessionId,
                                    questionId: item.questionId,
                                    candidateName: item.candidateName,
                                    examTitle: item.examTitle,
                                  ),
                                ),
                              );
                              if (graded == true && mounted) {
                                setState(() => _pendingFuture = _loadPending());
                              }
                            },
                            child: const Text('Review'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// The actual grading form for one answer. sessionId/questionId are
/// supplied by the caller (from the selected [_PendingReviewItem]) —
/// never typed in by the examiner.
class _ManualGradeDetailView extends StatefulWidget {
  const _ManualGradeDetailView({
    required this.sessionId,
    required this.questionId,
    required this.candidateName,
    required this.examTitle,
  });

  final int sessionId;
  final int questionId;
  final String candidateName;
  final String examTitle;

  @override
  State<_ManualGradeDetailView> createState() =>
      _ManualGradeDetailViewState();
}

class _ManualGradeDetailViewState extends State<_ManualGradeDetailView> {
  final ExamSessionRepository _repository = ExamSessionRepository();
  final _marksController = TextEditingController();

  bool _loading = true;
  String? _loadError;
  PendingAnswerModel? _answer;

  bool _saving = false;
  String? _saveError;
  double? _savedMarks;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _marksController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final answer = await _repository.getPendingAnswer(
        sessionId: widget.sessionId,
        questionId: widget.questionId,
      );
      if (!mounted) return;
      setState(() => _answer = answer);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveGrade() async {
    final answer = _answer;
    if (answer == null || _saving) return;

    final marks = double.tryParse(_marksController.text.trim());
    if (marks == null) {
      setState(() => _saveError = 'Enter a valid number of marks.');
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      await _repository.submitManualGrade(
        sessionId: answer.sessionId,
        questionId: answer.questionId,
        obtainedMarks: marks,
      );
      if (!mounted) return;
      setState(() => _savedMarks = marks);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saveError = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final answer = _answer;

    return Scaffold(
      appBar: AppBar(title: const Text('Grade Answer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_loadError != null)
              Text(
                _loadError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (answer != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Candidate: ${widget.candidateName}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Exam: ${widget.examTitle}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Session: #${answer.sessionId}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Divider(height: 24),
                      Chip(
                        label: Text(
                          answer.gradingStatus == 'pending_manual_review'
                              ? 'Pending Manual Review'
                              : answer.gradingStatus.toUpperCase(),
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: Colors.orange.withValues(alpha: 0.15),
                        labelStyle: const TextStyle(color: Colors.orange),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Question (${answer.questionType})',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(answer.questionText),
                      const SizedBox(height: 12),
                      Text(
                        'Candidate Answer',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(answer.selectedOption),
                      const SizedBox(height: 12),
                      Text('Maximum Marks: ${answer.maxMarks}'),
                      const SizedBox(height: 16),
                      if (_savedMarks != null) ...[
                        Text(
                          'Graded: ${_savedMarks!.toStringAsFixed(2)} / '
                          '${answer.maxMarks}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () =>
                                Navigator.of(context).pop(true),
                            child: const Text('Done'),
                          ),
                        ),
                      ] else if (answer.gradingStatus ==
                          'pending_manual_review') ...[
                        TextField(
                          controller: _marksController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Marks Awarded',
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_saveError != null) ...[
                          Text(
                            _saveError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        FilledButton(
                          onPressed: _saving ? null : _saveGrade,
                          child: _saving
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Grade Answer'),
                        ),
                      ] else ...[
                        Text(
                          'Already graded: ${answer.obtainedMarks} / '
                          '${answer.maxMarks}',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
