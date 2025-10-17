// features/question_bank/presentation/bloc/question_bank_bloc.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/infrastructure/realtime/realtime_service.dart';
import '../../../paper_workflow/data/models/question_paper_model.dart';
import '../../../paper_workflow/domain/services/paper_display_service.dart';
import '../../../paper_workflow/domain/usecases/get_approved_papers_paginated_usecase.dart';
import 'question_bank_event.dart';
import 'question_bank_state.dart';

class QuestionBankBloc extends Bloc<QuestionBankEvent, QuestionBankState> {
  final GetApprovedPapersPaginatedUseCase _getApprovedPapersPaginatedUseCase;
  final RealtimeService _realtimeService;

  static const String _channelName = 'question_bank_approved_papers';

  QuestionBankBloc({
    required GetApprovedPapersPaginatedUseCase getApprovedPapersPaginatedUseCase,
    required RealtimeService realtimeService,
  })  : _getApprovedPapersPaginatedUseCase = getApprovedPapersPaginatedUseCase,
        _realtimeService = realtimeService,
        super(const QuestionBankInitial()) {
    on<LoadQuestionBankPaginated>(_onLoadQuestionBankPaginated);
    on<RefreshQuestionBank>(_onRefreshQuestionBank);
    on<EnableQuestionBankRealtime>(_onEnableRealtime);
    on<DisableQuestionBankRealtime>(_onDisableRealtime);
    on<QuestionBankPaperRealtimeUpdate>(_onPaperRealtimeUpdate);
  }

  @override
  Future<void> close() async {
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
        final enrichedPapers = await sl<PaperDisplayService>().enrichPapers(paginatedResult.items);

        if (event.isLoadMore && state is QuestionBankLoaded) {
          // Append to existing papers
          final currentState = state as QuestionBankLoaded;
          final allPapers = [...currentState.papers, ...enrichedPapers];

          emit(QuestionBankLoaded(
            papers: allPapers,
            currentPage: paginatedResult.currentPage,
            totalPages: paginatedResult.totalPages,
            totalItems: paginatedResult.totalItems,
            hasMore: paginatedResult.hasMore,
            isLoadingMore: false,
            searchQuery: event.searchQuery,
            subjectFilter: event.subjectFilter,
            gradeFilter: event.gradeFilter,
          ));
        } else {
          // Fresh load - replace papers
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
          ));
        }
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
        final enrichedPapers = await sl<PaperDisplayService>().enrichPapers(paginatedResult.items);

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
      final currentState = state as QuestionBankLoaded;
      final paperModel = QuestionPaperModel.fromSupabase(event.paperData);

      // Only process approved papers
      if (paperModel.status.value != 'approved') return;

      final enrichedPaper = (await sl<PaperDisplayService>().enrichPapers([paperModel])).first;

      if (event.eventType == 'INSERT') {
        // Add new approved paper to the beginning
        emit(currentState.copyWith(
          papers: [enrichedPaper, ...currentState.papers],
          totalItems: currentState.totalItems + 1,
        ));
      } else if (event.eventType == 'UPDATE') {
        // Update existing paper
        final updatedPapers = currentState.papers
            .map((p) => p.id == enrichedPaper.id ? enrichedPaper : p)
            .toList();
        emit(currentState.copyWith(papers: updatedPapers));
      } else if (event.eventType == 'DELETE') {
        // Remove paper
        final filteredPapers = currentState.papers.where((p) => p.id != enrichedPaper.id).toList();
        emit(currentState.copyWith(
          papers: filteredPapers,
          totalItems: currentState.totalItems - 1,
        ));
      }
    } catch (e) {
      // Log error but don't fail - just skip this update
    }
  }
}
