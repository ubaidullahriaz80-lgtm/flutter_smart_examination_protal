import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/exam_model.dart';
import '../../../data/models/learning_gap_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_profile_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../data/repositories/learning_gap_repository.dart';
import '../../../data/repositories/pending_answer_repository.dart';
import '../../exam_delivery/views/exam_delivery_view.dart';
import '../../exam_delivery/views/sync_recovery_view.dart';
import '../../exams/views/exam_list_view.dart';
import '../../learning_gaps/views/learning_gaps_view.dart';
import 'dashboard_widgets.dart';
import 'role_dashboard_scaffold.dart';

class CandidateDashboardView extends StatefulWidget {
  const CandidateDashboardView({
    super.key,
    required this.user,
  });

  final UserModel user;

  @override
  State<CandidateDashboardView> createState() =>
      _CandidateDashboardViewState();
}

class _CandidateDashboardViewState extends State<CandidateDashboardView> {
  final AuthRepository _authRepository = AuthRepository();
  final ExamRepository _examRepository = ExamRepository();
  final LearningGapRepository _learningGapRepository = LearningGapRepository();

  late Future<UserProfileModel> _profileFuture;
  late Future<List<ExamModel>> _examsFuture;
  late Future<LearningGapReport> _gapsFuture;
  Future<int>? _failedSyncCountFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _authRepository.getProfile();
    _examsFuture = _examRepository.getExams();
    _gapsFuture = _learningGapRepository.getLearningGaps();
    _failedSyncCountFuture = _loadFailedSyncCount();
  }

  Future<int> _loadFailedSyncCount() async {
    final repo = context.read<PendingAnswerRepository>();
    final failed = await repo.getAllFailedAnswers();
    return failed.length;
  }

  void _refreshFailedSyncCount() {
    setState(() {
      _failedSyncCountFuture = _loadFailedSyncCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Candidate',
      user: widget.user,
      actions: [
        FutureBuilder<int>(
          future: _failedSyncCountFuture,
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            return IconButton(
              tooltip: 'Sync Recovery',
              icon: count > 0
                  ? Badge(
                      label: Text('$count'),
                      child: const Icon(Icons.sync_problem),
                    )
                  : const Icon(Icons.sync_problem),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SyncRecoveryView()),
                );
                _refreshFailedSyncCount();
              },
            );
          },
        ),
        IconButton(
          tooltip: 'Exams',
          icon: const Icon(Icons.assignment_outlined),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ExamListView()),
            );
          },
        ),
        IconButton(
          tooltip: 'Learning Gaps',
          icon: const Icon(Icons.insights_outlined),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LearningGapsView()),
            );
          },
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<UserProfileModel>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final profile = snapshot.data;
              return DashboardProfileCard(
                name: profile?.name ?? 'Candidate',
                email: profile?.email,
                roleLabel: widget.user.role.displayName,
              );
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<ExamModel>>(
            future: _examsFuture,
            builder: (context, examSnapshot) {
              final exams = examSnapshot.data ?? [];
              return FutureBuilder<LearningGapReport>(
                future: _gapsFuture,
                builder: (context, gapSnapshot) {
                  final report = gapSnapshot.data;
                  final stats = <DashboardStat>[
                    if (examSnapshot.connectionState == ConnectionState.done)
                      DashboardStat('Available Exams', '${exams.length}'),
                    if (report != null) ...[
                      DashboardStat(
                        'Topics Analyzed',
                        '${report.topicsAnalyzed}',
                      ),
                      DashboardStat(
                        'Weak Topics',
                        '${report.gaps.length}',
                      ),
                    ],
                  ];
                  if (stats.isEmpty) return const SizedBox.shrink();
                  return DashboardStatsRow(stats: stats);
                },
              );
            },
          ),
          const DashboardSectionTitle('Available Exams'),
          FutureBuilder<List<ExamModel>>(
            future: _examsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return const Text('Unable to load exams.');
              }
              final exams = snapshot.data ?? [];
              if (exams.isEmpty) {
                return const Text('No exams are available yet.');
              }
              return Column(
                children: [
                  for (final exam in exams.take(3)) _ExamPreviewCard(exam: exam),
                ],
              );
            },
          ),
          const DashboardSectionTitle('Learning Gap Summary'),
          FutureBuilder<LearningGapReport>(
            future: _gapsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return const Text('Unable to load learning gaps.');
              }
              final report = snapshot.data;
              if (report == null || report.gaps.isEmpty) {
                return const Text(
                  'No weak topics identified yet — keep taking exams to '
                  'build up your performance history.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final gap in report.gaps.take(3))
                    _GapRow(gap: gap),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExamPreviewCard extends StatelessWidget {
  const _ExamPreviewCard({required this.exam});

  final ExamModel exam;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExamDeliveryView(examId: exam.id),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.assignment_outlined, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${exam.durationMinutes} minutes • ${exam.questions.length} questions',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow({required this.gap});

  final LearningGapModel gap;

  Color _severityColor(BuildContext context) => switch (gap.severity) {
        'high' => Theme.of(context).colorScheme.error,
        _ => Colors.orange,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.trending_down, color: _severityColor(context)),
        title: Text(gap.topic),
        subtitle: Text('${gap.percentage.toStringAsFixed(1)}% performance'),
        trailing: Chip(
          label: Text(
            gap.severity.toUpperCase(),
            style: TextStyle(fontSize: 11, color: _severityColor(context)),
          ),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}
