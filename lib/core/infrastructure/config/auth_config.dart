import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../feature_flags/feature_flags.dart';
import 'environment.dart';
import 'environment_config.dart';

class AuthConfig {
  static Duration get sessionTimeout {
    switch (EnvironmentConfig.current) {
      case Environment.dev:
        return const Duration(hours: 24); // Extended for development
      case Environment.staging:
        return const Duration(hours: 8);
      case Environment.prod:
        return const Duration(hours: 4);
    }
  }

  static Duration get oauthTimeout {
    switch (EnvironmentConfig.current) {
      case Environment.dev:
        return const Duration(seconds: 60); // Extended for development
      case Environment.staging:
      case Environment.prod:
        return const Duration(seconds: 30);
    }
  }

  static bool get enableDebugAuth => FeatureFlags.enableDebugLogging;

  static bool get enableExtendedLogging => FeatureFlags.enableDebugLogging;

  // Add OAuth launch mode configuration
  static LaunchMode get authLaunchMode => LaunchMode.externalApplication;

  static String get redirectUrl {
    switch (EnvironmentConfig.current) {
      case Environment.dev:
        final url = kIsWeb
            ? 'http://localhost:3000/auth/callback'
            : 'com.pearl.papercraft.dev://login-callback/';
        print('🔍 DEBUG: redirectUrl = $url, kIsWeb = $kIsWeb');
        return url;
      case Environment.staging:
        final url = kIsWeb
            ? 'https://staging.papercraft.app/auth/callback'
            : 'com.pearl.papercraft.staging://login-callback/';
        print('🔍 DEBUG: redirectUrl = $url, kIsWeb = $kIsWeb');
        return url;
      case Environment.prod:
        final url = kIsWeb
            ? 'https://papercraft.app/auth/callback'
            : 'com.pearl.papercraft://login-callback/';
        print('🔍 DEBUG: redirectUrl = $url, kIsWeb = $kIsWeb');
        return url;
    }
  }

  // OAuth query parameters for better authentication flow
  static Map<String, String> get oauthQueryParams {
    return {
      'prompt': 'select_account', // Force account selection
      'access_type': 'offline',   // Get refresh token
    };
  }
}