// features/question_bank/presentation/bloc/question_bank_bloc.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/infrastructure/realtime/realtime_service.dart';
import '../../../paper_workflow/data/models/question_paper_model.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/domain/services/paper_display_service.dart';
import '../../../paper_workflow/domain/usecases/get_approved_papers_paginated_usecase.dart';
import 'question_bank_event.dart';
import 'question_bank_state.dart';

class QuestionBankBloc extends Bloc<QuestionBankEvent, QuestionBankState> {
  final GetApprovedPapersPaginatedUseCase _getApprovedPapersPaginatedUseCase;
  final RealtimeService _realtimeService;
  final PaperDisplayService _paperDisplayService;

  static const String _channelName = 'question_bank_approved_papers';

  // Debouncing for realtime updates (batch multiple updates)
  Timer? _realtimeDebounceTimer;
  final List<QuestionBankPaperRealtimeUpdate> _pendingRealtimeUpdates = [];
  static const Duration _realtimeDebounceInterval = Duration(milliseconds: 500);

  QuestionBankBloc({
    required GetApprovedPapersPaginatedUseCase getApprovedPapersPaginatedUseCase,
    required RealtimeService realtimeService,
    required PaperDisplayService paperDisplayService,
  })  : _getApprovedPapersPaginatedUseCase = getApprovedPapersPaginatedUseCase,
        _realtimeService = realtimeService,
        _paperDisplayService = paperDisplayService,
        super(const QuestionBankInitial()) {
    on<LoadQuestionBankPaginated>(_onLoadQuestionBankPaginated);
    on<RefreshQuestionBank>(_onRefreshQuestionBank);
    on<EnableQuestionBankRealtime>(_onEnableRealtime);
    on<DisableQuestionBankRealtime>(_onDisableRealtime);
    on<QuestionBankPaperRealtimeUpdate>(_onPaperRealtimeUpdate);
  }

  @override
  Future<void> close() async {
    // Cancel pending debounce timer
    _realtimeDebounceTimer?.cancel();
    _pendingRealtimeUpdates.clear();

    // Unsubscribe from realtime
    await _realtimeService.unsubscribe(_channelName);
    return super.close();
  }

  Future<void> _onLoadQuestionBankPaginated(
    LoadQuestionBankPaginated event,
    Emitter<QuestionBankState> emit,
  ) async {
    // If loading more, set loading flag on existing state
    if (event.isLoadMore && state is QuestionBankLoaded) {
      final currentState = state as QuestionBankLoaded;
      emit(currentState.copyWith(isLoadingMore: true));
    } else if (!event.isLoadMore) {
      // Fresh load or filter change - show loading
      emit(const QuestionBankLoading(message: 'Loading papers...'));
    }

    // Use provided filters directly - no blocking async operations
    final result = await _getApprovedPapersPaginatedUseCase(
      page: event.page,
      pageSize: event.pageSize,
      searchQuery: event.searchQuery,
      subjectFilter: event.subjectFilter,
      gradeFilter: event.gradeFilter,
    );

    await result.fold(
      (failure) async {
        emit(QuestionBankError(failure.message));
      },
      (paginatedResult) async {
        // Enrich papers with display names
        final enrichedPapers = await _paperDisplayService.enrichPapers(paginatedResult.items);

        List<QuestionPaperEntity> finalPapers;
        if (event.isLoadMore && state is QuestionBankLoaded) {
          // Append to existing papers
          final currentState = state as QuestionBankLoaded;
          finalPapers = [...currentState.papers, ...enrichedPapers];
        } else {
          // Fresh load - replace papers
          finalPapers = enrichedPapers;
        }

        // Pre-compute all grouped data
        final groupedData = _computeGroupedData(finalPapers);

        emit(QuestionBankLoaded(
          papers: finalPapers,
          currentPage: paginatedResult.currentPage,
          totalPages: paginatedResult.totalPages,
          totalItems: paginatedResult.totalItems,
          hasMore: paginatedResult.hasMore,
          isLoadingMore: false,
          searchQuery: event.searchQuery,
          subjectFilter: event.subjectFilter,
          gradeFilter: event.gradeFilter,
          thisMonthGroupedByClass: groupedData['thisMonthByClass']!,
          thisMonthGroupedByMonth: groupedData['thisMonthByMonth']!,
          previousMonthGroupedByClass: groupedData['previousMonthByClass']!,
          previousMonthGroupedByMonth: groupedData['previousMonthByMonth']!,
          archiveGroupedByClass: groupedData['archiveByClass']!,
          archiveGroupedByMonth: groupedData['archiveByMonth']!,
        ));
      },
    );
  }

