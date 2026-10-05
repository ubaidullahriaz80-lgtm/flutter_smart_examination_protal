import 'package:flutter/material.dart';

import '../../../data/models/exam_model.dart';
import '../../../data/models/managed_user_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_profile_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/exam_repository.dart';
import '../../../data/repositories/user_management_repository.dart';
import '../../analytics/views/cohort_analytics_view.dart';
import '../../user_management/views/user_list_view.dart';
import '../../department_management/views/department_list_view.dart';
import 'dashboard_widgets.dart';
import 'role_dashboard_scaffold.dart';

class SystemAdminDashboardView extends StatefulWidget {
  const SystemAdminDashboardView({super.key, required this.user});

  final UserModel user;

  @override
  State<SystemAdminDashboardView> createState() =>
      _SystemAdminDashboardViewState();
}

class _SystemAdminDashboardViewState extends State<SystemAdminDashboardView> {
  final AuthRepository _authRepository = AuthRepository();
  final UserManagementRepository _userManagementRepository =
      UserManagementRepository();
  final ExamRepository _examRepository = ExamRepository();

  late Future<UserProfileModel> _profileFuture;
  late Future<List<ManagedUserModel>> _usersFuture;
  late Future<List<ExamModel>> _examsFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _authRepository.getProfile();
    _usersFuture = _userManagementRepository.getUsers();
    _examsFuture = _examRepository.getExams();
  }

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'System Administrator',
      user: widget.user,
      actions: [
        IconButton(
          tooltip: 'User Management',
          icon: const Icon(Icons.manage_accounts_outlined),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const UserListView(),
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
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<UserProfileModel>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final profile = snapshot.data;
              return DashboardProfileCard(
                name: profile?.name ?? 'System Administrator',
                email: profile?.email,
                roleLabel: widget.user.role.displayName,
              );
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<ManagedUserModel>>(
            future: _usersFuture,
            builder: (context, userSnapshot) {
              final users = userSnapshot.data;
              return FutureBuilder<List<ExamModel>>(
                future: _examsFuture,
                builder: (context, examSnapshot) {
                  final exams = examSnapshot.data;
                  final stats = <DashboardStat>[
                    if (users != null) ...[
                      DashboardStat('Total Users', '${users.length}'),
                      DashboardStat(
                        'Candidates',
                        '${users.where((u) => u.role == UserRole.candidate).length}',
                      ),
                      DashboardStat(
                        'Examiners',
                        '${users.where((u) => u.role == UserRole.examiner).length}',
                      ),
                    ],
                    if (exams != null)
                      DashboardStat('Total Exams', '${exams.length}'),
                  ];
                  if (stats.isEmpty) return const SizedBox.shrink();
                  return DashboardStatsRow(stats: stats);
                },
              );
            },
          ),
          const DashboardSectionTitle('Quick Actions'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              DashboardActionChip(
                icon: Icons.manage_accounts_outlined,
                label: 'User Management',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UserListView()),
                ),
              ),
              DashboardActionChip(
                icon: Icons.bar_chart_outlined,
                label: 'Cohort Analytics',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CohortAnalyticsView()),
                ),
              ),
              DashboardActionChip(
                icon: Icons.business_outlined,
                label: 'Manage Departments',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DepartmentListView()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
