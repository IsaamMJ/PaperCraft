// core/infrastructure/feature_flags/feature_flags.dart
import '../../domain/interfaces/i_feature_flags.dart';
import '../di/injection_container.dart';

/// Static wrapper for feature flags to provide convenient access throughout the app
class FeatureFlags {
  FeatureFlags._();

  static IFeatureFlags get _flags => sl<IFeatureFlags>();

  static bool get enableAnalytics => _flags.enableAnalytics;
  static bool get enableCrashlytics => _flags.enableCrashlytics;
  static bool get enableDebugLogging => _flags.enableDebugLogging;
  static bool get enableNetworkLogging => _flags.enableNetworkLogging;
  static bool get enablePerformanceMonitoring => _flags.enablePerformanceMonitoring;

  static Map<String, bool> get allFlags => _flags.allFlags;

  static void logFlags() => _flags.logFlags();
}