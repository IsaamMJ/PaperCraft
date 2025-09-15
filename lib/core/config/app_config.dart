import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'Paper Craft';
  static const String version = '1.0.0';

  // Supabase Configuration
  static const String supabaseUrl = 'https://kpttdmhzunysswgeevrz.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtwdHRkbWh6dW55c3N3Z2VldnJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ5MjUxMjYsImV4cCI6MjA3MDUwMTEyNn0.upHpj9Hoy3EZrS65AmUViXMiHzF_T32HZGH9ujyetxc';

  // Environment flags
  static const bool isDebug = kDebugMode;

  // Auth redirect URLs
  static String get authRedirectUrl {
    return Uri.base.origin.contains('localhost')
        ? 'http://localhost:3000/auth/callback'
        : '${Uri.base.origin}/auth/callback';
  }
}