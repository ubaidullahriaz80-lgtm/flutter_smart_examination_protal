import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/connectivity/connectivity_service.dart';
import 'core/constants/app_constants.dart';
import 'core/notifications/notification_service.dart';
import 'core/routes/app_router.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/pending_answer_repository.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase Push Notifications
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Notification Service
  await NotificationService.initialize();

  // Initialize background connectivity and sync services
  final connectivityService = ConnectivityService();
  final syncService = SyncService(connectivityService: connectivityService);

  await connectivityService.start();

  // Subscribe sync engine to network connectivity state updates
  syncService.startListening();

  runApp(FsepApp(
    connectivityService: connectivityService,
    syncService: syncService,
  ));
}

class FsepApp extends StatelessWidget {
  const FsepApp({
    super.key,
    this.authRepository,
    this.connectivityService,
    this.syncService,
  });

  final AuthRepository? authRepository;
  final ConnectivityService? connectivityService;
  final SyncService? syncService;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(
          create: (_) => authRepository ?? AuthRepository(),
        ),
        RepositoryProvider<NotificationRepository>(
          create: (_) => NotificationRepository(),
        ),
        RepositoryProvider<PendingAnswerRepository>(
          create: (_) => PendingAnswerRepository(),
        ),
        RepositoryProvider<ConnectivityService>(
          create: (_) => connectivityService ?? ConnectivityService(),
        ),
        RepositoryProvider<SyncService>(
          create: (_) => syncService ?? SyncService(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
              notificationRepository: context.read<NotificationRepository>(),
            ),
          ),
          BlocProvider<ThemeCubit>(
            create: (_) => ThemeCubit(),
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp(
              navigatorKey: NotificationService.navigatorKey,
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeMode,
              initialRoute: AppRouter.initial,
              routes: AppRouter.routes,
            );
          },
        ),
      ),
    );
  }
}
