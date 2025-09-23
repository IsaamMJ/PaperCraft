abstract class IFeatureFlags {
  bool get enableAnalytics;
  bool get enableCrashlytics;
  bool get enableDebugLogging;
  bool get enableNetworkLogging;
  bool get enablePerformanceMonitoring;

  Map<String, bool> get allFlags;
  void logFlags();
}
