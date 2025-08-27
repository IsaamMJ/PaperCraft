import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/logger.dart';
import '../models/user_model.dart';
import '../models/auth_session_model.dart';
import 'local_storage_data_source.dart';

abstract class AuthRemoteDataSource {
  Future<(UserModel, AuthSessionModel)> signInWithGoogle();
  Future<UserModel?> getCurrentUser();
  Future<void> signOut();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient supabase;
  final LocalStorageDataSource localStorage;
  final Duration oauthTimeout;
  final String redirectTo;

  AuthRemoteDataSourceImpl(
      this.supabase,
      this.localStorage, {
        required this.redirectTo,
        this.oauthTimeout = const Duration(seconds: 30),
      });

  @override
  Future<(UserModel, AuthSessionModel)> signInWithGoogle() async {
    final launched = await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );

    if (!launched) {
      throw Exception('Failed to start OAuth flow.');
    }

    final completer = Completer<Session?>();
    late final StreamSubscription sub;

    sub = supabase.auth.onAuthStateChange.listen((event) {
      final session = supabase.auth.currentSession;
      if (session != null && !completer.isCompleted) {
        completer.complete(session);
      }

      // Listen for auth errors (like domain restrictions)
      if (event.event == AuthChangeEvent.signedOut && !completer.isCompleted) {
        completer.complete(null);
      }
    });

    Session? session;
    try {
      session = await completer.future.timeout(oauthTimeout);
    } on TimeoutException {
      await sub.cancel();
      throw Exception('OAuth sign-in timed out.');
    } catch (e) {
      await sub.cancel();
      throw Exception('OAuth sign-in failed: $e');
    } finally {
      await sub.cancel();
    }

    if (session == null || session.user == null) {
      throw Exception('Sign-in failed. Please try again.');
    }

    final user = session.user!;
    final userJson = user.toJson();
    final sessionJson = session.toJson();

    // Wait for profile creation (database trigger should handle this)
    final profileData = await _waitForProfile(user.id);

    if (profileData == null) {
      throw Exception('Profile creation failed. Please try again or contact administrator.');
    }

    final role = profileData['role'] as String?;
    final tenantId = profileData['tenant_id'] as String?;
    final userId = profileData['id'] as String;
    final fullName = profileData['full_name'] as String?;

    // Check if user is blocked due to unauthorized domain
    if (role == null || role == 'blocked' || tenantId == null || tenantId.isEmpty) {
      LoggingService.debug('User blocked due to unauthorized domain or missing role: ${user.email}');

      // Sign out the blocked user
      await supabase.auth.signOut();

      throw Exception('Access denied. Your organization domain is not authorized to use this application. Please contact your administrator.');
    }

    // Save to local storage - role is now required
    await localStorage.saveUserData(
      tenantId: tenantId,
      userId: userId,
      fullName: fullName,
      role: role, // Now guaranteed to be non-null
    );

    LoggingService.debug('User signed in successfully: ${user.email} -> tenant: $tenantId, role: $role');

    return (
    UserModel.fromSupabaseUser(userJson),
    AuthSessionModel.fromSupabaseSession(sessionJson)
    );
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      LoggingService.debug('Getting current user');
      final user = supabase.auth.currentUser;
      LoggingService.debug('Current auth user: ${user?.id}');

      if (user == null) {
        LoggingService.debug('No auth user found');
        return null;
      }

      // Fetch profile data
      final userData = await _fetchUserProfile(user.id);
      LoggingService.debug('User data from profiles: $userData');

      if (userData == null) {
        LoggingService.debug('Profile not found - user may have been removed due to domain restrictions');
        await signOut();
        return null;
      }

      final role = userData['role'] as String?;
      final tenantId = userData['tenant_id'] as String?;

      // Check if user is blocked or has missing required data
      if (role == null || role == 'blocked' || tenantId == null || tenantId.isEmpty) {
        LoggingService.debug('User is blocked, has no role, or has no tenant access');
        await signOut();
        return null;
      }

      // Ensure tenant_id and role are saved in local storage
      final savedTenantId = await localStorage.getTenantId();
      final savedRole = await localStorage.getUserRole();

      if (savedTenantId != tenantId || savedRole != role) {
        await localStorage.saveUserData(
          tenantId: tenantId,
          userId: userData['id'] as String,
          fullName: userData['full_name'] as String?,
          role: role, // Now guaranteed to be non-null
        );
        LoggingService.debug('Updated user data in local storage: tenant_id=$tenantId, role=$role');
      }

      // Create UserModel with data from both auth user and profiles
      return UserModel(
        id: userData['id'] as String,
        name: userData['full_name'] as String? ?? 'Unknown',
        email: user.email ?? '',
        avatarUrl: user.userMetadata?['avatar_url'] as String?,
        createdAt: DateTime.parse(userData['created_at'] as String),
      );

    } catch (e) {
      LoggingService.error('Error in getCurrentUser: $e');
      await signOut();
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    LoggingService.debug('Signing out user');

    try {
      // Clear local storage first
      await localStorage.clearUserData();

      // Then sign out from Supabase
      await supabase.auth.signOut();
    } catch (e) {
      LoggingService.error('Error during sign out: $e');
      // Even if sign out fails, clear local storage
      await localStorage.clearUserData();
    }
  }

  // Helper method to wait for profile with retry logic
  Future<Map<String, dynamic>?> _waitForProfile(String userId) async {
    const maxRetries = 10; // Increased retries for database trigger
    const baseDelay = Duration(milliseconds: 200);

    for (int i = 0; i < maxRetries; i++) {
      LoggingService.debug('Waiting for profile creation, attempt ${i + 1}');

      final profile = await _fetchUserProfile(userId);
      if (profile != null) {
        LoggingService.debug('Profile found on attempt ${i + 1}');
        return profile;
      }

      // Exponential backoff with jitter
      final delay = Duration(
          milliseconds: baseDelay.inMilliseconds * (1 << i) + (i * 50)
      );
      await Future.delayed(delay);
    }

    LoggingService.error('Profile not created after $maxRetries attempts');
    return null;
  }

  // Helper method to fetch user profile
  Future<Map<String, dynamic>?> _fetchUserProfile(String userId) async {
    try {
      final profileData = await supabase
          .from('profiles')
          .select('id, full_name, tenant_id, role, created_at')
          .eq('id', userId)
          .maybeSingle();

      return profileData;
    } catch (e) {
      LoggingService.error('Error fetching user profile: $e');
      return null;
    }
  }
}