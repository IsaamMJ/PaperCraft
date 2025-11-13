// features/paper_workflow/presentation/bloc/question_paper_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/domain/models/paginated_result.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../paper_review/domain/usecases/approve_paper_usecase.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../../../catalog/domain/entities/paper_section_entity.dart';
import '../../../paper_review/domain/usecases/reject_paper_usecase.dart';
import '../../domain/usecases/delete_draft_usecase.dart';
import '../../domain/usecases/update_paper_usecase.dart';
import '../../domain/usecases/get_all_papers_for_admin_usecase.dart';
import '../../domain/usecases/get_approved_papers_usecase.dart';
import '../../domain/usecases/get_approved_papers_paginated_usecase.dart';
import '../../domain/usecases/get_approved_papers_by_exam_date_range_usecase.dart';
import '../../domain/usecases/get_drafts_usecase.dart';
import '../../domain/usecases/get_paper_by_id_usecase.dart';
import '../../domain/usecases/get_papers_for_review_usecase.dart';
import '../../domain/usecases/get_user_submissions_usecase.dart';
import '../../domain/usecases/pull_for_editing_usecase.dart';
import '../../domain/usecases/save_draft_usecase.dart';
import '../../domain/usecases/submit_paper_usecase.dart';
import '../../domain/services/paper_display_service.dart';

// =============== EVENTS ===============
abstract class QuestionPaperEvent extends Equatable {
  const QuestionPaperEvent();

  @override
  List<Object?> get props => [];
}

class LoadDrafts extends QuestionPaperEvent {
  const LoadDrafts();
}

class LoadUserSubmissions extends QuestionPaperEvent {
  const LoadUserSubmissions();
}

class LoadPapersForReview extends QuestionPaperEvent {
  const LoadPapersForReview();
}

class LoadAllPapersForAdmin extends QuestionPaperEvent {
  const LoadAllPapersForAdmin();
}

class LoadApprovedPapers extends QuestionPaperEvent {
  const LoadApprovedPapers();
}

class LoadApprovedPapersByExamDateRange extends QuestionPaperEvent {
  final DateTime fromDate;
  final DateTime toDate;

  const LoadApprovedPapersByExamDateRange({
    required this.fromDate,
    required this.toDate,
  });

  @override
  List<Object> get props => [fromDate, toDate];
}

class LoadApprovedPapersPaginated extends QuestionPaperEvent {
  final int page;
  final int pageSize;
  final String? searchQuery;
  final String? subjectFilter;
  final String? gradeFilter;
  final bool isLoadMore; // true if loading more, false if refreshing

  const LoadApprovedPapersPaginated({
    this.page = 1,
    this.pageSize = 20,
    this.searchQuery,
    this.subjectFilter,
    this.gradeFilter,
    this.isLoadMore = false,
  });

  @override
  List<Object?> get props => [page, pageSize, searchQuery, subjectFilter, gradeFilter, isLoadMore];
}

class LoadExamTypes extends QuestionPaperEvent {
  const LoadExamTypes();
}

class LoadPaperById extends QuestionPaperEvent {
  final String paperId;

  const LoadPaperById(this.paperId);

  @override
  List<Object> get props => [paperId];
}

class SaveDraft extends QuestionPaperEvent {
  final QuestionPaperEntity paper;

  const SaveDraft(this.paper);

  @override
  List<Object> get props => [paper];
}

class SubmitPaper extends QuestionPaperEvent {
  final QuestionPaperEntity paper;

  const SubmitPaper(this.paper);

  @override
  List<Object> get props => [paper];
}

class ApprovePaper extends QuestionPaperEvent {
  final String paperId;

  const ApprovePaper(this.paperId);

  @override
  List<Object> get props => [paperId];
}

class RejectPaper extends QuestionPaperEvent {
  final String paperId;
  final String reason;

  const RejectPaper(this.paperId, this.reason);

  @override
  List<Object> get props => [paperId, reason];
}

class DeleteDraft extends QuestionPaperEvent {
  final String draftId;

  const DeleteDraft(this.draftId);

  @override
  List<Object> get props => [draftId];
}

class PullForEditing extends QuestionPaperEvent {
  final String paperId;

