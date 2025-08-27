// main.dart - Updated version with permission support
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    redirectTo: 'io.supabase.flutterdemo://login-callback',
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
          final authBloc = context.read<AuthBloc>();

          return MaterialApp.router(
            title: 'Question Paper System',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
            ),
            routerConfig: AppRouter.createRouter(authBloc),
          );
        },
      ),
    );
  }
}

// Add this fixed PermissionService to your main.dart
class PermissionService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Quick check if current user is admin - FIXED!
  static Future<bool> isAdmin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 🔥 FIX: Use the correct key 'user_role' instead of 'role'
      final role = prefs.getString('user_role');
      return role == 'admin';
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  /// Quick check for paper creation permission
  static Future<bool> canCreatePapers() async {
    try {
      if (await isAdmin()) return true;

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final tenantId = prefs.getString('tenant_id');

      if (userId == null || tenantId == null) return false;

      final data = await _supabase
          .from('user_permissions')
          .select('can_create_papers')
          .eq('user_id', userId)
          .eq('tenant_id', tenantId)
          .maybeSingle();

      return data?['can_create_papers'] as bool? ?? false;
    } catch (e) {
      print('Error checking paper creation permission: $e');
      return false;
    }
  }

  /// Debug method to check all stored user data
  static Future<void> debugUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      print('=== PermissionService Debug ===');
      print('user_id: ${prefs.getString('user_id')}');
      print('tenant_id: ${prefs.getString('tenant_id')}');
      print('user_role: ${prefs.getString('user_role')}');
      print('full_name: ${prefs.getString('full_name')}');
      print('All keys: ${prefs.getKeys()}');
      print('==============================');
    } catch (e) {
      print('Error in debugUserData: $e');
    }
  }
}