  Future<void> _onRefreshQuestionBank(
    RefreshQuestionBank event,
    Emitter<QuestionBankState> emit,
  ) async {
    // Don't show loading state on refresh (keep current data visible)
    final result = await _getApprovedPapersPaginatedUseCase(
      page: 1,
      pageSize: event.pageSize,
      searchQuery: event.searchQuery,
      subjectFilter: event.subjectFilter,
      gradeFilter: event.gradeFilter,
    );

    await result.fold(
      (failure) async {
        // On refresh error, keep current state (don't emit error)
        // User will see the data they already have
      },
      (paginatedResult) async {
        // Enrich papers with display names
        final enrichedPapers = await _paperDisplayService.enrichPapers(paginatedResult.items);

        // Pre-compute all grouped data
        final groupedData = _computeGroupedData(enrichedPapers);

        emit(QuestionBankLoaded(
          papers: enrichedPapers,
          currentPage: paginatedResult.currentPage,
          totalPages: paginatedResult.totalPages,
          totalItems: paginatedResult.totalItems,
          hasMore: paginatedResult.hasMore,
          isLoadingMore: false,
          searchQuery: event.searchQuery,
          subjectFilter: event.subjectFilter,
          gradeFilter: event.gradeFilter,
          thisMonthGroupedByClass: groupedData['thisMonthByClass']!,
          thisMonthGroupedByMonth: groupedData['thisMonthByMonth']!,
          previousMonthGroupedByClass: groupedData['previousMonthByClass']!,
          previousMonthGroupedByMonth: groupedData['previousMonthByMonth']!,
          archiveGroupedByClass: groupedData['archiveByClass']!,
          archiveGroupedByMonth: groupedData['archiveByMonth']!,
        ));
      },
    );
  }

  Future<void> _onEnableRealtime(
    EnableQuestionBankRealtime event,
    Emitter<QuestionBankState> emit,
  ) async {
    try {
      // Subscribe only to approved papers (filter by status)
      _realtimeService.subscribeToTable(
        table: 'question_papers',
        channelName: _channelName,
        filter: 'status=eq.approved', // Only listen to approved papers
        onInsert: (payload) {
          add(QuestionBankPaperRealtimeUpdate(paperData: payload, eventType: 'INSERT'));
        },
        onUpdate: (payload) {
          add(QuestionBankPaperRealtimeUpdate(paperData: payload, eventType: 'UPDATE'));
        },
        onDelete: (payload) {
          add(QuestionBankPaperRealtimeUpdate(paperData: payload, eventType: 'DELETE'));
        },
      );
    } catch (e) {
      // Log error but don't fail - realtime is optional
    }
  }

  Future<void> _onDisableRealtime(
    DisableQuestionBankRealtime event,
    Emitter<QuestionBankState> emit,
  ) async {
    await _realtimeService.unsubscribe(_channelName);
  }

  Future<void> _onPaperRealtimeUpdate(
    QuestionBankPaperRealtimeUpdate event,
    Emitter<QuestionBankState> emit,
  ) async {
    // Only process if we have loaded state
    if (state is! QuestionBankLoaded) return;

    try {
      final paperModel = QuestionPaperModel.fromSupabase(event.paperData);

      // Only process approved papers
      if (paperModel.status.value != 'approved') return;

      // Add to pending updates
      _pendingRealtimeUpdates.add(event);

      // Cancel existing timer and start new one
      _realtimeDebounceTimer?.cancel();
      _realtimeDebounceTimer = Timer(_realtimeDebounceInterval, () async {
        try {
          await _processPendingRealtimeUpdates(emit);
        } catch (e) {
          // Log error but don't fail
        }
      });
    } catch (e) {
      // Log error but don't fail
    }
  }

  /// Process all pending realtime updates in batch
  /// Batching reduces expensive grouping recomputation
  Future<void> _processPendingRealtimeUpdates(Emitter<QuestionBankState> emit) async {
    if (_pendingRealtimeUpdates.isEmpty || state is! QuestionBankLoaded) return;

    try {
      final currentState = state as QuestionBankLoaded;
      var updatedPapers = List<QuestionPaperEntity>.from(currentState.papers);
      int updatedTotalItems = currentState.totalItems;

      // Process all pending updates
      for (final event in _pendingRealtimeUpdates) {
        try {
          // Skip enrichment for realtime updates - use basic paper data
          // This avoids unnecessary API calls and improves performance
          final paperModel = QuestionPaperModel.fromSupabase(event.paperData);

          if (event.eventType == 'INSERT') {
            updatedPapers = [paperModel, ...updatedPapers];
            updatedTotalItems += 1;
          } else if (event.eventType == 'UPDATE') {
            updatedPapers = updatedPapers
                .map((p) => p.id == paperModel.id ? paperModel : p)
                .toList();
          } else if (event.eventType == 'DELETE') {
            updatedPapers = updatedPapers.where((p) => p.id != paperModel.id).toList();
            updatedTotalItems -= 1;
          }
        } catch (e) {
          // Skip individual update on error
        }
      }

      // Recompute all grouped data once for all updates (not per-update)
      // This is the critical optimization - grouping is expensive
      final groupedData = _computeGroupedData(updatedPapers);

      emit(currentState.copyWith(
        papers: updatedPapers,
        totalItems: updatedTotalItems,
        thisMonthGroupedByClass: groupedData['thisMonthByClass'],
        thisMonthGroupedByMonth: groupedData['thisMonthByMonth'],
        previousMonthGroupedByClass: groupedData['previousMonthByClass'],
        previousMonthGroupedByMonth: groupedData['previousMonthByMonth'],
        archiveGroupedByClass: groupedData['archiveByClass'],
        archiveGroupedByMonth: groupedData['archiveByMonth'],
      ));

      _pendingRealtimeUpdates.clear();
    } catch (e) {
      // Log error but don't fail
    }
  }

