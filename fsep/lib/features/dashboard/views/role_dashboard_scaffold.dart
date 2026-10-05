import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../data/models/user_model.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';

class RoleDashboardScaffold extends StatelessWidget {
  const RoleDashboardScaffold({
    super.key,
    required this.title,
    required this.user,
    this.actions,
    this.body,
  });

  final String title;
  final UserModel user;
  final List<Widget>? actions;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, mode) {
              return IconButton(
                icon: Icon(
                  mode == ThemeMode.dark
                      ? Icons.light_mode
                      : mode == ThemeMode.light
                          ? Icons.dark_mode
                          : Icons.brightness_auto,
                ),
                tooltip: 'Toggle Theme',
                onPressed: () {
                  final cubit = context.read<ThemeCubit>();
                  if (mode == ThemeMode.system) {
                    cubit.toggleTheme(false);
                  } else if (mode == ThemeMode.light) {
                    cubit.toggleTheme(true);
                  } else {
                    cubit.setSystemTheme();
                  }
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () {
              context.read<AuthBloc>().add(const LogoutRequested());
              Navigator.of(context).pushNamedAndRemoveUntil(
                AppRoutes.login,
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: body != null
          ? SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: body!,
              ),
            )
          : Center(
              child: Text('Signed in as ${user.id}\nRole: ${user.role.name}'),
            ),
    );
  }
}
