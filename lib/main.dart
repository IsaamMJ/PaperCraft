import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/config/app_config.dart';
import 'core/di/injection_container.dart';
import 'core/routes/app_router.dart';
import 'core/services/permission_service.dart';
import 'core/utils/app_logger.dart';
import 'features/authentication/domain/usecases/auth_usecase.dart';
import 'features/authentication/presentation/bloc/auth_bloc.dart';
import 'features/authentication/presentation/bloc/auth_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await setupDependencies();
    if (AppConfig.isDebug) await PermissionService.debugUserData();
    runApp(const PaperCraftApp());
  } catch (e) {
    AppLogger.error('Failed to initialize app', e);
  }
}

class PaperCraftApp extends StatelessWidget {
  const PaperCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (context) => AuthBloc(sl<AuthUseCase>())..add(const AuthInitialize()),
      child: Builder(
        builder: (context) => MaterialApp.router(
          title: AppConfig.appName,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            ),
          ),
          debugShowCheckedModeBanner: false,
          routerConfig: AppRouter.createRouter(context.read<AuthBloc>()),
        ),
      ),
    );
  }
}