  /// Pre-compute all filtered and grouped data for performance
  Map<String, Map<String, List<QuestionPaperEntity>>> _computeGroupedData(
    List<QuestionPaperEntity> papers,
  ) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final previousMonth = DateTime(now.year, now.month - 1);

    // Filter papers by period
    final thisMonthPapers = <QuestionPaperEntity>[];
    final previousMonthPapers = <QuestionPaperEntity>[];
    final archivePapers = <QuestionPaperEntity>[];

    for (final paper in papers) {
      if (!paper.status.isApproved) continue;

      final paperDate = paper.reviewedAt ?? paper.createdAt;
      final paperMonth = DateTime(paperDate.year, paperDate.month);

      if (paperMonth.isAtSameMomentAs(currentMonth)) {
        thisMonthPapers.add(paper);
      } else if (paperMonth.isAtSameMomentAs(previousMonth)) {
        previousMonthPapers.add(paper);
      } else if (paperMonth.isBefore(previousMonth)) {
        archivePapers.add(paper);
      }
    }

    return {
      'thisMonthByClass': _groupPapersByClass(thisMonthPapers),
      'thisMonthByMonth': _groupPapersByMonth(thisMonthPapers),
      'previousMonthByClass': _groupPapersByClass(previousMonthPapers),
      'previousMonthByMonth': _groupPapersByMonth(previousMonthPapers),
      'archiveByClass': _groupPapersByClass(archivePapers),
      'archiveByMonth': _groupPapersByMonth(archivePapers),
    };
  }

  /// Group papers by class/grade level
  Map<String, List<QuestionPaperEntity>> _groupPapersByClass(
    List<QuestionPaperEntity> papers,
  ) {
    final grouped = <String, List<QuestionPaperEntity>>{};

    for (final paper in papers) {
      final className = paper.gradeDisplayName;
      grouped.putIfAbsent(className, () => []).add(paper);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final aGrade = _extractGradeNumber(a);
        final bGrade = _extractGradeNumber(b);
        if (aGrade != null && bGrade != null) {
          return aGrade.compareTo(bGrade);
        }
        return a.compareTo(b);
      });

    final sortedGrouped = <String, List<QuestionPaperEntity>>{};
    for (final key in sortedKeys) {
      grouped[key]!.sort((a, b) =>
        (b.reviewedAt ?? b.createdAt).compareTo(a.reviewedAt ?? a.createdAt)
      );
      sortedGrouped[key] = grouped[key]!;
    }

    return sortedGrouped;
  }

  /// Group papers by month-year
  Map<String, List<QuestionPaperEntity>> _groupPapersByMonth(
    List<QuestionPaperEntity> papers,
  ) {
    final grouped = <String, List<QuestionPaperEntity>>{};

    for (final paper in papers) {
      final date = paper.reviewedAt ?? paper.createdAt;
      final monthYear = '${_getMonthName(date.month)} ${date.year}';
      grouped.putIfAbsent(monthYear, () => []).add(paper);
    }

    final sortedGrouped = <String, List<QuestionPaperEntity>>{};
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final aDate = grouped[a]!.first.reviewedAt ?? grouped[a]!.first.createdAt;
        final bDate = grouped[b]!.first.reviewedAt ?? grouped[b]!.first.createdAt;
        return bDate.compareTo(aDate);
      });

    for (final key in sortedKeys) {
      grouped[key]!.sort((a, b) =>
        (b.reviewedAt ?? b.createdAt).compareTo(a.reviewedAt ?? a.createdAt)
      );
      sortedGrouped[key] = grouped[key]!;
    }

    return sortedGrouped;
  }

  /// Extract grade number from display string (e.g., "Grade 10" -> 10)
  int? _extractGradeNumber(String gradeDisplay) {
    final match = RegExp(r'Grade (\d+)').firstMatch(gradeDisplay);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  /// Get month name from month number
  String _getMonthName(int month) {
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
  }
}
