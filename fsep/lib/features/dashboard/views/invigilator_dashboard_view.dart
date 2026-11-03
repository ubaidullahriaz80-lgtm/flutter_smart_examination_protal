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

  late final List<DashboardNavItem> _navItems = [
    DashboardNavItem(
      icon: Icons.visibility_outlined,
      label: 'Live Invigilator',
      description: 'Monitor active exam sessions in real time',
      builder: (_) => const LiveInvigilatorView(),
    ),
  ];

  bool _isFlagged(InvigilatorSessionModel s) =>
      s.suspicion.status == 'suspicious' ||
      s.suspicion.status == 'highly_suspicious' ||
      s.suspicion.status == 'medium' ||
      s.suspicion.status == 'high' ||
      s.suspicion.status == 'critical';

  @override
  Widget build(BuildContext context) {
    return RoleDashboardScaffold(
      title: 'Live Invigilator',
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
                name: profile?.name ?? 'Live Invigilator',
                email: profile?.email,
                roleLabel: widget.user.role.displayName,
                message: 'Watch live sessions and respond to flagged activity.',
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
                label: 'Sessions',
                icon: Icons.groups_outlined,
                child: _sessionList(
                  emptyMessage: 'There are no active sessions right now.',
                ),
              ),
              DashboardTab(
                label: 'Flagged',
                icon: Icons.flag_outlined,
                child: _sessionList(
                  flaggedOnly: true,
                  emptyMessage: 'No sessions have been flagged.',
                ),
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
        FutureBuilder<List<InvigilatorSessionModel>>(
          future: _sessionsFuture,
          builder: (context, snapshot) {
            final sessions = snapshot.data;
            if (sessions == null) return const SizedBox.shrink();
            final active =
                sessions.where((s) => s.status == 'in_progress').length;
            final flagged = sessions.where(_isFlagged).length;
            return DashboardStatsRow(
              stats: [
                DashboardStat(
                  'Total Sessions',
                  '${sessions.length}',
                  icon: Icons.groups_outlined,
                  color: DashboardColors.blue,
                ),
                DashboardStat(
                  'Active Now',
                  '$active',
                  icon: Icons.play_circle_outline,
                  color: DashboardColors.emerald,
                ),
                DashboardStat(
                  'Flagged',
                  '$flagged',
                  icon: Icons.flag_outlined,
                  color: DashboardColors.rose,
                ),
              ],
            );
          },
        ),
        const DashboardSectionTitle(
          'Quick Actions',
          subtitle: 'Open the live monitoring console',
        ),
        DashboardActionGrid(items: _navItems),
      ],
    );
  }

  Widget _sessionList({bool flaggedOnly = false, required String emptyMessage}) {
    return FutureBuilder<List<InvigilatorSessionModel>>(
      future: _sessionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const DashboardLoading();
        }
        if (snapshot.hasError) {
          return const DashboardMessage(
            icon: Icons.error_outline,
            message: 'Unable to load sessions.',
            isError: true,
          );
        }
        final all = snapshot.data ?? [];
        final sessions = flaggedOnly ? all.where(_isFlagged).toList() : all;
        if (sessions.isEmpty) {
          return DashboardMessage(
            icon: Icons.inbox_outlined,
            message: emptyMessage,
          );
        }
        return Column(
          children: [
            for (final s in sessions)
              DashboardListCard(
                icon: _isFlagged(s) ? Icons.flag_outlined : Icons.person_outline,
                color: _isFlagged(s)
                    ? DashboardColors.rose
                    : DashboardColors.blue,
                title: s.candidateName,
                subtitle: [
                  s.examTitle,
                  if (s.courseCode != null) s.courseCode!,
                ].join(' • '),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    DashboardPill(
                      label: s.status.replaceAll('_', ' '),
                      color: s.status == 'in_progress'
                          ? DashboardColors.emerald
                          : DashboardColors.blue,
                    ),
                    if (_isFlagged(s)) ...[
                      const SizedBox(height: 6),
                      DashboardPill(
                        label: s.suspicion.status.replaceAll('_', ' '),
                        color: DashboardColors.rose,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
