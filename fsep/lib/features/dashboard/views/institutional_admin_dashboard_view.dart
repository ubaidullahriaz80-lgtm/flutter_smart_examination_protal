import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_profile_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../user_management/views/user_list_view.dart';
import '../../department_management/views/department_list_view.dart';
import '../../analytics/views/institutional_analytics_view.dart';
import 'dashboard_widgets.dart';
import 'role_dashboard_scaffold.dart';

class InstitutionalAdminDashboardView extends StatefulWidget {
  const InstitutionalAdminDashboardView({super.key, required this.user});

  final UserModel user;

  @override
  State<InstitutionalAdminDashboardView> createState() =>
      _InstitutionalAdminDashboardViewState();
}

class _InstitutionalAdminDashboardViewState
    extends State<InstitutionalAdminDashboardView> {
  final AuthRepository _authRepository = AuthRepository();
  late Future<UserProfileModel> _profileFuture;
  late Future<Map<String, dynamic>> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _authRepository.getProfile();
    _analyticsFuture = _fetchAnalytics();
  }

  Future<Map<String, dynamic>> _fetchAnalytics() async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>('/analytics/institutional');
    return response.data ?? {};
  }

  late final List<DashboardNavItem> _navItems = [
    DashboardNavItem(
      icon: Icons.business_outlined,
      label: 'Manage Departments',
      description: 'Organise departments and their members',
      builder: (_) => const DepartmentListView(),
    ),
    DashboardNavItem(
      icon: Icons.people_outline,
      label: 'Faculty & Students',
      description: 'Manage faculty and student accounts',
      builder: (_) => const UserListView(),
    ),
    DashboardNavItem(
      icon: Icons.insights_outlined,
      label: 'Institutional Analytics',
      description: 'Institution-wide performance insights',
      builder: (_) => const InstitutionalAnalyticsView(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Institutional Administrator',
      user: widget.user,
      profileFuture: _profileFuture,
      navItems: _navItems,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<UserProfileModel>(
            future: _profileFuture,
            builder: (context, profileSnapshot) {
              final profile = profileSnapshot.data;
              return DashboardWelcomeBanner(
                name: profile?.name ?? 'Institutional Admin',
                email: profile?.email,
                roleLabel: widget.user.role.displayName,
                message: 'Keep an eye on departments, people and exam activity.',
              );
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<Map<String, dynamic>>(
            future: _analyticsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const DashboardLoading();
              }
              final overview = snapshot.data?['overview'] ?? {};
              return DashboardTabs(
                tabs: [
                  DashboardTab(
                    label: 'Overview',
                    icon: Icons.dashboard_outlined,
                    child: _buildOverview(overview),
                  ),
                  DashboardTab(
                    label: 'People & Capacity',
                    icon: Icons.groups_outlined,
                    child: _buildPeople(overview),
                  ),
                  DashboardTab(
                    label: 'Analytics',
                    icon: Icons.insights_outlined,
                    child: _buildAnalytics(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOverview(dynamic overview) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardStatsRow(
          stats: [
            DashboardStat(
              'Departments',
              '${overview['total_departments'] ?? 0}',
              icon: Icons.business_outlined,
              color: DashboardColors.emerald,
            ),
            DashboardStat(
              'Faculty',
              '${overview['total_faculty'] ?? 0}',
              icon: Icons.co_present_outlined,
              color: DashboardColors.blue,
            ),
            DashboardStat(
              'Students',
              '${overview['total_students'] ?? 0}',
              icon: Icons.school_outlined,
              color: DashboardColors.violet,
            ),
            DashboardStat(
              'Active Exams',
              '${overview['active_exams'] ?? 0}',
              icon: Icons.assignment_outlined,
              color: DashboardColors.orange,
            ),
          ],
        ),
        const DashboardSectionTitle(
          'Quick Actions',
          subtitle: 'Jump straight to a management area',
        ),
        DashboardActionGrid(items: _navItems),
      ],
    );
  }

  Widget _buildPeople(dynamic overview) {
    num read(String key) {
      final value = overview[key];
      return value is num ? value : 0;
    }

    final faculty = read('total_faculty');
    final students = read('total_students');
    final people = faculty + students;

    return DashboardTwoColumn(
      left: DashboardPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DashboardPanelHeader(
              title: 'People Mix',
              subtitle: 'Faculty and students across the institution',
            ),
            DashboardBarRow(
              label: 'Faculty',
              value: faculty,
              total: people,
              color: DashboardColors.blue,
            ),
            DashboardBarRow(
              label: 'Students',
              value: students,
              total: people,
              color: DashboardColors.violet,
              bottomPadding: 0,
            ),
          ],
        ),
      ),
      right: DashboardPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DashboardPanelHeader(
              title: 'Capacity',
              subtitle: 'Departments and live exam load',
            ),
            _MetricRow(
              icon: Icons.business_outlined,
              label: 'Departments',
              value: '${read('total_departments')}',
              color: DashboardColors.emerald,
            ),
            const SizedBox(height: 12),
            _MetricRow(
              icon: Icons.assignment_outlined,
              label: 'Active Exams',
              value: '${read('active_exams')}',
              color: DashboardColors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalytics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardSectionTitle(
          'Institutional Analytics',
          subtitle: 'Dive into institution-wide performance',
          padding: EdgeInsets.only(bottom: 14),
        ),
        DashboardActionGrid(items: [_navItems.last]),
      ],
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
