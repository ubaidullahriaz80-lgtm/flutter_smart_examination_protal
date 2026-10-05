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

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Institutional Administrator',
      user: widget.user,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final overview = snapshot.data?['overview'] ?? {};
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<UserProfileModel>(
                future: _profileFuture,
                builder: (context, profileSnapshot) {
                  final profile = profileSnapshot.data;
                  return DashboardProfileCard(
                    name: profile?.name ?? 'Institutional Admin',
                    email: profile?.email,
                    roleLabel: widget.user.role.displayName,
                  );
                },
              ),
              const SizedBox(height: 20),
              DashboardStatsRow(
                stats: [
                  DashboardStat('Departments', '${overview['total_departments'] ?? 0}'),
                  DashboardStat('Faculty', '${overview['total_faculty'] ?? 0}'),
                  DashboardStat('Students', '${overview['total_students'] ?? 0}'),
                  DashboardStat('Active Exams', '${overview['active_exams'] ?? 0}'),
                ],
              ),
              const DashboardSectionTitle('Quick Actions'),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  DashboardActionChip(
                    icon: Icons.business_outlined,
                    label: 'Manage Departments',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DepartmentListView()),
                    ),
                  ),
                  DashboardActionChip(
                    icon: Icons.people_outline,
                    label: 'Faculty & Students',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UserListView()),
                    ),
                  ),
                  DashboardActionChip(
                    icon: Icons.insights_outlined,
                    label: 'Institutional Analytics',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const InstitutionalAnalyticsView()),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
