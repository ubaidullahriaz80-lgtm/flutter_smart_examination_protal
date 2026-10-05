import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/question_model.dart';
import '../../../data/repositories/question_bank_repository.dart';
import '../bloc/question_bloc.dart';
import '../bloc/question_event.dart';
import '../bloc/question_state.dart';
import 'question_form_view.dart';

class AiQuestionReviewView extends StatelessWidget {
  const AiQuestionReviewView({super.key, required this.jobId});

  final int jobId;

  Future<void> _openEditForm(BuildContext context, QuestionModel question) async {
    final bloc = context.read<QuestionBloc>();
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuestionFormView(existingQuestion: question),
      ),
    );
    if (updated == true) {
      bloc.add(LoadReviewQueue(jobId));
    }
  }

  void _confirmAndBulkAction(BuildContext context, List<int> ids, String action) async {
    final bloc = context.read<QuestionBloc>();
    String? reason;

    if (action == 'reject') {
      reason = await _showRejectDialog(context);
      if (reason == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Bulk Approve?'),
          content: Text('Approve all ${ids.length} pending questions?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    bloc.add(BulkReviewQuestions(
      jobId: jobId,
      questionIds: ids,
      action: action,
      rejectionReason: reason,
    ));
  }

  Future<String?> _showRejectDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Questions'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason for rejection'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => QuestionBloc(
        repository: QuestionBankRepository(),
      )..add(LoadReviewQueue(jobId)),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Review Job #$jobId'),
        ),
        body: BlocListener<QuestionBloc, QuestionState>(
          listener: (context, state) {
            if (state is QuestionOperationSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
              context.read<QuestionBloc>().add(LoadReviewQueue(jobId));
            } else if (state is QuestionError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          child: BlocBuilder<QuestionBloc, QuestionState>(
            builder: (context, state) {
              if (state is QuestionLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is QuestionError && state.message.contains('Unable to load')) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Failed to load review queue.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.read<QuestionBloc>().add(LoadReviewQueue(jobId)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final questions = state is QuestionLoaded ? state.questions : <QuestionModel>[];
              final pending = questions.where((q) => q.reviewStatus == 'pending').toList();

              if (questions.isEmpty && state is QuestionLoaded) {
                return const Center(child: Text('No questions found for this job.'));
              }

              return Column(
                children: [
                  if (pending.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmAndBulkAction(context, pending.map((q) => q.id).toList(), 'reject'),
                              icon: const Icon(Icons.close),
                              label: const Text('Reject All'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _confirmAndBulkAction(context, pending.map((q) => q.id).toList(), 'approve'),
                              icon: const Icon(Icons.done_all),
                              label: const Text('Approve All'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: questions.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final q = questions[index];
                        return _ReviewCard(
                          question: q,
                          onEdit: () => _openEditForm(context, q),
                          onApprove: q.reviewStatus == 'pending'
                              ? () => context.read<QuestionBloc>().add(UpdateQuestion(q, reviewStatus: 'approved'))
                              : null,
                          onReject: q.reviewStatus == 'pending'
                              ? () async {
                                  final reason = await _showRejectDialog(context);
                                  if (reason != null && context.mounted) {
                                    context.read<QuestionBloc>().add(UpdateQuestion(q, reviewStatus: 'rejected', rejectionReason: reason));
                                  }
                                }
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.question,
    required this.onEdit,
    required this.onApprove,
    required this.onReject,
  });

  final QuestionModel question;
  final VoidCallback onEdit;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final status = question.reviewStatus.toUpperCase();
    final color = question.reviewStatus == 'approved'
        ? Colors.green
        : question.reviewStatus == 'rejected'
            ? Colors.red
            : Colors.orange;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    question.questionText,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _Badge(question.questionType),
                _Badge('${question.marks.toInt()} pts'),
                _Badge(question.difficulty ?? 'medium'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: onEdit, child: const Text('Edit')),
                if (onReject != null) ...[
                  const SizedBox(width: 8),
                  TextButton(onPressed: onReject, child: const Text('Reject', style: TextStyle(color: Colors.red))),
                ],
                if (onApprove != null) ...[
                  const SizedBox(width: 8),
                  FilledButton(onPressed: onApprove, child: const Text('Approve')),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