  const PullForEditing(this.paperId);

  @override
  List<Object> get props => [paperId];
}

class RefreshAll extends QuestionPaperEvent {
  const RefreshAll();
}

/// Load all teacher papers (drafts + submissions) atomically to prevent race conditions
class LoadAllTeacherPapers extends QuestionPaperEvent {
  const LoadAllTeacherPapers();
}

/// Update a single question in the current paper
class UpdateQuestionInline extends QuestionPaperEvent {
  final String sectionName;
  final int questionIndex;
  final String updatedText;
  final List<String>? updatedOptions;

  const UpdateQuestionInline({
    required this.sectionName,
    required this.questionIndex,
    required this.updatedText,
    this.updatedOptions,
  });

  @override
  List<Object?> get props => [sectionName, questionIndex, updatedText, updatedOptions];
}

/// Update section name
class UpdateSectionName extends QuestionPaperEvent {
  final String oldSectionName;
  final String newSectionName;

  const UpdateSectionName({
    required this.oldSectionName,
    required this.newSectionName,
  });

  @override
  List<Object> get props => [oldSectionName, newSectionName];
}

// =============== STATES ===============
abstract class QuestionPaperState extends Equatable {
  const QuestionPaperState();

  @override
  List<Object?> get props => [];
}

class QuestionPaperInitial extends QuestionPaperState {}

class QuestionPaperLoading extends QuestionPaperState {
  final String? message;

  const QuestionPaperLoading({this.message});

  @override
  List<Object?> get props => [message];
}

class QuestionPaperLoaded extends QuestionPaperState {
  final List<QuestionPaperEntity> drafts;
  final List<QuestionPaperEntity> submissions;
  final List<QuestionPaperEntity> papersForReview;
  final List<QuestionPaperEntity> allPapersForAdmin;
  final List<QuestionPaperEntity> approvedPapers;
  final QuestionPaperEntity? currentPaper;
  final Set<String> editedQuestions; // Track edited questions: "sectionName_questionIndex"

  const QuestionPaperLoaded({
    this.drafts = const [],
    this.submissions = const [],
    this.papersForReview = const [],
    this.allPapersForAdmin = const [],
    this.approvedPapers = const [],
    this.currentPaper,
    this.editedQuestions = const {},
  });

  @override
  List<Object?> get props => [
    drafts,
    submissions,
    papersForReview,
    allPapersForAdmin,
    approvedPapers,
    currentPaper,
    editedQuestions
  ];

  QuestionPaperLoaded copyWith({
    List<QuestionPaperEntity>? drafts,
    List<QuestionPaperEntity>? submissions,
    List<QuestionPaperEntity>? papersForReview,
    List<QuestionPaperEntity>? allPapersForAdmin,
    List<QuestionPaperEntity>? approvedPapers,
    QuestionPaperEntity? currentPaper,
    Set<String>? editedQuestions,
    bool clearCurrentPaper = false,
  }) {
    return QuestionPaperLoaded(
      drafts: drafts ?? this.drafts,
      submissions: submissions ?? this.submissions,
      papersForReview: papersForReview ?? this.papersForReview,
      allPapersForAdmin: allPapersForAdmin ?? this.allPapersForAdmin,
      approvedPapers: approvedPapers ?? this.approvedPapers,
      currentPaper: clearCurrentPaper ? null : (currentPaper ?? this.currentPaper),
      editedQuestions: editedQuestions ?? this.editedQuestions,
    );
  }
}

class QuestionPaperError extends QuestionPaperState {
  final String message;

  const QuestionPaperError(this.message);

  @override
  List<Object> get props => [message];
}

class QuestionPaperSuccess extends QuestionPaperState {
  final String message;
  final String? actionType;

  const QuestionPaperSuccess(this.message, {this.actionType});

  @override
  List<Object?> get props => [message, actionType];
}

class ApprovedPapersPaginated extends QuestionPaperState {
  final List<QuestionPaperEntity> papers;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final bool hasMore;
  final bool isLoadingMore;
  final String? searchQuery;
  final String? subjectFilter;
  final String? gradeFilter;

  const ApprovedPapersPaginated({
    required this.papers,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.hasMore,
    this.isLoadingMore = false,
    this.searchQuery,
    this.subjectFilter,
    this.gradeFilter,
  });

