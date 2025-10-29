import 'package:flutter/foundation.dart';
import '../../domain/interfaces/i_feature_flags.dart';
import '../config/environment.dart';

class FeatureFlagsImpl implements IFeatureFlags {
  final Environment _environment;
  final String _platformName;

  const FeatureFlagsImpl(this._environment, this._platformName);

  @override
  bool get enableAnalytics => _environment != Environment.dev;

  @override
  bool get enableCrashlytics => _environment == Environment.prod && _platformName == 'android';

  @override
  bool get enableDebugLogging => _environment == Environment.dev;

  @override
  bool get enableNetworkLogging => _environment == Environment.dev;

  @override
  bool get enablePerformanceMonitoring => _environment != Environment.dev;

  @override
  Map<String, bool> get allFlags {
    return {
      'enableAnalytics': enableAnalytics,
      'enableCrashlytics': enableCrashlytics,
      'enableDebugLogging': enableDebugLogging,
      'enableNetworkLogging': enableNetworkLogging,
      'enablePerformanceMonitoring': enablePerformanceMonitoring,
    };
  }

  @override
  void logFlags() {
    if (kDebugMode) {
      allFlags.forEach((key, value) {
      });
    }
  }
}