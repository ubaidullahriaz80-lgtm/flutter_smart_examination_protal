import 'package:flutter/material.dart';

import '../../../data/models/exam_model.dart';
import '../../../data/models/question_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_profile_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../data/repositories/question_bank_repository.dart';
import '../../analytics/views/cohort_analytics_view.dart';
import '../../exams/views/exam_management_list_view.dart';
import '../../invigilator/views/live_invigilator_view.dart';
import '../../question_bank/views/ai_question_generator_view.dart';
import '../../question_bank/views/question_bank_list_view.dart';
import 'dashboard_widgets.dart';
import 'role_dashboard_scaffold.dart';

class ExaminerDashboardView extends StatefulWidget {
  const ExaminerDashboardView({super.key, required this.user});

  final UserModel user;

  @override
  State<ExaminerDashboardView> createState() => _ExaminerDashboardViewState();
}

class _ExaminerDashboardViewState extends State<ExaminerDashboardView> {
  final AuthRepository _authRepository = AuthRepository();
  final ExamRepository _examRepository = ExamRepository();
  final QuestionBankRepository _questionBankRepository =
      QuestionBankRepository();

  late Future<UserProfileModel> _profileFuture;
  late Future<List<ExamModel>> _examsFuture;
  late Future<List<QuestionModel>> _questionsFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _authRepository.getProfile();
    _examsFuture = _examRepository.getExams();
    _questionsFuture = _questionBankRepository.getQuestions();
  }

  late final List<DashboardNavItem> _navItems = [
    DashboardNavItem(
      icon: Icons.edit_calendar_outlined,
      label: 'Exam Administration',
      description: 'Create, edit and publish exams',
      builder: (_) => const ExamManagementListView(),
    ),
    DashboardNavItem(
      icon: Icons.quiz_outlined,
      label: 'Question Bank',
      description: 'Browse and manage your questions',
      builder: (_) => const QuestionBankListView(),
    ),
    DashboardNavItem(
      icon: Icons.auto_awesome,
      label: 'AI Question Generator',
      description: 'Generate questions with AI',
      builder: (_) => const AiQuestionGeneratorView(),
    ),
    DashboardNavItem(
      icon: Icons.bar_chart_outlined,
      label: 'Cohort Analytics',
      description: 'Performance across cohorts',
      builder: (_) => const CohortAnalyticsView(),
    ),
    DashboardNavItem(
      icon: Icons.visibility_outlined,
      label: 'Live Invigilator',
      description: 'Monitor active exam sessions',
      builder: (_) => const LiveInvigilatorView(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Examiner',
      user: widget.user,
      profileFuture: _profileFuture,
      navItems: _navItems,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<UserProfileModel>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final profile = snapshot.data;
              return DashboardWelcomeBanner(
                name: profile?.name ?? 'Examiner',
                email: profile?.email,
                roleLabel: widget.user.role.displayName,
                message: 'Build exams, manage questions and monitor results.',
              );
            },
          ),
          const SizedBox(height: 20),
          DashboardTabs(
            tabs: [
              DashboardTab(
                label: 'Overview',
                icon: Icons.dashboard_outlined,
                child: _buildOverview(),
              ),
              DashboardTab(
                label: 'Recent Exams',
                icon: Icons.assignment_outlined,
                child: _buildExams(),
              ),
              DashboardTab(
                label: 'Quick Actions',
                icon: Icons.bolt_outlined,
                child: DashboardActionGrid(items: _navItems),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<List<ExamModel>>(
          future: _examsFuture,
          builder: (context, examSnapshot) {
            final exams = examSnapshot.data;
            return FutureBuilder<List<QuestionModel>>(
              future: _questionsFuture,
              builder: (context, questionSnapshot) {
                final questions = questionSnapshot.data;
                return DashboardStatsRow(
                  stats: [
                    if (exams != null) ...[
                      DashboardStat(
                        'Total Exams',
                        '${exams.length}',
                        icon: Icons.assignment_outlined,
                        color: DashboardColors.emerald,
                      ),
                      DashboardStat(
                        'Published',
                        '${exams.where((e) => e.status == 'published').length}',
                        icon: Icons.check_circle_outline,
                        color: DashboardColors.blue,
                      ),
                      DashboardStat(
                        'Draft',
                        '${exams.where((e) => e.status == 'draft').length}',
                        icon: Icons.edit_note,
                        color: DashboardColors.orange,
                      ),
                    ],
                    if (questions != null)
                      DashboardStat(
                        'Total Questions',
                        '${questions.length}',
                        icon: Icons.quiz_outlined,
                        color: DashboardColors.violet,
                      ),
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
                  title: 'Recent Exams',
                  subtitle: 'Latest exams you created',
                  actionLabel: 'Manage',
                  onAction: () => _navItems.first.open(context),
                ),
                _examList(limit: 3),
              ],
            ),
          ),
          right: DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DashboardPanelHeader(
                  title: 'Exam Status',
                  subtitle: 'How your exams are distributed',
                ),
                _statusBars(),
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
          'Recent Exams',
          subtitle: 'Every exam with its current status',
          padding: EdgeInsets.only(bottom: 14),
        ),
        _examList(),
      ],
    );
  }

  Widget _statusBars() {
    return FutureBuilder<List<ExamModel>>(
      future: _examsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const DashboardLoading();
        }
        final exams = snapshot.data ?? [];
        if (exams.isEmpty) {
          return const DashboardMessage(
            icon: Icons.inbox_outlined,
            message: 'No exams have been created yet.',
          );
        }
        final published = exams.where((e) => e.status == 'published').length;
        final draft = exams.where((e) => e.status == 'draft').length;
        final other = exams.length - published - draft;
        return Column(
          children: [
            DashboardBarRow(
              label: 'Published',
              value: published,
              total: exams.length,
              color: DashboardColors.emerald,
            ),
            DashboardBarRow(
              label: 'Draft',
              value: draft,
              total: exams.length,
              color: DashboardColors.orange,
            ),
            if (other > 0)
              DashboardBarRow(
                label: 'Other',
                value: other,
                total: exams.length,
                color: DashboardColors.blue,
              ),
          ],
        );
      },
    );
  }

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
            message: 'No exams have been created yet.',
          );
        }
        final shown = limit == null ? exams : exams.take(limit).toList();
        return Column(
          children: [for (final exam in shown) _ExamSummaryTile(exam: exam)],
        );
      },
    );
  }
}

class _ExamSummaryTile extends StatelessWidget {
  const _ExamSummaryTile({required this.exam});

  final ExamModel exam;

  Color get _statusColor => switch (exam.status) {
        'published' => DashboardColors.emerald,
        'draft' => DashboardColors.orange,
        _ => DashboardColors.blue,
      };

  @override
  Widget build(BuildContext context) {
    return DashboardListCard(
      icon: Icons.assignment_outlined,
      color: _statusColor,
      title: exam.title,
      subtitle: [
        if (exam.courseCode != null) exam.courseCode!,
        '${exam.durationMinutes} min',
        '${exam.totalMarks} marks',
      ].join(' • '),
      trailing: DashboardPill(label: exam.status, color: _statusColor),
    );
  }
}
