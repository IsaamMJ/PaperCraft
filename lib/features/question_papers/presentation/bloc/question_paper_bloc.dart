// features/question_papers/presentation/bloc/question_paper_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/question_paper_entity.dart';
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
  final QuestionPaperEntity? currentPaper;

  const QuestionPaperLoaded({
    this.drafts = const [],
    this.submissions = const [],
    this.papersForReview = const [],
    this.currentPaper,
  });

  @override
  List<Object?> get props => [drafts, submissions, papersForReview, currentPaper];

  QuestionPaperLoaded copyWith({
    List<QuestionPaperEntity>? drafts,
    List<QuestionPaperEntity>? submissions,
    List<QuestionPaperEntity>? papersForReview,
    QuestionPaperEntity? currentPaper,
    bool clearCurrentPaper = false,
  }) {
    return QuestionPaperLoaded(
      drafts: drafts ?? this.drafts,
      submissions: submissions ?? this.submissions,
      papersForReview: papersForReview ?? this.papersForReview,
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
        super(QuestionPaperInitial()) {
    on<LoadDrafts>(_onLoadDrafts);
    on<LoadUserSubmissions>(_onLoadUserSubmissions);
    on<LoadPapersForReview>(_onLoadPapersForReview);
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

  Future<void> _onPullForEditing(PullForEditing event, Emitter<QuestionPaperState> emit) async {
    emit(const QuestionPaperLoading(message: 'Pulling paper for editing...'));

    final result = await _pullForEditingUseCase(event.paperId);

    result.fold(
          (failure) => emit(QuestionPaperError(failure.message)),
          (editablePaper) {
        emit(const QuestionPaperSuccess('Paper is now available for editing', actionType: 'pull'));
        add(const LoadDrafts());
      },
    );
  }

  Future<void> _onRefreshAll(RefreshAll event, Emitter<QuestionPaperState> emit) async {
    add(const LoadDrafts());
    add(const LoadUserSubmissions());
    add(const LoadPapersForReview());
  }
}