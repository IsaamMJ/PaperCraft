// features/home/presentation/bloc/home_bloc.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../../core/infrastructure/realtime/realtime_service.dart';
import '../../../paper_workflow/data/models/question_paper_model.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/domain/services/paper_display_service.dart';
import '../../../paper_workflow/domain/usecases/get_drafts_usecase.dart';
import '../../../paper_workflow/domain/usecases/get_user_submissions_usecase.dart';
import '../../../paper_workflow/domain/usecases/get_papers_for_review_usecase.dart';
import '../../../paper_workflow/domain/usecases/get_all_papers_for_admin_usecase.dart';
import 'home_event.dart';
import 'home_state.dart';

/// HomeBloc manages the state of the home page for both teachers and admins
///
/// Responsibilities:
/// - Load papers based on user role (teacher: drafts/submissions, admin: review/all)
/// - Handle realtime updates for live paper changes
/// - Enrich papers with display data (subject names, grades)
/// - Manage refresh operations
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetDraftsUseCase _getDraftsUseCase;
  final GetUserSubmissionsUseCase _getSubmissionsUseCase;
  final GetPapersForReviewUseCase _getPapersForReviewUseCase;
  final GetAllPapersForAdminUseCase _getAllPapersForAdminUseCase;
  final RealtimeService _realtimeService;
  final PaperDisplayService _paperDisplayService;

  // Realtime channel names
  static const String _adminChannelName = 'home_admin_papers';
  static const String _teacherChannelName = 'home_teacher_papers';

  HomeBloc({
    required GetDraftsUseCase getDraftsUseCase,
    required GetUserSubmissionsUseCase getSubmissionsUseCase,
    required GetPapersForReviewUseCase getPapersForReviewUseCase,
    required GetAllPapersForAdminUseCase getAllPapersForAdminUseCase,
    required RealtimeService realtimeService,
    required PaperDisplayService paperDisplayService,
  })  : _getDraftsUseCase = getDraftsUseCase,
        _getSubmissionsUseCase = getSubmissionsUseCase,
        _getPapersForReviewUseCase = getPapersForReviewUseCase,
        _getAllPapersForAdminUseCase = getAllPapersForAdminUseCase,
        _realtimeService = realtimeService,
        _paperDisplayService = paperDisplayService,
        super(const HomeLoading(message: 'Initializing...')) {
    on<LoadHomePapers>(_onLoadHomePapers);
    on<RefreshHomePapers>(_onRefreshHomePapers);
    on<EnableRealtimeUpdates>(_onEnableRealtimeUpdates);
    on<DisableRealtimeUpdates>(_onDisableRealtimeUpdates);
    on<PaperRealtimeUpdate>(_onPaperRealtimeUpdate);
  }

  @override
  Future<void> close() async {
    await _realtimeService.unsubscribe(_adminChannelName);
    await _realtimeService.unsubscribe(_teacherChannelName);
    return super.close();
  }

  // ==================== Event Handlers ====================

  Future<void> _onLoadHomePapers(
      LoadHomePapers event,
      Emitter<HomeState> emit,
      ) async {
    emit(const HomeLoading(message: 'Loading...'));

    try {
      if (event.isAdmin) {
        await _loadAdminPapers(emit);
      } else {
        await _loadTeacherPapers(emit, event.userId);
      }
    } catch (e) {
      emit(HomeError('Failed to load papers: $e'));
    }
  }

  Future<void> _onRefreshHomePapers(
      RefreshHomePapers event,
      Emitter<HomeState> emit,
      ) async {
    // Don't show loading state on refresh (keep current data visible)
    try {
      if (event.isAdmin) {
        await _loadAdminPapers(emit);
      } else {
        await _loadTeacherPapers(emit, event.userId);
      }
    } catch (e) {
      // On refresh error, keep current state (silent failure)
      // User will see the data they already have
    }
  }

  Future<void> _onEnableRealtimeUpdates(
      EnableRealtimeUpdates event,
      Emitter<HomeState> emit,
      ) async {
    try {
      final channelName = event.isAdmin ? _adminChannelName : _teacherChannelName;

      _realtimeService.subscribeToTable(
        table: 'question_papers',
        channelName: channelName,
        onInsert: (payload) => add(PaperRealtimeUpdate(
          paperData: payload,
          eventType: RealtimeEventType.insert,
        )),
        onUpdate: (payload) => add(PaperRealtimeUpdate(
          paperData: payload,
          eventType: RealtimeEventType.update,
        )),
        onDelete: (payload) => add(PaperRealtimeUpdate(
          paperData: payload,
          eventType: RealtimeEventType.delete,
        )),
      );
    } catch (e) {
      // Log error but don't fail - realtime is optional enhancement
    }
  }

  Future<void> _onDisableRealtimeUpdates(
      DisableRealtimeUpdates event,
      Emitter<HomeState> emit,
      ) async {
    await _realtimeService.unsubscribe(_adminChannelName);
    await _realtimeService.unsubscribe(_teacherChannelName);
  }

  Future<void> _onPaperRealtimeUpdate(
      PaperRealtimeUpdate event,
      Emitter<HomeState> emit,
      ) async {
    // Only process if we have loaded state
    if (state is! HomeLoaded) return;

    try {
      final currentState = state as HomeLoaded;
      final paperModel = QuestionPaperModel.fromSupabase(event.paperData);
      final enrichedPaper = (await _paperDisplayService.enrichPapers([paperModel])).first;

      switch (event.eventType) {
        case RealtimeEventType.insert:
          emit(_handleInsert(currentState, enrichedPaper));
        case RealtimeEventType.update:
          emit(_handleUpdate(currentState, enrichedPaper));
        case RealtimeEventType.delete:
          emit(_handleDelete(currentState, enrichedPaper.id));
      }
    } catch (e) {
      // Log error but don't fail - just skip this update
    }
  }

  // ==================== Private Helper Methods ====================

  /// Load papers for admin users
  Future<void> _loadAdminPapers(Emitter<HomeState> emit) async {
    // Fetch both datasets in parallel
    final results = await Future.wait([
      _getPapersForReviewUseCase(),
      _getAllPapersForAdminUseCase(),
    ]);

    final reviewResult = results[0];
    final allPapersResult = results[1];

    // Handle errors
    final reviewFailure = _extractFailure(reviewResult);
    if (reviewFailure != null) {
      emit(HomeError(reviewFailure.message));
      return;
    }

    final allPapersFailure = _extractFailure(allPapersResult);
    if (allPapersFailure != null) {
      emit(HomeError(allPapersFailure.message));
      return;
    }

    // Extract success values
    final papersForReview = _extractPapers(reviewResult);
    final allPapers = _extractPapers(allPapersResult);

    // Enrich and sort papers
    final enrichedReview = await _enrichAndSortPapers(papersForReview);
    final enrichedAll = await _enrichAndSortPapers(allPapers);

    emit(HomeLoaded(
      papersForReview: enrichedReview,
      allPapersForAdmin: enrichedAll,
    ));
  }

  /// Load papers for teacher users
  Future<void> _loadTeacherPapers(Emitter<HomeState> emit, String? userId) async {
    if (userId == null) {
      emit(const HomeError('User ID not found'));
      return;
    }

    // Fetch both datasets in parallel
    final results = await Future.wait([
      _getDraftsUseCase(),
      _getSubmissionsUseCase(),
    ]);

    final draftsResult = results[0];
    final submissionsResult = results[1];

    // Handle errors
    final draftsFailure = _extractFailure(draftsResult);
    if (draftsFailure != null) {
      emit(HomeError(draftsFailure.message));
      return;
    }

    final submissionsFailure = _extractFailure(submissionsResult);
    if (submissionsFailure != null) {
      emit(HomeError(submissionsFailure.message));
      return;
    }

    // Extract success values
    final drafts = _extractPapers(draftsResult);
    final submissions = _extractPapers(submissionsResult);

    // Enrich and sort papers
    final enrichedDrafts = await _enrichAndSortPapers(drafts);
    final enrichedSubmissions = await _enrichAndSortPapers(submissions);

    emit(HomeLoaded(
      drafts: enrichedDrafts,
      submissions: enrichedSubmissions,
    ));
  }

  /// Enrich papers with display data and sort by modifiedAt (newest first)
  ///
  /// This is a testable business logic method
  Future<List<QuestionPaperEntity>> _enrichAndSortPapers(
      List<QuestionPaperEntity> papers,
      ) async {
    if (papers.isEmpty) return papers;

    final enriched = await _paperDisplayService.enrichPapers(papers);
    enriched.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return enriched;
  }

  /// Extract failure from Either result
  Failure? _extractFailure(Either<Failure, List<QuestionPaperEntity>> result) {
    return result.fold(
          (failure) => failure,
          (_) => null,
    );
  }

  /// Extract papers from Either result
  List<QuestionPaperEntity> _extractPapers(
      Either<Failure, List<QuestionPaperEntity>> result,
      ) {
    return result.fold(
          (_) => [],
          (papers) => papers,
    );
  }

  // ==================== Realtime Update Handlers ====================

  /// Handle INSERT event - add new paper to appropriate list
  HomeLoaded _handleInsert(HomeLoaded currentState, QuestionPaperEntity newPaper) {
    // Add to review queue if status is submitted/pending
    if (newPaper.status.value == 'pending' || newPaper.status.value == 'submitted') {
      return currentState.copyWith(
        papersForReview: [newPaper, ...currentState.papersForReview],
      );
    }

    // Add to all papers (for admin view)
    return currentState.copyWith(
      allPapersForAdmin: [newPaper, ...currentState.allPapersForAdmin],
    );
  }

  /// Handle UPDATE event - update existing paper in all lists
  HomeLoaded _handleUpdate(HomeLoaded currentState, QuestionPaperEntity updatedPaper) {
    return currentState.copyWith(
      drafts: _updatePaperInList(currentState.drafts, updatedPaper),
      submissions: _updatePaperInList(currentState.submissions, updatedPaper),
      papersForReview: _updatePaperInList(currentState.papersForReview, updatedPaper),
      allPapersForAdmin: _updatePaperInList(currentState.allPapersForAdmin, updatedPaper),
    );
  }

  /// Handle DELETE event - remove paper from all lists
  HomeLoaded _handleDelete(HomeLoaded currentState, String paperId) {
    return currentState.copyWith(
      drafts: currentState.drafts.where((p) => p.id != paperId).toList(),
      submissions: currentState.submissions.where((p) => p.id != paperId).toList(),
      papersForReview: currentState.papersForReview.where((p) => p.id != paperId).toList(),
      allPapersForAdmin: currentState.allPapersForAdmin.where((p) => p.id != paperId).toList(),
    );
  }

  /// Update a paper in a list if it exists
  List<QuestionPaperEntity> _updatePaperInList(
      List<QuestionPaperEntity> list,
      QuestionPaperEntity updatedPaper,
      ) {
    return list.map((p) => p.id == updatedPaper.id ? updatedPaper : p).toList();
  }
}