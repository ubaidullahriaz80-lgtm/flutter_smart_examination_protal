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

  late final List<DashboardNavItem> _navItems = [
    DashboardNavItem(
      icon: Icons.manage_accounts_outlined,
      label: 'User Management',
      description: 'Add, edit and import user accounts',
      builder: (_) => const UserListView(),
    ),
    DashboardNavItem(
      icon: Icons.business_outlined,
      label: 'Manage Departments',
      description: 'Organise departments and their members',
      builder: (_) => const DepartmentListView(),
    ),
    DashboardNavItem(
      icon: Icons.bar_chart_outlined,
      label: 'Cohort Analytics',
      description: 'Performance trends across cohorts',
      builder: (_) => const CohortAnalyticsView(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'System Administrator',
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
                name: profile?.name ?? 'System Administrator',
                email: profile?.email,
                roleLabel: widget.user.role.displayName,
                message: 'Oversee users, departments and platform activity.',
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
                label: 'Users',
                icon: Icons.people_outline,
                child: _buildUsers(),
              ),
              DashboardTab(
                label: 'Exams',
                icon: Icons.assignment_outlined,
                child: _buildExams(),
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
        FutureBuilder<List<ManagedUserModel>>(
          future: _usersFuture,
          builder: (context, userSnapshot) {
            final users = userSnapshot.data;
            return FutureBuilder<List<ExamModel>>(
              future: _examsFuture,
              builder: (context, examSnapshot) {
                final exams = examSnapshot.data;
                return DashboardStatsRow(
                  stats: [
                    if (users != null) ...[
                      DashboardStat(
                        'Total Users',
                        '${users.length}',
                        icon: Icons.groups_outlined,
                        color: DashboardColors.emerald,
                      ),
                      DashboardStat(
                        'Candidates',
                        '${users.where((u) => u.role == UserRole.candidate).length}',
                        icon: Icons.school_outlined,
                        color: DashboardColors.blue,
                      ),
                      DashboardStat(
                        'Examiners',
                        '${users.where((u) => u.role == UserRole.examiner).length}',
                        icon: Icons.edit_note,
                        color: DashboardColors.violet,
                      ),
                    ],
                    if (exams != null)
                      DashboardStat(
                        'Total Exams',
                        '${exams.length}',
                        icon: Icons.assignment_outlined,
                        color: DashboardColors.orange,
                      ),
                  ],
                );
              },
            );
          },
        ),
        const DashboardSectionTitle(
          'Quick Actions',
          subtitle: 'Jump straight to a management area',
        ),
        DashboardActionGrid(items: _navItems),
      ],
    );
  }

  Widget _buildUsers() {
    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardPanelHeader(
            title: 'Users by Role',
            subtitle: 'How accounts are distributed across roles',
            actionLabel: 'Manage users',
            onAction: () => _navItems.first.open(context),
          ),
          FutureBuilder<List<ManagedUserModel>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const DashboardLoading();
              }
              if (snapshot.hasError) {
                return const DashboardMessage(
                  icon: Icons.error_outline,
                  message: 'Unable to load users.',
                  isError: true,
                );
              }
              final users = snapshot.data ?? [];
              if (users.isEmpty) {
                return const DashboardMessage(
                  icon: Icons.inbox_outlined,
                  message: 'No users have been added yet.',
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < UserRole.values.length; i++)
                    DashboardBarRow(
                      label: UserRole.values[i].displayName,
                      value:
                          users.where((u) => u.role == UserRole.values[i]).length,
                      total: users.length,
                      color: DashboardColors.at(i),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExams() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionTitle(
          'All Exams',
          subtitle: 'Exams across the platform',
          padding: EdgeInsets.only(bottom: 14),
        ),
        FutureBuilder<List<ExamModel>>(
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
            return Column(
              children: [for (final exam in exams) _ExamRow(exam: exam)],
            );
          },
        ),
      ],
    );
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.exam});

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
