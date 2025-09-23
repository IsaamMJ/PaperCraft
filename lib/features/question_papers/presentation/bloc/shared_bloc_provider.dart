// core/presentation/providers/shared_bloc_provider.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:papercraft/features/question_papers/presentation/bloc/question_paper_bloc.dart';
import '../../../../core/infrastructure/di/injection_container.dart';

/// Provides shared BLoC instances to prevent memory leaks and improve performance
class SharedBlocProvider extends StatelessWidget {
  final Widget child;
  static QuestionPaperBloc? _sharedQuestionPaperBloc;

  const SharedBlocProvider({super.key, required this.child});

  /// Get or create shared QuestionPaperBloc instance
  static QuestionPaperBloc getQuestionPaperBloc() {
    _sharedQuestionPaperBloc ??= QuestionPaperBloc(
      saveDraftUseCase: sl(),
      submitPaperUseCase: sl(),
      getDraftsUseCase: sl(),
      getUserSubmissionsUseCase: sl(),
      approvePaperUseCase: sl(),
      rejectPaperUseCase: sl(),
      getPapersForReviewUseCase: sl(),
      deleteDraftUseCase: sl(),
      pullForEditingUseCase: sl(),
      getPaperByIdUseCase: sl(),
      getAllPapersForAdminUseCase: sl(), // NEW
      getApprovedPapersUseCase: sl(),    // NEW
    );
    return _sharedQuestionPaperBloc!;
  }

  /// Dispose shared instances (call this when app is disposed)
  static void disposeAll() {
    _sharedQuestionPaperBloc?.close();
    _sharedQuestionPaperBloc = null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<QuestionPaperBloc>.value(
      value: getQuestionPaperBloc(),
      child: child,
    );
  }
}

/// Mixin for widgets that need performance optimizations
mixin PerformanceOptimizationMixin<T extends StatefulWidget> on State<T> {
  /// Debounce helper to prevent rapid successive calls
  static final Map<String, Timer?> _debouncers = {};

  void debounce(String key, VoidCallback action, {Duration delay = const Duration(milliseconds: 300)}) {
    _debouncers[key]?.cancel();
    _debouncers[key] = Timer(delay, action);
  }

  @override
  void dispose() {
    // Clean up any active debouncers for this widget
    final instanceKey = hashCode.toString();
    _debouncers.keys
        .where((key) => key.startsWith(instanceKey))
        .forEach((key) {
      _debouncers[key]?.cancel();
      _debouncers.remove(key);
    });
    super.dispose();
  }
}

/// Cached computation helper for expensive calculations
class ComputationCache<T> {
  final Map<String, _CacheEntry<T>> _cache = {};
  final Duration maxAge;

  ComputationCache({this.maxAge = const Duration(minutes: 5)});

  T getOrCompute(String key, T Function() computation) {
    final entry = _cache[key];
    final now = DateTime.now();

    if (entry != null && now.difference(entry.timestamp) < maxAge) {
      return entry.value;
    }

    final result = computation();
    _cache[key] = _CacheEntry(result, now);
    return result;
  }

  void invalidate(String key) {
    _cache.remove(key);
  }

  void invalidateAll() {
    _cache.clear();
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime timestamp;

  _CacheEntry(this.value, this.timestamp);
}