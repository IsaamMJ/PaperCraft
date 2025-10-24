// core/infrastructure/utils/debounce_helper.dart
import 'dart:async';

/// Debouncer to prevent rapid repeated function calls
///
/// Useful for search inputs, rapid button clicks, etc.
///
/// Usage:
/// ```dart
/// final debouncer = Debouncer(duration: Duration(milliseconds: 500));
///
/// onSearchChanged(String query) {
///   debouncer.call(() async {
///     final results = await searchPapers(query);
///     setState(() => searchResults = results);
///   });
/// }
/// ```
class Debouncer {
  final Duration duration;
  Timer? _timer;

  Debouncer({this.duration = const Duration(milliseconds: 500)});

  /// Execute a function after debounce period
  /// If called again before the period ends, the previous call is cancelled
  void call(Function() function) {
    _timer?.cancel();
    _timer = Timer(duration, () {
      function();
    });
  }

  /// Execute an async function with debouncing
  Future<T?> callAsync<T>(Future<T> Function() asyncFunction) async {
    _timer?.cancel();
    final completer = Completer<T?>();

    _timer = Timer(duration, () async {
      try {
        final result = await asyncFunction();
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });

    return completer.future;
  }

  /// Cancel any pending debounced call
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose and cleanup
  void dispose() {
    cancel();
  }
}

/// Throttler to limit function calls to once per duration
///
/// Unlike debouncer, throttler allows first call immediately, then blocks until duration passes.
///
/// Usage:
/// ```dart
/// final throttler = Throttler(duration: Duration(seconds: 1));
///
/// onScroll() {
///   throttler.call(() {
///     loadMorePapers();
///   });
/// }
/// ```
class Throttler {
  final Duration duration;
  DateTime? _lastCallTime;
  Timer? _timer;

  Throttler({this.duration = const Duration(seconds: 1)});

  /// Execute function if enough time has passed since last call
  /// Returns true if function was executed, false if throttled
  bool call(Function() function) {
    final now = DateTime.now();

    if (_lastCallTime == null ||
        now.difference(_lastCallTime!).inMilliseconds >= duration.inMilliseconds) {
      _lastCallTime = now;
      function();
      return true;
    }
    return false;
  }

  /// Execute async function with throttling
  Future<T?> callAsync<T>(Future<T> Function() asyncFunction) async {
    final now = DateTime.now();

    if (_lastCallTime == null ||
        now.difference(_lastCallTime!).inMilliseconds >= duration.inMilliseconds) {
      _lastCallTime = now;
      return await asyncFunction();
    }
    return null;
  }

  /// Cancel any pending throttled operation
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Dispose and cleanup
  void dispose() {
    cancel();
  }
}
