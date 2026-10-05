import 'package:flutter/material.dart';

import '../../features/auth/views/login_view.dart';
import '../../features/dashboard/views/role_dashboard_view.dart';
import '../widgets/splash_view.dart';
import 'app_routes.dart';

/// Named-route table for the app, used with [MaterialApp.routes].
class AppRouter {
  AppRouter._();

  static const String initial = AppRoutes.splash;

  static final Map<String, WidgetBuilder> routes = {
    AppRoutes.splash: (context) => const SplashView(),
    AppRoutes.login: (context) => const LoginView(),
    AppRoutes.dashboard: (context) => const RoleDashboardView(),
  };
}
