import 'dart:async';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/interfaces/i_clock.dart';

/// Mock implementation of IClock for testing
class MockClock extends Mock implements IClock {}

/// Fake clock for testing time-dependent code
/// Allows you to control time in tests!
class FakeClock implements IClock {
  DateTime _currentTime;
  final List<_FakeTimer> _timers = [];

  FakeClock([DateTime? initialTime])
      : _currentTime = initialTime ?? DateTime(2024, 1, 1, 12, 0, 0);

  @override
  DateTime now() => _currentTime;

  @override
  Timer periodic(Duration duration, void Function(Timer) callback) {
    final timer = _FakeTimer(duration, callback, isPeriodic: true);
    _timers.add(timer);
    return timer;
  }

  @override
  Timer timer(Duration duration, void Function() callback) {
    final wrappedCallback = (Timer t) => callback();
    final timer = _FakeTimer(duration, wrappedCallback, isPeriodic: false);
    _timers.add(timer);
    return timer;
  }

  @override
  Future<void> delay(Duration duration) async {
    // In tests, we can choose to advance time manually instead
    // For now, complete immediately
    return Future.value();
  }

  // Test helpers

  /// Advance time by the given duration
  void advance(Duration duration) {
    _currentTime = _currentTime.add(duration);
    _triggerTimers();
  }

  /// Advance to a specific time
  void advanceTo(DateTime time) {
    if (time.isBefore(_currentTime)) {
      throw ArgumentError('Cannot go back in time');
    }
    _currentTime = time;
    _triggerTimers();
  }

  /// Trigger all pending timers
  void _triggerTimers() {
    for (final timer in List.from(_timers)) {
      if (!timer.isActive) continue;

      timer.execute();
    }
  }

  /// Get count of active timers
  int get activeTimerCount => _timers.where((t) => t.isActive).length;

  /// Cancel all timers
  void cancelAllTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }
}

class _FakeTimer implements Timer {
  final Duration duration;
  final void Function(Timer) callback;
  final bool isPeriodic;
  bool _isActive = true;
  int _tickCount = 0;

  _FakeTimer(this.duration, this.callback, {required this.isPeriodic});

  void execute() {
    if (!_isActive) return;

    _tickCount++;
    callback(this);

    if (!isPeriodic) {
      _isActive = false;
    }
  }

  @override
  void cancel() {
    _isActive = false;
  }

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _tickCount;
}
