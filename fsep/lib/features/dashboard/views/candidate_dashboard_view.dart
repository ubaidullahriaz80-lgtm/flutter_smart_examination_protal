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

  // ── Navigation destinations (sidebar + in-page shortcuts) ──────────────────

  DashboardNavItem _examsItem() => DashboardNavItem(
        icon: Icons.assignment_outlined,
        label: 'Exams',
        description: 'View and take your available exams',
        builder: (_) => const ExamListView(),
      );

  DashboardNavItem _gapsItem() => DashboardNavItem(
        icon: Icons.insights_outlined,
        label: 'Learning Gaps',
        description: 'Review weak topics and your roadmap',
        builder: (_) => const LearningGapsView(),
      );

  DashboardNavItem _syncItem() => DashboardNavItem(
        icon: Icons.sync_problem,
        label: 'Sync Recovery',
        description: 'Resolve answers that failed to sync',
        builder: (_) => const SyncRecoveryView(),
        onReturn: _refreshFailedSyncCount,
        badge: FutureBuilder<int>(
          future: _failedSyncCountFuture,
          builder: (context, snapshot) {
            final count = snapshot.data ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return DashboardCountBadge(count);
          },
        ),
      );

  @override
  Widget build(BuildContext context) {
    final examsItem = _examsItem();
    final gapsItem = _gapsItem();

    return RoleDashboardScaffold(
      title: 'Candidate',
      user: widget.user,
      profileFuture: _profileFuture,
      navItems: [examsItem, gapsItem, _syncItem()],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<UserProfileModel>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final profile = snapshot.data;
              return DashboardWelcomeBanner(
                name: profile?.name ?? 'Candidate',
                email: profile?.email,
                roleLabel: widget.user.role.displayName,
                message: 'Track your exams and learning progress in one place.',
              );
            },
          ),
          const SizedBox(height: 20),
          DashboardTabs(
            tabs: [
              DashboardTab(
                label: 'Overview',
                icon: Icons.dashboard_outlined,
                child: _buildOverview(examsItem, gapsItem),
              ),
              DashboardTab(
                label: 'Exams',
                icon: Icons.assignment_outlined,
                child: _buildExams(),
              ),
              DashboardTab(
                label: 'Learning Gaps',
                icon: Icons.insights_outlined,
                child: _buildGaps(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tabs ───────────────────────────────────────────────────────────────────

  Widget _buildOverview(DashboardNavItem examsItem, DashboardNavItem gapsItem) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<List<ExamModel>>(
          future: _examsFuture,
          builder: (context, examSnapshot) {
            final exams = examSnapshot.data ?? [];
            return FutureBuilder<LearningGapReport>(
              future: _gapsFuture,
              builder: (context, gapSnapshot) {
                final report = gapSnapshot.data;
                return DashboardStatsRow(
                  stats: [
                    if (examSnapshot.connectionState == ConnectionState.done)
                      DashboardStat(
                        'Available Exams',
                        '${exams.length}',
                        icon: Icons.assignment_outlined,
                        color: DashboardColors.emerald,
                      ),
                    if (report != null) ...[
                      DashboardStat(
                        'Topics Analyzed',
                        '${report.topicsAnalyzed}',
                        icon: Icons.analytics_outlined,
                        color: DashboardColors.blue,
                      ),
                      DashboardStat(
                        'Weak Topics',
                        '${report.gaps.length}',
                        icon: Icons.trending_down,
                        color: DashboardColors.orange,
                      ),
                      DashboardStat(
                        'Questions Attempted',
                        '${report.questionsAttempted}',
                        icon: Icons.help_outline,
                        color: DashboardColors.violet,
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 22),
        DashboardTwoColumn(
          left: DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardPanelHeader(
                  title: 'Available Exams',
                  subtitle: 'Pick up where you left off',
                  actionLabel: 'View all',
                  onAction: () => examsItem.open(context),
                ),
                _examList(limit: 3),
              ],
            ),
          ),
          right: DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DashboardPanelHeader(
                  title: 'Learning Gap Summary',
                  subtitle: 'Topics that need more attention',
                  actionLabel: 'View all',
                  onAction: () => gapsItem.open(context),
                ),
                _gapList(limit: 3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExams() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionTitle(
          'Available Exams',
          subtitle: 'Exams you can start right now',
          padding: EdgeInsets.only(bottom: 14),
        ),
        _examList(),
      ],
    );
  }

  Widget _buildGaps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionTitle(
          'Learning Gap Summary',
          subtitle: 'Topics where your performance is below target',
          padding: EdgeInsets.only(bottom: 14),
        ),
        _gapList(),
      ],
    );
  }

  // ── Data-bound lists ───────────────────────────────────────────────────────

  Widget _examList({int? limit}) {
    return FutureBuilder<List<ExamModel>>(
      future: _examsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const DashboardLoading();
        }
        if (snapshot.hasError) {
          return const DashboardMessage(
            icon: Icons.error_outline,
            message: 'Unable to load exams.',
            isError: true,
          );
        }
        final exams = snapshot.data ?? [];
        if (exams.isEmpty) {
          return const DashboardMessage(
            icon: Icons.inbox_outlined,
            message: 'No exams are available yet.',
          );
        }
        final shown = limit == null ? exams : exams.take(limit).toList();
        return Column(
          children: [for (final exam in shown) _ExamPreviewCard(exam: exam)],
        );
      },
    );
  }

  Widget _gapList({int? limit}) {
    return FutureBuilder<LearningGapReport>(
      future: _gapsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const DashboardLoading();
        }
        if (snapshot.hasError) {
          return const DashboardMessage(
            icon: Icons.error_outline,
            message: 'Unable to load learning gaps.',
            isError: true,
          );
        }
        final report = snapshot.data;
        if (report == null || report.gaps.isEmpty) {
          return const DashboardMessage(
            icon: Icons.emoji_events_outlined,
            message: 'No weak topics identified yet — keep taking exams to '
                'build up your performance history.',
          );
        }
        final gaps = limit == null ? report.gaps : report.gaps.take(limit);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final gap in gaps) _GapRow(gap: gap)],
        );
      },
    );
  }
}

class _ExamPreviewCard extends StatelessWidget {
  const _ExamPreviewCard({required this.exam});

  final ExamModel exam;

  @override
  Widget build(BuildContext context) {
    return DashboardListCard(
      icon: Icons.assignment_outlined,
      color: DashboardColors.blue,
      title: exam.title,
      chips: [
        DashboardMetaChip(
          icon: Icons.timer_outlined,
          label: '${exam.durationMinutes} min',
        ),
        DashboardMetaChip(
          icon: Icons.help_outline,
          label: '${exam.questions.length} questions',
        ),
      ],
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: DashboardColors.emerald,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Start',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ExamDeliveryView(examId: exam.id),
          ),
        );
      },
    );
  }
}

class _GapRow extends StatelessWidget {
  const _GapRow({required this.gap});

  final LearningGapModel gap;

  Color get _severityColor => switch (gap.severity) {
        'high' => DashboardColors.rose,
        _ => DashboardColors.orange,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _severityColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DashboardPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.trending_down,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    gap.topic,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DashboardPill(label: gap.severity, color: color),
              ],
            ),
            const SizedBox(height: 12),
            DashboardBarRow(
              label: 'Performance',
              value: gap.percentage,
              total: 100,
              color: color,
              valueLabel: '${gap.percentage.toStringAsFixed(1)}%',
              bottomPadding: 0,
            ),
          ],
        ),
      ),
    );
  }
}
