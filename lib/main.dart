import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routes/app_router.dart';
import 'features/authentication/data/datasources/local_storage_data_source.dart';
import 'features/authentication/data/datasources/auth_remote_data_source.dart';
import 'features/authentication/data/repositories/auth_repository_impl.dart';
import 'features/authentication/domain/usecases/get_current_user.dart';
import 'features/authentication/domain/usecases/sign_in_with_google.dart';
import 'features/authentication/domain/usecases/sign_out.dart';
import 'features/authentication/presentation/bloc/auth_bloc.dart';
import 'features/authentication/presentation/bloc/auth_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://kpttdmhzunysswgeevrz.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtwdHRkbWh6dW55c3N3Z2VldnJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ5MjUxMjYsImV4cCI6MjA3MDUwMTEyNn0.upHpj9Hoy3EZrS65AmUViXMiHzF_T32HZGH9ujyetxc',
  );

  final supabase = Supabase.instance.client;

  // Data sources
  final localStorageDataSource = LocalStorageDataSourceImpl();
  final authDataSource = AuthRemoteDataSourceImpl(
    supabase,
    localStorageDataSource,
    redirectTo: 'io.supabase.flutterdemo://login-callback', // Deep link
  );

  // Repository
  final authRepository = AuthRepositoryImpl(authDataSource);

  // Use cases
  final signInUseCase = SignInWithGoogle(authRepository);
  final getCurrentUserUseCase = GetCurrentUser(authRepository);
  final signOutUseCase = SignOut(authRepository);

  runApp(
    MyApp(
      signInUseCase: signInUseCase,
      getCurrentUserUseCase: getCurrentUserUseCase,
      signOutUseCase: signOutUseCase,
    ),
  );
}

class MyApp extends StatelessWidget {
  final SignInWithGoogle signInUseCase;
  final GetCurrentUser getCurrentUserUseCase;
  final SignOut signOutUseCase;

  const MyApp({
    super.key,
    required this.signInUseCase,
    required this.getCurrentUserUseCase,
    required this.signOutUseCase,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final authBloc = AuthBloc(
          signInWithGoogle: signInUseCase,
          getCurrentUser: getCurrentUserUseCase,
          signOutUseCase: signOutUseCase,
        );
        authBloc.add(AppStartedEvent());
        return authBloc;
      },
      child: Builder(
        builder: (context) {
          // Get AuthBloc from context
          final authBloc = context.read<AuthBloc>();

          return MaterialApp.router(
            title: 'Flutter Supabase Auth',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            ),
            routerConfig: AppRouter.createRouter(authBloc),
          );
        },
      ),
    );
  }
}