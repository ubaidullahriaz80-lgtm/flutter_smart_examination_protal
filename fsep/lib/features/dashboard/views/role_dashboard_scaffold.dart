import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/theme/theme_cubit.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/user_profile_model.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/bloc/auth_event.dart';
import 'dashboard_widgets.dart';

/// Web-portal shell shared by every role dashboard: a persistent sidebar
/// (logo, navigation, profile, log out) on wide screens that collapses into a
/// drawer on narrow ones, plus a slim top bar and the scrollable content area.
class RoleDashboardScaffold extends StatelessWidget {
  const RoleDashboardScaffold({
    super.key,
    required this.title,
    required this.user,
    this.navItems = const [],
    this.profileFuture,
    this.body,
  });

  final String title;
  final UserModel user;

  /// Sidebar destinations (the Dashboard entry is added automatically).
  final List<DashboardNavItem> navItems;

  /// Used for the sidebar profile section; falls back to the role name.
  final Future<UserProfileModel>? profileFuture;
  final Widget? body;

  static const double _wideBreakpoint = 1000;
  static const double _sidebarWidth = 268;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    Widget sidebar({required bool inDrawer}) => _Sidebar(
          user: user,
          navItems: navItems,
          profileFuture: profileFuture,
          inDrawer: inDrawer,
        );

    return Scaffold(
      drawer: isWide
          ? null
          : Drawer(
              width: _sidebarWidth,
              shape: const RoundedRectangleBorder(),
              backgroundColor: DashboardColors.sidebar,
              child: sidebar(inDrawer: true),
            ),
      body: Row(
        children: [
          if (isWide)
            SizedBox(width: _sidebarWidth, child: sidebar(inDrawer: false)),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: title, showMenu: !isWide),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isWide ? 28 : 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: SizedBox(
                          width: double.infinity,
                          child: body ??
                              Center(
                                child: Text(
                                  'Signed in as ${user.id}\nRole: ${user.role.name}',
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.showMenu});

  final String title;
  final bool showMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: showMenu ? 8 : 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          if (showMenu)
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title Dashboard',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Home / Dashboard',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar
// ─────────────────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.user,
    required this.navItems,
    required this.profileFuture,
    required this.inDrawer,
  });

  final UserModel user;
  final List<DashboardNavItem> navItems;
  final Future<UserProfileModel>? profileFuture;
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? DashboardColors.sidebarDark : DashboardColors.sidebar,
      child: SafeArea(
        child: Column(
          children: [
            const _Brand(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  const _SidebarLabel('MENU'),
                  _NavTile(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    selected: true,
                    onTap: () {
                      if (inDrawer) Navigator.of(context).pop();
                    },
                  ),
                  if (navItems.isNotEmpty) const _SidebarLabel('WORKSPACE'),
                  for (final item in navItems)
                    _NavTile(
                      icon: item.icon,
                      label: item.label,
                      badge: item.badge,
                      onTap: () {
                        if (inDrawer) Navigator.of(context).pop();
                        item.open(context);
                      },
                    ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
            _ProfileSection(user: user, profileFuture: profileFuture),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    context.read<AuthBloc>().add(const LogoutRequested());
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.login,
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Log out'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFDA4AF),
                    backgroundColor: const Color(0xFF3A1523),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Examination Portal',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarLabel extends StatelessWidget {
  const _SidebarLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : Colors.white.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? DashboardColors.emerald : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.white.withValues(alpha: 0.07),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null) badge!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.user, required this.profileFuture});

  final UserModel user;
  final Future<UserProfileModel>? profileFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfileModel>(
      future: profileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final hasName = profile != null && profile.name.trim().isNotEmpty;
        final name = hasName ? profile.name : user.role.displayName;
        final subtitle = (profile != null && profile.email.isNotEmpty)
            ? profile.email
            : user.role.displayName;

        return Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF7C3AED),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