  @override
  List<Object?> get props => [
        papers,
        currentPage,
        totalPages,
        totalItems,
        hasMore,
        isLoadingMore,
        searchQuery,
        subjectFilter,
        gradeFilter,
      ];

  ApprovedPapersPaginated copyWith({
    List<QuestionPaperEntity>? papers,
    int? currentPage,
    int? totalPages,
    int? totalItems,
    bool? hasMore,
    bool? isLoadingMore,
    String? searchQuery,
    String? subjectFilter,
    String? gradeFilter,
    bool clearFilters = false,
  }) {
    return ApprovedPapersPaginated(
      papers: papers ?? this.papers,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalItems: totalItems ?? this.totalItems,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      searchQuery: clearFilters ? null : (searchQuery ?? this.searchQuery),
      subjectFilter: clearFilters ? null : (subjectFilter ?? this.subjectFilter),
      gradeFilter: clearFilters ? null : (gradeFilter ?? this.gradeFilter),
    );
  }
}

class ApprovedPapersByExamDateLoaded extends QuestionPaperState {
  final List<QuestionPaperEntity> papers;
  final DateTime fromDate;
  final DateTime toDate;

  const ApprovedPapersByExamDateLoaded({
    required this.papers,
    required this.fromDate,
    required this.toDate,
  });

  @override
  List<Object> get props => [papers, fromDate, toDate];
}

// =============== BLOC ===============
class QuestionPaperBloc extends Bloc<QuestionPaperEvent, QuestionPaperState> {
  final SaveDraftUseCase _saveDraftUseCase;
  final SubmitPaperUseCase _submitPaperUseCase;
  final GetDraftsUseCase _getDraftsUseCase;
  final GetUserSubmissionsUseCase _getUserSubmissionsUseCase;
  final ApprovePaperUseCase _approvePaperUseCase;
  final RejectPaperUseCase _rejectPaperUseCase;
  final GetPapersForReviewUseCase _getPapersForReviewUseCase;
  final DeleteDraftUseCase _deleteDraftUseCase;
  final PullForEditingUseCase _pullForEditingUseCase;
  final GetPaperByIdUseCase _getPaperByIdUseCase;
  final GetAllPapersForAdminUseCase _getAllPapersForAdminUseCase;
  final GetApprovedPapersUseCase _getApprovedPapersUseCase;
  final GetApprovedPapersPaginatedUseCase _getApprovedPapersPaginatedUseCase;
  final GetApprovedPapersByExamDateRangeUseCase _getApprovedPapersByExamDateRangeUseCase;
  final UpdatePaperUseCase _updatePaperUseCase;

