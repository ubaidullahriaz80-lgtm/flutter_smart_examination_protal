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

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Examiner',
      user: widget.user,
      actions: [
        IconButton(
          tooltip: 'Exam Administration',
          icon: const Icon(Icons.edit_calendar_outlined),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ExamManagementListView(),
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Question Bank',
          icon: const Icon(Icons.quiz_outlined),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const QuestionBankListView(),
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Cohort Analytics',
          icon: const Icon(Icons.bar_chart_outlined),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CohortAnalyticsView(),
              ),
            );
          },
        ),
        IconButton(
          tooltip: 'Live Invigilator',
          icon: const Icon(Icons.visibility_outlined),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const LiveInvigilatorView(),
              ),
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
                name: profile?.name ?? 'Examiner',
                email: profile?.email,
                roleLabel: widget.user.role.displayName,
              );
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<ExamModel>>(
            future: _examsFuture,
            builder: (context, examSnapshot) {
              final exams = examSnapshot.data;
              return FutureBuilder<List<QuestionModel>>(
                future: _questionsFuture,
                builder: (context, questionSnapshot) {
                  final questions = questionSnapshot.data;
                  final stats = <DashboardStat>[
                    if (exams != null) ...[
                      DashboardStat('Total Exams', '${exams.length}'),
                      DashboardStat(
                        'Published',
                        '${exams.where((e) => e.status == 'published').length}',
                      ),
                      DashboardStat(
                        'Draft',
                        '${exams.where((e) => e.status == 'draft').length}',
                      ),
                    ],
                    if (questions != null)
                      DashboardStat('Total Questions', '${questions.length}'),
                  ];
                  if (stats.isEmpty) return const SizedBox.shrink();
                  return DashboardStatsRow(stats: stats);
                },
              );
            },
          ),
          const DashboardSectionTitle('Recent Exams'),
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
                return const Text('No exams have been created yet.');
              }
              return Column(
                children: [
                  for (final exam in exams.take(3)) _ExamSummaryTile(exam: exam),
                ],
              );
            },
          ),
          const DashboardSectionTitle('Quick Actions'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              DashboardActionChip(
                icon: Icons.edit_calendar_outlined,
                label: 'Exam Administration',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ExamManagementListView(),
                  ),
                ),
              ),
              DashboardActionChip(
                icon: Icons.quiz_outlined,
                label: 'Question Bank',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const QuestionBankListView()),
                ),
              ),
              DashboardActionChip(
                icon: Icons.auto_awesome,
                label: 'AI Question Generator',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AiQuestionGeneratorView(),
                  ),
                ),
              ),
              DashboardActionChip(
                icon: Icons.bar_chart_outlined,
                label: 'Cohort Analytics',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CohortAnalyticsView()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExamSummaryTile extends StatelessWidget {
  const _ExamSummaryTile({required this.exam});

  final ExamModel exam;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(exam.title),
        subtitle: Text(
          [
            if (exam.courseCode != null) exam.courseCode!,
            '${exam.durationMinutes} min',
            '${exam.totalMarks} marks',
          ].join(' • '),
        ),
        trailing: Chip(
          label: Text(
            exam.status.toUpperCase(),
            style: const TextStyle(fontSize: 11),
          ),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

