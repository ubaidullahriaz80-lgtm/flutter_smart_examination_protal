import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/exam_model.dart';
import '../../../data/repositories/exam_repository.dart';
import '../bloc/exam_bloc.dart';
import '../bloc/exam_event.dart';
import '../bloc/exam_state.dart';
import 'exam_form_view.dart';

/// Examiner's Exam Administration list (GET /api/exams). Distinct from the
/// candidate-facing ExamListView, which taps straight into taking an exam —
/// this one taps into editing, and adds create/delete.
class ExamManagementListView extends StatelessWidget {
  const ExamManagementListView({super.key});

  Future<void> _openCreateForm(BuildContext context) async {
    final bloc = context.read<ExamBloc>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ExamFormView(),
      ),
    );

    if (created == true) {
      bloc.add(const RefreshExams());
    }
  }

  Future<void> _openEditForm(BuildContext context, ExamModel exam) async {
    final bloc = context.read<ExamBloc>();
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExamFormView(existingExam: exam),
      ),
    );

    if (updated == true) {
      bloc.add(const RefreshExams());
    }
  }

  Future<void> _confirmAndDelete(BuildContext context, ExamModel exam) async {
    final bloc = context.read<ExamBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Exam?'),
        content: Text(
          'Are you sure you want to delete "${exam.title}"? '
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

    bloc.add(DeleteExam(exam.id));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExamBloc(
        repository: ExamRepository(),
      )..add(const LoadExams()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exam Administration'),
          actions: [
            Builder(builder: (context) {
              return IconButton(
                tooltip: 'Add Exam',
                icon: const Icon(Icons.add),
                onPressed: () => _openCreateForm(context),
              );
            }),
          ],
        ),
        body: BlocListener<ExamBloc, ExamState>(
          listener: (context, state) {
            if (state is ExamError) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.message)));
            }
          },
          child: BlocBuilder<ExamBloc, ExamState>(
            builder: (context, state) {
              if (state is ExamLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (state is ExamError && state.message.contains('Unable to load')) {
                return _ErrorView(
                  onRetry: () {
                    context.read<ExamBloc>().add(const LoadExams());
                  },
                );
              }

              final exams = state is ExamLoaded ? state.exams : <ExamModel>[];

              if (exams.isEmpty && state is ExamLoaded) {
                return const Center(
                  child: Text(
                    'No exams yet. Tap + to create one.',
                    style: TextStyle(fontSize: 16),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  final bloc = context.read<ExamBloc>();
                  bloc.add(const RefreshExams());
                  await bloc.stream.firstWhere((s) => s is! ExamLoading);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: exams.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final exam = exams[index];

                    return _ExamManagementCard(
                      exam: exam,
                      onTap: () => _openEditForm(context, exam),
                      onDelete: () => _confirmAndDelete(context, exam),
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

class _ExamManagementCard extends StatelessWidget {
  const _ExamManagementCard({
    required this.exam,
    required this.onTap,
    required this.onDelete,
  });

  final ExamModel exam;
  final VoidCallback onTap;
  final VoidCallback onDelete;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      exam.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      exam.status.toUpperCase(),
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
                ],
              ),
              if (exam.description != null &&
                  exam.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  exam.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  if (exam.courseCode != null)
                    _InfoItem(
                      icon: Icons.menu_book_outlined,
                      label: exam.courseCode!,
                    ),
                  _InfoItem(
                    icon: Icons.timer_outlined,
                    label: '${exam.durationMinutes} min',
                  ),
                  _InfoItem(
                    icon: Icons.grade_outlined,
                    label: '${exam.totalMarks} marks',
                  ),
                  _InfoItem(
                    icon: Icons.quiz_outlined,
                    label: '${exam.questions.length} questions',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load exams.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
