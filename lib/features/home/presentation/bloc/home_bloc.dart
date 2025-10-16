// features/home/presentation/bloc/home_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
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

  HomeBloc({
    required GetDraftsUseCase getDraftsUseCase,
    required GetUserSubmissionsUseCase getSubmissionsUseCase,
    required GetPapersForReviewUseCase getPapersForReviewUseCase,
    required GetAllPapersForAdminUseCase getAllPapersForAdminUseCase,
  })  : _getDraftsUseCase = getDraftsUseCase,
        _getSubmissionsUseCase = getSubmissionsUseCase,
        _getPapersForReviewUseCase = getPapersForReviewUseCase,
        _getAllPapersForAdminUseCase = getAllPapersForAdminUseCase,
        super(const HomeInitial()) {
    on<LoadHomePapers>(_onLoadHomePapers);
    on<RefreshHomePapers>(_onRefreshHomePapers);
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
}
