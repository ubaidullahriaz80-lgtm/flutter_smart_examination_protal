import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../data/models/result_model.dart';
import '../../../data/repositories/exam_session_repository.dart';
import '../../learning_gaps/views/learning_gaps_view.dart';

/// Shown after a candidate successfully submits an exam (or reopens an
/// exam whose session is already submitted). Displays the real persisted
/// result if it could be fetched; otherwise falls back to a generic
/// confirmation message rather than blocking or showing an error — a
/// failed result fetch must never look like a failed submission.
///
/// No correct answers are shown here — the backend result API doesn't
/// return them, by design.
class ExamSubmissionConfirmationView extends StatelessWidget {
  const ExamSubmissionConfirmationView({super.key, this.result});

  final ResultModel? result;

  @override
  Widget build(BuildContext context) {
    final result = this.result;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exam Submitted'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Exam submitted successfully.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your answers have been recorded and can no longer be changed.',
                      textAlign: TextAlign.center,
                    ),
                    if (result != null) ...[
                      const SizedBox(height: 24),
                      _ResultCard(result: result),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back to Exams'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final ResultModel result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (result.isPendingManualReview) ...[
              Chip(
                label: const Text(
                  'Pending Manual Review',
                  style: TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.orange.withValues(alpha: 0.15),
                labelStyle: const TextStyle(color: Colors.orange),
              ),
              const SizedBox(height: 12),
              const Text(
                'Some of your answers need to be reviewed by an examiner '
                'before your final score is complete.',
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              result.passFail.toUpperCase(),
              style: TextStyle(
                color: result.passFail == 'pass' ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cohort Percentile: ${result.percentile.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              '${result.totalScore.toStringAsFixed(2)} / '
              '${result.maxScore.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '${result.percentage.toStringAsFixed(1)}%'
              '${result.isPendingManualReview ? ' so far' : ''}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (result.questionResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              for (final questionResult in result.questionResults)
                _QuestionResultRow(questionResult: questionResult),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _ExportButtons(sessionId: result.sessionId),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LearningGapsView(sessionId: result.sessionId),
                    ),
                  );
                },
                icon: const Icon(Icons.insights_outlined),
                label: const Text('View Learning Gap Report'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Export PDF/Excel — same underlying result data as the card above, just
/// a downloadable file. Uses the existing file_picker dependency's
/// saveFile (already added for CSV import) rather than a new
/// file-opening/sharing package.
class _ExportButtons extends StatefulWidget {
  const _ExportButtons({required this.sessionId});

  final int sessionId;

  @override
  State<_ExportButtons> createState() => _ExportButtonsState();
}

class _ExportButtonsState extends State<_ExportButtons> {
  final ExamSessionRepository _repository = ExamSessionRepository();

  bool _exportingPdf = false;
  bool _exportingExcel = false;

  Future<void> _export({required bool isPdf}) async {
    setState(() {
      if (isPdf) {
        _exportingPdf = true;
      } else {
        _exportingExcel = true;
      }
    });

    try {
      final bytes = isPdf
          ? await _repository.getResultPdf(widget.sessionId)
          : await _repository.getResultExcel(widget.sessionId);

      final fileName =
          'fsep-result-${widget.sessionId}.${isPdf ? 'pdf' : 'xlsx'}';

      final savedUri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: isPdf
            ? 'application/pdf'
            : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (!mounted) return;
      if (savedUri != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Saved $fileName')));
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Export failed: ${error.message}')),
        );
    } finally {
      if (mounted) {
        setState(() {
          if (isPdf) {
            _exportingPdf = false;
          } else {
            _exportingExcel = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _exportingPdf ? null : () => _export(isPdf: true),
          icon: _exportingPdf
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Export PDF'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _exportingExcel ? null : () => _export(isPdf: false),
          icon: _exportingExcel
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.grid_on_outlined),
          label: const Text('Export Excel'),
        ),
      ],
    );
  }
}

class _QuestionResultRow extends StatelessWidget {
  const _QuestionResultRow({required this.questionResult});

  final QuestionResultModel questionResult;

  @override
  Widget build(BuildContext context) {
    final isCorrect = questionResult.isCorrect;
    final marks = questionResult.obtainedMarks;

    final Icon icon;
    final String label;
    if (isCorrect == null) {
      icon = const Icon(Icons.hourglass_empty, size: 18, color: Colors.orange);
      label = 'Pending review';
    } else if (isCorrect) {
      icon = const Icon(Icons.check_circle, size: 18, color: Colors.green);
      label = 'Correct';
    } else {
      icon = Icon(Icons.cancel,
          size: 18, color: Theme.of(context).colorScheme.error);
      label = 'Incorrect';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text('Question #${questionResult.questionId}'),
          ),
          icon,
          const SizedBox(width: 6),
          Text(label),
          if (marks != null) ...[
            const SizedBox(width: 6),
            Text('(${marks.toStringAsFixed(2)} marks)'),
          ],
        ],
      ),
    );
  }
}
