import 'dart:async';

/// Abstraction for time-related operations
/// This makes timer-based logic testable
abstract class IClock {
  /// Get current DateTime
  DateTime now();

  /// Create a periodic timer
  Timer periodic(Duration duration, void Function(Timer) callback);

  /// Create a one-shot timer
  Timer timer(Duration duration, void Function() callback);

  /// Delay execution
  Future<void> delay(Duration duration);
}

/// Production implementation using real time
class SystemClock implements IClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  Timer periodic(Duration duration, void Function(Timer) callback) {
    return Timer.periodic(duration, callback);
  }

  @override
  Timer timer(Duration duration, void Function() callback) {
    return Timer(duration, callback);
  }

  @override
  Future<void> delay(Duration duration) {
    return Future.delayed(duration);
  }
}
