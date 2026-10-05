import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/question_model.dart';
import '../../../data/repositories/question_bank_repository.dart';
import '../bloc/question_bloc.dart';
import '../bloc/question_event.dart';
import '../bloc/question_state.dart';
import 'ai_question_generator_view.dart';
import 'manual_grading_view.dart';
import 'question_form_view.dart';

/// Question Bank — lists questions (manually authored or AI-generated)
/// and lets an examiner move them through the existing review_status
/// workflow. Entry point to the AI Question Generator.
class QuestionBankListView extends StatelessWidget {
  const QuestionBankListView({super.key});

  Future<void> _openGenerator(BuildContext context) async {
    final bloc = context.read<QuestionBloc>();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AiQuestionGeneratorView()),
    );
    bloc.add(const RefreshQuestions());
  }

  Future<void> _openCreateForm(BuildContext context) async {
    final bloc = context.read<QuestionBloc>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const QuestionFormView()),
    );
    if (created == true) {
      bloc.add(const RefreshQuestions());
    }
  }

  Future<void> _openEditForm(BuildContext context, QuestionModel question) async {
    final bloc = context.read<QuestionBloc>();
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuestionFormView(existingQuestion: question),
      ),
    );
    if (updated == true) {
      bloc.add(const RefreshQuestions());
    }
  }

  Future<void> _confirmAndDelete(BuildContext context, QuestionModel question) async {
    final bloc = context.read<QuestionBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Question?'),
        content: const Text(
          'Are you sure you want to delete this question? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    bloc.add(DeleteQuestion(question.id));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => QuestionBloc(
        repository: QuestionBankRepository(),
      )..add(const LoadQuestions()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Question Bank'),
          actions: [
            Builder(builder: (context) {
              return IconButton(
                tooltip: 'Add Question',
                icon: const Icon(Icons.add),
                onPressed: () => _openCreateForm(context),
              );
            }),
            IconButton(
              tooltip: 'Manual Grading',
              icon: const Icon(Icons.rate_review_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ManualGradingView()),
                );
              },
            ),
            Builder(builder: (context) {
              return IconButton(
                tooltip: 'AI Question Generator',
                icon: const Icon(Icons.auto_awesome),
                onPressed: () => _openGenerator(context),
              );
            }),
          ],
        ),
        body: BlocListener<QuestionBloc, QuestionState>(
          listener: (context, state) {
            if (state is QuestionOperationSuccess) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.message)));
              context.read<QuestionBloc>().add(const RefreshQuestions());
            } else if (state is QuestionError) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          child: BlocBuilder<QuestionBloc, QuestionState>(
            builder: (context, state) {
              if (state is QuestionLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state is QuestionError && state.message.contains('Unable to load')) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 12),
                        const Text('Unable to load the Question Bank.'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.read<QuestionBloc>().add(const LoadQuestions()),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final questions = state is QuestionLoaded ? state.questions : <QuestionModel>[];

              if (questions.isEmpty && state is QuestionLoaded) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'No questions yet.',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => _openGenerator(context),
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Generate with AI'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  final bloc = context.read<QuestionBloc>();
                  bloc.add(const RefreshQuestions());
                  await bloc.stream.firstWhere((s) => s is! QuestionLoading);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: questions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final question = questions[index];
                    return _QuestionBankCard(
                      question: question,
                      onTap: () => _openEditForm(context, question),
                      onDelete: () => _confirmAndDelete(context, question),
                      onApprove: question.reviewStatus == 'pending'
                          ? () => context.read<QuestionBloc>().add(UpdateQuestion(question, reviewStatus: 'approved'))
                          : null,
                      onReject: question.reviewStatus == 'pending'
                          ? () => context.read<QuestionBloc>().add(UpdateQuestion(question, reviewStatus: 'rejected'))
                          : null,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _QuestionBankCard extends StatelessWidget {
  const _QuestionBankCard({
    required this.question,
    required this.onTap,
    required this.onDelete,
    required this.onApprove,
    required this.onReject,
  });

  final QuestionModel question;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  Color _statusColor(BuildContext context) => switch (question.reviewStatus) {
        'approved' => Colors.green,
        'rejected' => Theme.of(context).colorScheme.error,
        _ => Colors.orange,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (question.isAiGenerated)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Chip(
                        label:
                            Text('AI', style: TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(
                    label: Text(
                      question.reviewStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        color: _statusColor(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(
                      question.questionType,
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(
                      '${question.marks.toInt()} marks',
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (question.courseCode != null)
                    Chip(
                      label: Text(
                        question.courseCode!,
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (question.difficulty != null)
                    Chip(
                      label: Text(
                        question.difficulty!,
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (question.bloomTaxonomy != null)
                    Chip(
                      label: Text(
                        question.bloomTaxonomy!,
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (question.topicTag != null)
                    Chip(
                      label: Text(
                        question.topicTag!,
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (onApprove != null || onReject != null) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                        onPressed: onReject, child: const Text('Reject')),
                    const SizedBox(width: 8),
                    FilledButton(
                        onPressed: onApprove, child: const Text('Approve')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
