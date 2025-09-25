// features/question_papers/presentation/bloc/question_paper_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/paper_status.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/exam_type_entity.dart'; // ADD THIS IMPORT
import '../../domain/usecases/save_draft_usecase.dart';
import '../../domain/usecases/submit_paper_usecase.dart';
import '../../domain/usecases/get_drafts_usecase.dart';
import '../../domain/usecases/get_user_submissions_usecase.dart';
import '../../domain/usecases/approve_paper_usecase.dart';
import '../../domain/usecases/reject_paper_usecase.dart';
import '../../domain/usecases/get_papers_for_review_usecase.dart';
import '../../domain/usecases/delete_draft_usecase.dart';
import '../../domain/usecases/pull_for_editing_usecase.dart';
import '../../domain/usecases/get_paper_by_id_usecase.dart';
import '../../domain/usecases/get_all_papers_for_admin_usecase.dart';
import '../../domain/usecases/get_approved_papers_usecase.dart';
import '../../domain/usecases/get_exam_types_usecase.dart'; // ADD THIS IMPORT

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
  final List<ExamTypeEntity> examTypes;
  final QuestionPaperEntity? currentPaper;

  const QuestionPaperLoaded({
    this.drafts = const [],
    this.submissions = const [],
    this.papersForReview = const [],
    this.allPapersForAdmin = const [],
    this.approvedPapers = const [],
    this.examTypes = const [],
    this.currentPaper,
  });

  @override
  List<Object?> get props => [
    drafts,
    submissions,
    papersForReview,
    allPapersForAdmin,
    approvedPapers,
    examTypes,
    currentPaper
  ];

  QuestionPaperLoaded copyWith({
    List<QuestionPaperEntity>? drafts,
    List<QuestionPaperEntity>? submissions,
    List<QuestionPaperEntity>? papersForReview,
    List<QuestionPaperEntity>? allPapersForAdmin,
    List<QuestionPaperEntity>? approvedPapers,
    List<ExamTypeEntity>? examTypes,
    QuestionPaperEntity? currentPaper,
    bool clearCurrentPaper = false,
  }) {
    return QuestionPaperLoaded(
      drafts: drafts ?? this.drafts,
      submissions: submissions ?? this.submissions,
      papersForReview: papersForReview ?? this.papersForReview,
      allPapersForAdmin: allPapersForAdmin ?? this.allPapersForAdmin,
      approvedPapers: approvedPapers ?? this.approvedPapers,
      examTypes: examTypes ?? this.examTypes,
      currentPaper: clearCurrentPaper ? null : (currentPaper ?? this.currentPaper),
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
  final GetExamTypesUseCase _getExamTypesUseCase;

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
    required GetExamTypesUseCase getExamTypesUseCase,
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
        _getExamTypesUseCase = getExamTypesUseCase,
        super(QuestionPaperInitial()) {
    on<LoadDrafts>(_onLoadDrafts);
    on<LoadUserSubmissions>(_onLoadUserSubmissions);
    on<LoadPapersForReview>(_onLoadPapersForReview);
    on<LoadAllPapersForAdmin>(_onLoadAllPapersForAdmin);
    on<LoadApprovedPapers>(_onLoadApprovedPapers);
    on<LoadExamTypes>(_onLoadExamTypes);
    on<LoadPaperById>(_onLoadPaperById);
    on<SaveDraft>(_onSaveDraft);
    on<SubmitPaper>(_onSubmitPaper);
    on<ApprovePaper>(_onApprovePaper);
    on<RejectPaper>(_onRejectPaper);
    on<DeleteDraft>(_onDeleteDraft);
    on<PullForEditing>(_onPullForEditing);
    on<RefreshAll>(_onRefreshAll);
  }

  Future<void> _onLoadDrafts(LoadDrafts event, Emitter<QuestionPaperState> emit) async {
    final result = await _getDraftsUseCase();

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (drafts) {
        if (state is QuestionPaperLoaded) {
          final currentState = state as QuestionPaperLoaded;
          emit(currentState.copyWith(drafts: drafts));
        } else {
          emit(QuestionPaperLoaded(drafts: drafts));
        }
      },
    );
  }

  Future<void> _onLoadUserSubmissions(LoadUserSubmissions event, Emitter<QuestionPaperState> emit) async {
    final result = await _getUserSubmissionsUseCase();

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (submissions) {
        if (state is QuestionPaperLoaded) {
          final currentState = state as QuestionPaperLoaded;
          emit(currentState.copyWith(submissions: submissions));
        } else {
          emit(QuestionPaperLoaded(submissions: submissions));
        }
      },
    );
  }

  Future<void> _onLoadPapersForReview(LoadPapersForReview event, Emitter<QuestionPaperState> emit) async {
    final result = await _getPapersForReviewUseCase();

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (papers) {
        if (state is QuestionPaperLoaded) {
          final currentState = state as QuestionPaperLoaded;
          emit(currentState.copyWith(papersForReview: papers));
        } else {
          emit(QuestionPaperLoaded(papersForReview: papers));
        }
      },
    );
  }

  Future<void> _onLoadAllPapersForAdmin(LoadAllPapersForAdmin event, Emitter<QuestionPaperState> emit) async {
    final result = await _getAllPapersForAdminUseCase();

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (allPapers) {
        if (state is QuestionPaperLoaded) {
          final currentState = state as QuestionPaperLoaded;
          emit(currentState.copyWith(allPapersForAdmin: allPapers));
        } else {
          emit(QuestionPaperLoaded(allPapersForAdmin: allPapers));
        }
      },
    );
  }

  Future<void> _onLoadApprovedPapers(LoadApprovedPapers event, Emitter<QuestionPaperState> emit) async {
    final result = await _getApprovedPapersUseCase();

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (approvedPapers) {
        if (state is QuestionPaperLoaded) {
          final currentState = state as QuestionPaperLoaded;
          emit(currentState.copyWith(approvedPapers: approvedPapers));
        } else {
          emit(QuestionPaperLoaded(approvedPapers: approvedPapers));
        }
      },
    );
  }

  Future<void> _onLoadExamTypes(LoadExamTypes event, Emitter<QuestionPaperState> emit) async {
    final result = await _getExamTypesUseCase();

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (examTypes) {
        if (state is QuestionPaperLoaded) {
          final currentState = state as QuestionPaperLoaded;
          emit(currentState.copyWith(examTypes: examTypes));
        } else {
          emit(QuestionPaperLoaded(examTypes: examTypes));
        }
      },
    );
  }

  Future<void> _onLoadPaperById(LoadPaperById event, Emitter<QuestionPaperState> emit) async {
    emit(const QuestionPaperLoading(message: 'Loading paper...'));

    final result = await _getPaperByIdUseCase(event.paperId);

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (paper) {
        if (state is QuestionPaperLoaded) {
          final currentState = state as QuestionPaperLoaded;
          emit(currentState.copyWith(currentPaper: paper));
        } else {
          emit(QuestionPaperLoaded(currentPaper: paper));
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
}