  QuestionPaperBloc({
    required SaveDraftUseCase saveDraftUseCase,
    required SubmitPaperUseCase submitPaperUseCase,
    required GetDraftsUseCase getDraftsUseCase,
    required GetUserSubmissionsUseCase getUserSubmissionsUseCase,
    required ApprovePaperUseCase approvePaperUseCase,
    required RejectPaperUseCase rejectPaperUseCase,
    required GetPapersForReviewUseCase getPapersForReviewUseCase,
    required DeleteDraftUseCase deleteDraftUseCase,
    required PullForEditingUseCase pullForEditingUseCase,
    required GetPaperByIdUseCase getPaperByIdUseCase,
    required GetAllPapersForAdminUseCase getAllPapersForAdminUseCase,
    required GetApprovedPapersUseCase getApprovedPapersUseCase,
    required GetApprovedPapersPaginatedUseCase getApprovedPapersPaginatedUseCase,
    required GetApprovedPapersByExamDateRangeUseCase getApprovedPapersByExamDateRangeUseCase,
    required UpdatePaperUseCase updatePaperUseCase,
  })  : _saveDraftUseCase = saveDraftUseCase,
        _submitPaperUseCase = submitPaperUseCase,
        _getDraftsUseCase = getDraftsUseCase,
        _getUserSubmissionsUseCase = getUserSubmissionsUseCase,
        _approvePaperUseCase = approvePaperUseCase,
        _rejectPaperUseCase = rejectPaperUseCase,
        _getPapersForReviewUseCase = getPapersForReviewUseCase,
        _deleteDraftUseCase = deleteDraftUseCase,
        _pullForEditingUseCase = pullForEditingUseCase,
        _getPaperByIdUseCase = getPaperByIdUseCase,
        _getAllPapersForAdminUseCase = getAllPapersForAdminUseCase,
        _getApprovedPapersUseCase = getApprovedPapersUseCase,
        _getApprovedPapersPaginatedUseCase = getApprovedPapersPaginatedUseCase,
        _getApprovedPapersByExamDateRangeUseCase = getApprovedPapersByExamDateRangeUseCase,
        _updatePaperUseCase = updatePaperUseCase,
        super(QuestionPaperInitial()) {
    on<LoadDrafts>(_onLoadDrafts);
    on<LoadUserSubmissions>(_onLoadUserSubmissions);
    on<LoadPapersForReview>(_onLoadPapersForReview);
    on<LoadAllPapersForAdmin>(_onLoadAllPapersForAdmin);
    on<LoadApprovedPapers>(_onLoadApprovedPapers);
    on<LoadApprovedPapersPaginated>(_onLoadApprovedPapersPaginated);
    on<LoadApprovedPapersByExamDateRange>(_onLoadApprovedPapersByExamDateRange);
    // Exam types removed - using dynamic sections
    on<LoadPaperById>(_onLoadPaperById);
    on<SaveDraft>(_onSaveDraft);
    on<SubmitPaper>(_onSubmitPaper);
    on<ApprovePaper>(_onApprovePaper);
    on<RejectPaper>(_onRejectPaper);
    on<DeleteDraft>(_onDeleteDraft);
    on<PullForEditing>(_onPullForEditing);
    on<RefreshAll>(_onRefreshAll);
    on<LoadAllTeacherPapers>(_onLoadAllTeacherPapers);
    on<UpdateQuestionInline>(_onUpdateQuestionInline);
    on<UpdateSectionName>(_onUpdateSectionName);
  }

  Future<void> _onLoadDrafts(LoadDrafts event, Emitter<QuestionPaperState> emit) async {
    final result = await _getDraftsUseCase();

    await result.fold(
          (failure) async => emit(QuestionPaperError(failure.message)),
          (drafts) async {
        // Enrich papers with display names
        final enrichedDrafts = await sl<PaperDisplayService>().enrichPapers(drafts);

        if (state is QuestionPaperLoaded) {
          final currentState = state as QuestionPaperLoaded;
          emit(currentState.copyWith(drafts: enrichedDrafts));
        } else {
          emit(QuestionPaperLoaded(drafts: enrichedDrafts));
        }
      },
    );
  }

  Future<void> _onLoadUserSubmissions(LoadUserSubmissions event, Emitter<QuestionPaperState> emit) async {
    final result = await _getUserSubmissionsUseCase();

    await result.fold(
          (failure) async => emit(QuestionPaperError(failure.message)),
          (submissions) async {
        // Enrich papers with display names
        final enrichedSubmissions = await sl<PaperDisplayService>().enrichPapers(submissions);

        if (state is QuestionPaperLoaded) {
          final currentState = state as QuestionPaperLoaded;
          emit(currentState.copyWith(submissions: enrichedSubmissions));
        } else {
          emit(QuestionPaperLoaded(submissions: enrichedSubmissions));
        }
      },
    );
  }

  Future<void> _onLoadPapersForReview(LoadPapersForReview event, Emitter<QuestionPaperState> emit) async {
    final result = await _getPapersForReviewUseCase();

    await result.fold(
          (failure) async => emit(QuestionPaperError(failure.message)),
          (papers) async {
        // Enrich papers with display names
        final enrichedPapers = await sl<PaperDisplayService>().enrichPapers(papers);

        if (state is QuestionPaperLoaded) {
          final currentState = state as QuestionPaperLoaded;
          emit(currentState.copyWith(papersForReview: enrichedPapers));
        } else {
          emit(QuestionPaperLoaded(papersForReview: enrichedPapers));
        }
      },
    );
  }

