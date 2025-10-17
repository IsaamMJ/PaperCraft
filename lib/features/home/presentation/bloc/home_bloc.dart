// features/home/presentation/bloc/home_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
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

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetDraftsUseCase _getDraftsUseCase;
  final GetUserSubmissionsUseCase _getSubmissionsUseCase;
  final GetPapersForReviewUseCase _getPapersForReviewUseCase;
  final GetAllPapersForAdminUseCase _getAllPapersForAdminUseCase;
  final RealtimeService _realtimeService;

  static const String _adminChannelName = 'home_admin_papers';
  static const String _teacherChannelName = 'home_teacher_papers';

  HomeBloc({
    required GetDraftsUseCase getDraftsUseCase,
    required GetUserSubmissionsUseCase getSubmissionsUseCase,
    required GetPapersForReviewUseCase getPapersForReviewUseCase,
    required GetAllPapersForAdminUseCase getAllPapersForAdminUseCase,
    required RealtimeService realtimeService,
  })  : _getDraftsUseCase = getDraftsUseCase,
        _getSubmissionsUseCase = getSubmissionsUseCase,
        _getPapersForReviewUseCase = getPapersForReviewUseCase,
        _getAllPapersForAdminUseCase = getAllPapersForAdminUseCase,
        _realtimeService = realtimeService,
        super(const HomeInitial()) {
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

  Future<void> _onLoadHomePapers(
    LoadHomePapers event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeLoading(message: 'Loading...'));

    try {
      if (event.isAdmin) {
        // Admin: Load papers for review and all papers
        await _loadAdminPapers(emit);
      } else {
        // Teacher: Load drafts and submissions
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
      // On refresh error, keep current state (don't emit error)
      // User will see the data they already have
    }
  }

  Future<void> _loadAdminPapers(Emitter<HomeState> emit) async {
    // Load papers for review
    final reviewResult = await _getPapersForReviewUseCase();

    // Load all papers for admin
    final allPapersResult = await _getAllPapersForAdminUseCase();

    await reviewResult.fold(
      (failure) async => emit(HomeError(failure.message)),
      (papersForReview) async {
        await allPapersResult.fold(
          (failure) async => emit(HomeError(failure.message)),
          (allPapers) async {
            // Enrich papers with display names
            final enrichedReview = await sl<PaperDisplayService>().enrichPapers(papersForReview);
            final enrichedAll = await sl<PaperDisplayService>().enrichPapers(allPapers);

            emit(HomeLoaded(
              papersForReview: enrichedReview,
              allPapersForAdmin: enrichedAll,
            ));
          },
        );
      },
    );
  }

  Future<void> _loadTeacherPapers(Emitter<HomeState> emit, String? userId) async {
    if (userId == null) {
      emit(const HomeError('User ID not found'));
      return;
    }

    // Load drafts
    final draftsResult = await _getDraftsUseCase();

    // Load submissions
    final submissionsResult = await _getSubmissionsUseCase();

    await draftsResult.fold(
      (failure) async => emit(HomeError(failure.message)),
      (drafts) async {
        await submissionsResult.fold(
          (failure) async => emit(HomeError(failure.message)),
          (submissions) async {
            // Enrich papers with display names
            final enrichedDrafts = await sl<PaperDisplayService>().enrichPapers(drafts);
            final enrichedSubmissions = await sl<PaperDisplayService>().enrichPapers(submissions);

            emit(HomeLoaded(
              drafts: enrichedDrafts,
              submissions: enrichedSubmissions,
            ));
          },
        );
      },
    );
  }

  Future<void> _onEnableRealtimeUpdates(
    EnableRealtimeUpdates event,
    Emitter<HomeState> emit,
  ) async {
    try {
      // Subscribe to question_papers table changes
      final channelName = event.isAdmin ? _adminChannelName : _teacherChannelName;

      _realtimeService.subscribeToTable(
        table: 'question_papers',
        channelName: channelName,
        onInsert: (payload) {
          // Paper inserted - add it if it's relevant
          add(PaperRealtimeUpdate(paperData: payload, eventType: 'INSERT'));
        },
        onUpdate: (payload) {
          // Paper updated - refresh if needed
          add(PaperRealtimeUpdate(paperData: payload, eventType: 'UPDATE'));
        },
        onDelete: (payload) {
          // Paper deleted - remove it
          add(PaperRealtimeUpdate(paperData: payload, eventType: 'DELETE'));
        },
      );
    } catch (e) {
      // Log error but don't fail - realtime is optional
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
      final enrichedPaper = (await sl<PaperDisplayService>().enrichPapers([paperModel])).first;

      if (event.eventType == 'INSERT') {
        // Add new paper to appropriate list
        emit(_handleInsert(currentState, enrichedPaper));
      } else if (event.eventType == 'UPDATE') {
        // Update existing paper
        emit(_handleUpdate(currentState, enrichedPaper));
      } else if (event.eventType == 'DELETE') {
        // Remove paper
        emit(_handleDelete(currentState, enrichedPaper.id));
      }
    } catch (e) {
      // Log error but don't fail - just skip this update
    }
  }

  HomeLoaded _handleInsert(HomeLoaded currentState, QuestionPaperEntity newPaper) {
    // Add to review queue if status is submitted/pending
    if (newPaper.status.value == 'pending' || newPaper.status.value == 'submitted') {
      return currentState.copyWith(
        papersForReview: [newPaper, ...currentState.papersForReview],
      );
    }

    // Add to all papers
    return currentState.copyWith(
      allPapersForAdmin: [newPaper, ...currentState.allPapersForAdmin],
    );
  }

  HomeLoaded _handleUpdate(HomeLoaded currentState, QuestionPaperEntity updatedPaper) {
    // Update in all lists where it exists
    return currentState.copyWith(
      drafts: _updatePaperInList(currentState.drafts, updatedPaper),
      submissions: _updatePaperInList(currentState.submissions, updatedPaper),
      papersForReview: _updatePaperInList(currentState.papersForReview, updatedPaper),
      allPapersForAdmin: _updatePaperInList(currentState.allPapersForAdmin, updatedPaper),
    );
  }

  HomeLoaded _handleDelete(HomeLoaded currentState, String paperId) {
    return currentState.copyWith(
      drafts: currentState.drafts.where((p) => p.id != paperId).toList(),
      submissions: currentState.submissions.where((p) => p.id != paperId).toList(),
      papersForReview: currentState.papersForReview.where((p) => p.id != paperId).toList(),
      allPapersForAdmin: currentState.allPapersForAdmin.where((p) => p.id != paperId).toList(),
    );
  }

  List<QuestionPaperEntity> _updatePaperInList(
    List<QuestionPaperEntity> list,
    QuestionPaperEntity updatedPaper,
  ) {
    return list.map((p) => p.id == updatedPaper.id ? updatedPaper : p).toList();
  }
}
