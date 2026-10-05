import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../data/models/exam_model.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../exam_delivery/views/exam_delivery_view.dart';
import '../bloc/exam_bloc.dart';
import '../bloc/exam_event.dart';
import '../bloc/exam_state.dart';
import '../../../core/utils/responsive.dart';

class ExamListView extends StatelessWidget {
  const ExamListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ExamBloc(
        repository: ExamRepository(),
      )..add(const LoadExams()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exams'),
        ),
        body: BlocBuilder<ExamBloc, ExamState>(
          builder: (context, state) {
            if (state is ExamLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state is ExamError) {
              return _ErrorView(
                onRetry: () {
                  context.read<ExamBloc>().add(const LoadExams());
                },
              );
            }

            if (state is ExamLoaded) {
              final exams = state.exams;

              if (exams.isEmpty) {
                return const Center(
                  child: Text(
                    'No exams available.',
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
                child: context.isMobile
                    ? ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: exams.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final exam = exams[index];
                          return _ExamCard(exam: exam);
                        },
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(24),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: context.isDesktop ? 3 : 2,
                          childAspectRatio: 1.4,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: exams.length,
                        itemBuilder: (context, index) {
                          final exam = exams[index];
                          return _ExamCard(exam: exam);
                        },
                      ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({
    required this.exam,
  });

  final ExamModel exam;

  bool get _isLocked => exam.startsAt != null && DateTime.now().isBefore(exam.startsAt!);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: _isLocked
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ExamDeliveryView(examId: exam.id),
                    ),
                  );
                },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isLocked 
                            ? Colors.grey.withValues(alpha: 0.1)
                            : theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isLocked ? Icons.lock_outline : Icons.description_outlined, 
                        color: _isLocked ? Colors.grey : theme.colorScheme.primary, 
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exam.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _isLocked ? Colors.grey : null,
                            ),
                          ),
                          if (exam.courseCode != null)
                            Text(
                              exam.courseCode!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _isLocked ? Colors.grey : theme.colorScheme.primary, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_isLocked)
                      const _LockedChip()
                    else
                      _StatusChip(status: exam.status),
                  ],
                ),
                if (_isLocked) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        'Scheduled for ${DateFormat('MMM dd, hh:mm a').format(exam.startsAt!)}',
                        style: const TextStyle(
                          fontSize: 12, 
                          color: Colors.orange, 
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                if (exam.description != null && exam.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    exam.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _isLocked ? Colors.grey : Colors.grey[600],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _InfoBadge(
                      icon: Icons.timer_outlined,
                      label: '${exam.durationMinutes}m',
                    ),
                    _InfoBadge(
                      icon: Icons.grade_outlined,
                      label: '${exam.totalMarks} pts',
                    ),
                    _InfoBadge(
                      icon: Icons.quiz_outlined,
                      label: '${exam.questions.length} items',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedChip extends StatelessWidget {
  const _LockedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: const Text(
        'LOCKED',
        style: TextStyle(
          fontSize: 9, 
          color: Colors.orange, 
          fontWeight: FontWeight.w800, 
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'published' ? const Color(0xFF10B981) : Colors.grey;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.onRetry,
  });

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