  Future<void> _onLoadAllPapersForAdmin(LoadAllPapersForAdmin event, Emitter<QuestionPaperState> emit) async {
    final result = await _getAllPapersForAdminUseCase();

    await result.fold(
          (failure) async => emit(QuestionPaperError(failure.message)),
          (allPapers) async {
        // Enrich papers with display names
        final enrichedPapers = await sl<PaperDisplayService>().enrichPapers(allPapers);

        if (state is QuestionPaperLoaded) {
          final currentState = state as QuestionPaperLoaded;
          emit(currentState.copyWith(allPapersForAdmin: enrichedPapers));
        } else {
          emit(QuestionPaperLoaded(allPapersForAdmin: enrichedPapers));
        }
      },
    );
  }

  Future<void> _onLoadApprovedPapers(LoadApprovedPapers event, Emitter<QuestionPaperState> emit) async {
    final result = await _getApprovedPapersUseCase();

    await result.fold(
          (failure) async => emit(QuestionPaperError(failure.message)),
          (approvedPapers) async {
        // Enrich papers with display names
        final enrichedPapers = await sl<PaperDisplayService>().enrichPapers(approvedPapers);

        if (state is QuestionPaperLoaded) {
          final currentState = state as QuestionPaperLoaded;
          emit(currentState.copyWith(approvedPapers: enrichedPapers));
        } else {
          emit(QuestionPaperLoaded(approvedPapers: enrichedPapers));
        }
      },
    );
  }

  Future<void> _onLoadApprovedPapersByExamDateRange(
    LoadApprovedPapersByExamDateRange event,
    Emitter<QuestionPaperState> emit,
  ) async {
    emit(const QuestionPaperLoading(message: 'Loading upcoming exams...'));

    final result = await _getApprovedPapersByExamDateRangeUseCase(
      fromDate: event.fromDate,
      toDate: event.toDate,
    );

    await result.fold(
      (failure) async => emit(QuestionPaperError(failure.message)),
      (papers) async {
        // Enrich papers with display names
        final enrichedPapers = await sl<PaperDisplayService>().enrichPapers(papers);

        emit(ApprovedPapersByExamDateLoaded(
          papers: enrichedPapers,
          fromDate: event.fromDate,
          toDate: event.toDate,
        ));
      },
    );
  }

