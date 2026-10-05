import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/user_model.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_state.dart';
import 'candidate_dashboard_view.dart';
import 'examiner_dashboard_view.dart';
import 'institutional_admin_dashboard_view.dart';
import 'invigilator_dashboard_view.dart';
import 'system_admin_dashboard_view.dart';

class RoleDashboardView extends StatelessWidget {
  const RoleDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    if (state is! AuthAuthenticated) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = state.user;
    return switch (user.role) {
      UserRole.systemAdministrator => SystemAdminDashboardView(user: user),
      UserRole.institutionalAdministrator =>
        InstitutionalAdminDashboardView(user: user),
      UserRole.examiner => ExaminerDashboardView(user: user),
      UserRole.liveInvigilator => InvigilatorDashboardView(user: user),
      UserRole.candidate => CandidateDashboardView(user: user),
    };
  }
}
