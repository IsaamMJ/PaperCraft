// features/question_bank/presentation/bloc/question_bank_bloc.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../paper_workflow/domain/services/paper_display_service.dart';
import '../../../paper_workflow/domain/usecases/get_approved_papers_paginated_usecase.dart';
import 'question_bank_event.dart';
import 'question_bank_state.dart';

class QuestionBankBloc extends Bloc<QuestionBankEvent, QuestionBankState> {
  final GetApprovedPapersPaginatedUseCase _getApprovedPapersPaginatedUseCase;

  QuestionBankBloc({
    required GetApprovedPapersPaginatedUseCase getApprovedPapersPaginatedUseCase,
  })  : _getApprovedPapersPaginatedUseCase = getApprovedPapersPaginatedUseCase,
        super(const QuestionBankInitial()) {
    on<LoadQuestionBankPaginated>(_onLoadQuestionBankPaginated);
    on<RefreshQuestionBank>(_onRefreshQuestionBank);
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
}