  Future<void> _onLoadApprovedPapersPaginated(
    LoadApprovedPapersPaginated event,
    Emitter<QuestionPaperState> emit,
  ) async {
    // If loading more, set loading flag on existing state
    if (event.isLoadMore && state is ApprovedPapersPaginated) {
      final currentState = state as ApprovedPapersPaginated;
      emit(currentState.copyWith(isLoadingMore: true));
    } else if (!event.isLoadMore) {
      // Fresh load or filter change - show loading
      emit(const QuestionPaperLoading(message: 'Loading papers...'));
    }

    final result = await _getApprovedPapersPaginatedUseCase(
      page: event.page,
      pageSize: event.pageSize,
      searchQuery: event.searchQuery,
      subjectFilter: event.subjectFilter,
      gradeFilter: event.gradeFilter,
    );

    await result.fold(
      (failure) async => emit(QuestionPaperError(failure.message)),
      (paginatedResult) async {
        // Enrich papers with display names
        final enrichedPapers = await sl<PaperDisplayService>().enrichPapers(paginatedResult.items);

        if (event.isLoadMore && state is ApprovedPapersPaginated) {
          // Append to existing papers
          final currentState = state as ApprovedPapersPaginated;
          final allPapers = [...currentState.papers, ...enrichedPapers];

          emit(ApprovedPapersPaginated(
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
          emit(ApprovedPapersPaginated(
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

  // Exam types no longer needed - using dynamic sections instead

  Future<void> _onLoadPaperById(LoadPaperById event, Emitter<QuestionPaperState> emit) async {
    emit(const QuestionPaperLoading(message: 'Loading paper...'));

    final result = await _getPaperByIdUseCase(event.paperId);

    await result.fold(
          (failure) async => emit(QuestionPaperError(failure.message)),
          (paper) async {
        if (paper == null) {
          emit(const QuestionPaperError('Paper not found'));
          return;
        }

        // Enrich single paper with display names
        final enrichedPaper = await sl<PaperDisplayService>().enrichPaper(paper);

        if (state is QuestionPaperLoaded) {
          final currentState = state as QuestionPaperLoaded;
          emit(currentState.copyWith(currentPaper: enrichedPaper));
        } else {
          emit(QuestionPaperLoaded(currentPaper: enrichedPaper));
        }
      },
    );
  }

  Future<void> _onSaveDraft(SaveDraft event, Emitter<QuestionPaperState> emit) async {
    final result = await _saveDraftUseCase(event.paper);

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (savedPaper) {
        emit(const QuestionPaperSuccess('Draft saved successfully', actionType: 'save'));
        add(const LoadDrafts());
      },
    );
  }

  Future<void> _onSubmitPaper(SubmitPaper event, Emitter<QuestionPaperState> emit) async {
    emit(const QuestionPaperLoading(message: 'Submitting paper...'));

    final result = await _submitPaperUseCase(event.paper);

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (submittedPaper) {
        emit(const QuestionPaperSuccess('Paper submitted successfully', actionType: 'submit'));
        add(const LoadDrafts());
        add(const LoadUserSubmissions());
      },
    );
  }

  Future<void> _onApprovePaper(ApprovePaper event, Emitter<QuestionPaperState> emit) async {
    final result = await _approvePaperUseCase(event.paperId);

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (approvedPaper) {
        emit(const QuestionPaperSuccess('Paper approved successfully', actionType: 'approve'));
        add(const LoadPapersForReview());
        add(const LoadUserSubmissions());
        add(const LoadApprovedPapers());
        add(const LoadAllPapersForAdmin());
      },
    );
  }

  Future<void> _onRejectPaper(RejectPaper event, Emitter<QuestionPaperState> emit) async {
    final result = await _rejectPaperUseCase(event.paperId, event.reason);

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (rejectedPaper) {
        emit(const QuestionPaperSuccess('Paper rejected with feedback', actionType: 'reject'));
        add(const LoadPapersForReview());
        add(const LoadUserSubmissions());
        add(const LoadAllPapersForAdmin());
      },
    );
  }

  Future<void> _onDeleteDraft(DeleteDraft event, Emitter<QuestionPaperState> emit) async {
    final result = await _deleteDraftUseCase(event.draftId);

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (_) {
        emit(const QuestionPaperSuccess('Draft deleted successfully', actionType: 'delete'));
        add(const LoadDrafts());
      },
    );
  }

  Future<void> _onPullForEditing(
      PullForEditing event,
      Emitter<QuestionPaperState> emit,
      ) async {
    emit(const QuestionPaperLoading(message: 'Converting paper to draft...'));

    final result = await _pullForEditingUseCase(event.paperId);

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (draftPaper) {
        emit(const QuestionPaperSuccess('Paper converted back to draft successfully', actionType: 'pull'));

        // Refresh the data
        add(const LoadDrafts());
        add(const LoadUserSubmissions());
        add(const LoadAllPapersForAdmin());
      },
    );
  }

  Future<void> _onRefreshAll(RefreshAll event, Emitter<QuestionPaperState> emit) async {
    add(const LoadDrafts());
    add(const LoadUserSubmissions());
    add(const LoadPapersForReview());
    add(const LoadAllPapersForAdmin());
    add(const LoadApprovedPapers());
    add(const LoadExamTypes());
  }

  /// Load all teacher papers atomically to prevent race conditions and partial loading
  Future<void> _onLoadAllTeacherPapers(LoadAllTeacherPapers event, Emitter<QuestionPaperState> emit) async {
    // Only show loading state if we don't have data yet
    // This prevents UI from showing loading spinner when data already exists
    if (state is! QuestionPaperLoaded) {
      emit(QuestionPaperLoading());
    }

    try {
      // Load both drafts and submissions in parallel
      final results = await Future.wait([
        _getDraftsUseCase(),
        _getUserSubmissionsUseCase(),
      ]);

      final draftsResult = results[0];
      final submissionsResult = results[1];

      // Check if either failed
      final draftFailure = draftsResult.fold((f) => f, (_) => null);
      final submissionFailure = submissionsResult.fold((f) => f, (_) => null);

      if (draftFailure != null) {
        emit(QuestionPaperError(draftFailure.message));
        return;
      }

      if (submissionFailure != null) {
        emit(QuestionPaperError(submissionFailure.message));
        return;
      }

      // Extract papers
      final drafts = draftsResult.fold((_) => <QuestionPaperEntity>[], (papers) => papers);
      final submissions = submissionsResult.fold((_) => <QuestionPaperEntity>[], (papers) => papers);

      // Enrich both lists in parallel
      final enrichedResults = await Future.wait([
        sl<PaperDisplayService>().enrichPapers(drafts),
        sl<PaperDisplayService>().enrichPapers(submissions),
      ]);

      // Preserve other state data if it exists
      if (state is QuestionPaperLoaded) {
        final currentState = state as QuestionPaperLoaded;
        emit(currentState.copyWith(
          drafts: enrichedResults[0],
          submissions: enrichedResults[1],
        ));
      } else {
        emit(QuestionPaperLoaded(
          drafts: enrichedResults[0],
          submissions: enrichedResults[1],
        ));
      }
    } catch (e) {
      emit(QuestionPaperError('Failed to load papers: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateQuestionInline(UpdateQuestionInline event, Emitter<QuestionPaperState> emit) async {
    print('🎯 [BLoC] UpdateQuestionInline event received');
    print('   - Section: "${event.sectionName}"');
    print('   - Question index: ${event.questionIndex}');
    print('   - Updated text length: ${event.updatedText.length}');
    print('   - Updated options count: ${event.updatedOptions?.length ?? 0}');

    if (state is! QuestionPaperLoaded) {
      print('   ❌ Error: State is not QuestionPaperLoaded');
      return;
    }

    final currentState = state as QuestionPaperLoaded;
    final currentPaper = currentState.currentPaper;

    if (currentPaper == null) {
      print('   ❌ Error: No paper loaded');
      emit(const QuestionPaperError('No paper loaded'));
      return;
    }

    try {
      print('   📋 Checking paper structure...');
      // Update the question in the current paper
      final updatedQuestions = Map<String, List<Question>>.from(currentPaper.questions);

      if (!updatedQuestions.containsKey(event.sectionName)) {
        print('   ❌ Error: Section "${event.sectionName}" not found');
        print('      Available sections: ${updatedQuestions.keys.toList()}');
        emit(QuestionPaperError('Section "${event.sectionName}" not found'));
        return;
      }

      final sectionQuestions = List<Question>.from(updatedQuestions[event.sectionName]!);
      print('   - Section "${event.sectionName}" has ${sectionQuestions.length} questions');

      if (event.questionIndex < 0 || event.questionIndex >= sectionQuestions.length) {
        print('   ❌ Error: Invalid question index ${event.questionIndex} (valid range: 0-${sectionQuestions.length - 1})');
        emit(QuestionPaperError('Invalid question index'));
        return;
      }

      // Update the question with new values (only text and options)
      final oldQuestion = sectionQuestions[event.questionIndex];
      print('   🔄 Updating question ${event.questionIndex}:');
      print('      - Old text: "${oldQuestion.text.substring(0, oldQuestion.text.length > 50 ? 50 : oldQuestion.text.length)}${oldQuestion.text.length > 50 ? '...' : ''}"');
      print('      - New text: "${event.updatedText.substring(0, event.updatedText.length > 50 ? 50 : event.updatedText.length)}${event.updatedText.length > 50 ? '...' : ''}"');
      print('      - Old options: ${oldQuestion.options?.length ?? 0}');
      print('      - New options: ${event.updatedOptions?.length ?? 0}');

      sectionQuestions[event.questionIndex] = oldQuestion.copyWith(
        text: event.updatedText,
        options: event.updatedOptions ?? oldQuestion.options,
      );

      updatedQuestions[event.sectionName] = sectionQuestions;

      // Create updated paper with modified questions
      final updatedPaper = currentPaper.copyWith(questions: updatedQuestions);

      // Track which question was edited
      final editedQuestionKey = '${event.sectionName}_${event.questionIndex}';
      final updatedEditedQuestions = Set<String>.from(currentState.editedQuestions)..add(editedQuestionKey);

      print('   ✅ Question updated successfully');
      print('      - Edited questions tracking: $editedQuestionKey');
      print('      - Total edited questions: ${updatedEditedQuestions.length}');

      // Emit success state with updated paper and track edited questions
      emit(currentState.copyWith(
        currentPaper: updatedPaper,
        editedQuestions: updatedEditedQuestions,
      ));

      // Now save the updated paper to the database
      print('   💾 Saving updated paper to database...');
      final result = await _updatePaperUseCase(updatedPaper);

      result.fold(
        (failure) {
          print('   ❌ Database save failed: ${failure.message}');
          emit(QuestionPaperError('Failed to save changes: ${failure.message}'));
        },
        (savedPaper) {
          print('   ✅ Paper saved to database successfully');

          // Emit final loaded state with the saved paper
          emit(currentState.copyWith(
            currentPaper: savedPaper,
            editedQuestions: updatedEditedQuestions,
          ));

          print('   📢 Question update complete - paper displayed with latest changes');
        },
      );
    } catch (e, stackTrace) {
      print('   ❌ Exception occurred: $e');
      print('   Stack trace: $stackTrace');
      emit(QuestionPaperError('Failed to update question: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateSectionName(UpdateSectionName event, Emitter<QuestionPaperState> emit) async {
    print('🎯 [BLoC] UpdateSectionName event received');
    print('   - Old section name: "${event.oldSectionName}"');
    print('   - New section name: "${event.newSectionName}"');

    if (state is! QuestionPaperLoaded) {
      print('   ❌ Error: State is not QuestionPaperLoaded');
      return;
    }

    final currentState = state as QuestionPaperLoaded;
    final currentPaper = currentState.currentPaper;

    if (currentPaper == null) {
      print('   ❌ Error: No paper loaded');
      emit(const QuestionPaperError('No paper loaded'));
      return;
    }

    try {
      print('   📋 Checking paper structure...');

      // Update section name in paperSections
      final updatedSections = currentPaper.paperSections != null
          ? List<PaperSectionEntity>.from(currentPaper.paperSections!)
          : <PaperSectionEntity>[];
      var sectionIndex = -1;

      for (int i = 0; i < updatedSections.length; i++) {
        if (updatedSections[i].name == event.oldSectionName) {
          sectionIndex = i;
          break;
        }
      }

      if (sectionIndex == -1) {
        print('   ❌ Error: Section "${event.oldSectionName}" not found in paperSections');
        emit(QuestionPaperError('Section not found'));
        return;
      }

      // Update the section name
      final oldSection = updatedSections[sectionIndex];
      print('   🔄 Updating section:');
      print('      - Old name: "${oldSection.name}"');
      print('      - New name: "${event.newSectionName}"');

      // Create updated section with new name (assuming section has a copyWith method)
      updatedSections[sectionIndex] = oldSection.copyWith(name: event.newSectionName);

      // Update questions map to use new section name
      final updatedQuestions = <String, List<Question>>{};
      currentPaper.questions.forEach((sectionName, questions) {
        if (sectionName == event.oldSectionName) {
          updatedQuestions[event.newSectionName] = questions;
        } else {
          updatedQuestions[sectionName] = questions;
        }
      });

      // Create updated paper
      final updatedPaper = currentPaper.copyWith(
        paperSections: updatedSections,
        questions: updatedQuestions,
      );

      print('   ✅ Section name updated successfully');

      // Emit success state with updated paper
      emit(currentState.copyWith(currentPaper: updatedPaper));

      // Save the updated paper to the database
      print('   💾 Saving updated paper to database...');
      final result = await _updatePaperUseCase(updatedPaper);

      result.fold(
        (failure) {
          print('   ❌ Database save failed: ${failure.message}');
          emit(QuestionPaperError('Failed to save changes: ${failure.message}'));
        },
        (savedPaper) {
          print('   ✅ Paper saved to database successfully');

          // Emit final loaded state with the saved paper
          emit(currentState.copyWith(currentPaper: savedPaper));

          print('   📢 Section name update complete');
        },
      );
    } catch (e, stackTrace) {
      print('   ❌ Exception occurred: $e');
      print('   Stack trace: $stackTrace');
      emit(QuestionPaperError('Failed to update section: ${e.toString()}'));
    }
  }
}