import 'package:flutter/material.dart';

import '../../../data/models/user_model.dart';
import '../../../data/models/user_profile_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/exam_session_repository.dart';
import '../../invigilator/views/live_invigilator_view.dart';
import 'dashboard_widgets.dart';
import 'role_dashboard_scaffold.dart';

class InvigilatorDashboardView extends StatefulWidget {
  const InvigilatorDashboardView({super.key, required this.user});

  final UserModel user;

  @override
  State<InvigilatorDashboardView> createState() =>
      _InvigilatorDashboardViewState();
}

class _InvigilatorDashboardViewState extends State<InvigilatorDashboardView> {
  final AuthRepository _authRepository = AuthRepository();
  final ExamSessionRepository _sessionRepository = ExamSessionRepository();

  late Future<UserProfileModel> _profileFuture;
  late Future<List<InvigilatorSessionModel>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _authRepository.getProfile();
    _sessionsFuture = _sessionRepository.getActiveSessions();
  }

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Live Invigilator',
      user: widget.user,
      actions: [
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
                name: profile?.name ?? 'Live Invigilator',
                email: profile?.email,
                roleLabel: widget.user.role.displayName,
              );
            },
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<InvigilatorSessionModel>>(
            future: _sessionsFuture,
            builder: (context, snapshot) {
              final sessions = snapshot.data;
              if (sessions == null) return const SizedBox.shrink();
              final active =
                  sessions.where((s) => s.status == 'in_progress').length;
              final flagged = sessions
                  .where((s) =>
                      s.suspicion.status == 'suspicious' ||
                      s.suspicion.status == 'highly_suspicious' ||
                      s.suspicion.status == 'medium' ||
                      s.suspicion.status == 'high' ||
                      s.suspicion.status == 'critical')
                  .length;
              return DashboardStatsRow(stats: [
                DashboardStat('Total Sessions', '${sessions.length}'),
                DashboardStat('Active Now', '$active'),
                DashboardStat('Flagged', '$flagged'),
              ]);
            },
          ),
          const DashboardSectionTitle('Quick Actions'),
          DashboardActionChip(
            icon: Icons.visibility_outlined,
            label: 'Open Live Invigilator',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LiveInvigilatorView()),
            ),
          ),
        ],
      ),
    );
  }
}
