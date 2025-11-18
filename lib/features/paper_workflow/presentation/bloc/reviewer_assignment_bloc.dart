import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../authentication/domain/entities/reviewer_assignment_entity.dart';
import '../../../authentication/domain/repositories/reviewer_assignment_repository.dart';

// Events
abstract class ReviewerAssignmentEvent extends Equatable {
  const ReviewerAssignmentEvent();

  @override
  List<Object?> get props => [];
}

class LoadReviewerAssignments extends ReviewerAssignmentEvent {
  final String tenantId;

  const LoadReviewerAssignments(this.tenantId);

  @override
  List<Object?> get props => [tenantId];
}

class CreateReviewerAssignment extends ReviewerAssignmentEvent {
  final String tenantId;
  final String reviewerId;
  final int gradeMin;
  final int gradeMax;

  const CreateReviewerAssignment({
    required this.tenantId,
    required this.reviewerId,
    required this.gradeMin,
    required this.gradeMax,
  });

  @override
  List<Object?> get props => [tenantId, reviewerId, gradeMin, gradeMax];
}

class UpdateReviewerAssignment extends ReviewerAssignmentEvent {
  final String assignmentId;
  final int gradeMin;
  final int gradeMax;

  const UpdateReviewerAssignment({
    required this.assignmentId,
    required this.gradeMin,
    required this.gradeMax,
  });

  @override
  List<Object?> get props => [assignmentId, gradeMin, gradeMax];
}

class DeleteReviewerAssignment extends ReviewerAssignmentEvent {
  final String assignmentId;

  const DeleteReviewerAssignment(this.assignmentId);

  @override
  List<Object?> get props => [assignmentId];
}

// States
abstract class ReviewerAssignmentState extends Equatable {
  const ReviewerAssignmentState();

  @override
  List<Object?> get props => [];
}

class ReviewerAssignmentInitial extends ReviewerAssignmentState {}

class ReviewerAssignmentLoading extends ReviewerAssignmentState {
  final String? message;

  const ReviewerAssignmentLoading({this.message});

  @override
  List<Object?> get props => [message];
}

class ReviewerAssignmentLoaded extends ReviewerAssignmentState {
  final List<ReviewerAssignmentEntity> assignments;

  const ReviewerAssignmentLoaded(this.assignments);

  @override
  List<Object?> get props => [assignments];
}

class ReviewerAssignmentError extends ReviewerAssignmentState {
  final String message;

  const ReviewerAssignmentError(this.message);

  @override
  List<Object?> get props => [message];
}

class ReviewerAssignmentSuccess extends ReviewerAssignmentState {
  final String message;

  const ReviewerAssignmentSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class ReviewerAssignmentBloc extends Bloc<ReviewerAssignmentEvent, ReviewerAssignmentState> {
  final ReviewerAssignmentRepository _repository;

  ReviewerAssignmentBloc({ReviewerAssignmentRepository? repository})
      : _repository = repository ?? sl<ReviewerAssignmentRepository>(),
        super(ReviewerAssignmentInitial()) {
    print('[DEBUG BLOC] ReviewerAssignmentBloc initialized');
    on<LoadReviewerAssignments>(_onLoadReviewerAssignments);
    on<CreateReviewerAssignment>(_onCreateReviewerAssignment);
    on<UpdateReviewerAssignment>(_onUpdateReviewerAssignment);
    on<DeleteReviewerAssignment>(_onDeleteReviewerAssignment);
  }

  @override
  void onEvent(ReviewerAssignmentEvent event) {
    print('[DEBUG BLOC] Event received: ${event.runtimeType}');
    super.onEvent(event);
  }

  Future<void> _onLoadReviewerAssignments(
    LoadReviewerAssignments event,
    Emitter<ReviewerAssignmentState> emit,
  ) async {
    print('[DEBUG BLOC] Loading reviewer assignments for tenant: ${event.tenantId}');
    emit(const ReviewerAssignmentLoading(message: 'Loading assignments...'));

    final result = await _repository.getReviewerAssignments(event.tenantId);

    result.fold(
      (failure) {
        print('[DEBUG BLOC] Load failed: ${failure.message}');
        emit(ReviewerAssignmentError(failure.message));
      },
      (assignments) {
        print('[DEBUG BLOC] Loaded ${assignments.length} assignments');
        emit(ReviewerAssignmentLoaded(assignments));
      },
    );
  }

  Future<void> _onCreateReviewerAssignment(
    CreateReviewerAssignment event,
    Emitter<ReviewerAssignmentState> emit,
  ) async {
    print('[DEBUG BLOC] Creating reviewer assignment');
    emit(const ReviewerAssignmentLoading(message: 'Creating assignment...'));

    final result = await _repository.createReviewerAssignment(
      tenantId: event.tenantId,
      reviewerId: event.reviewerId,
      gradeMin: event.gradeMin,
      gradeMax: event.gradeMax,
    );

    result.fold(
      (failure) {
        print('[DEBUG BLOC] Create failed: ${failure.message}');
        emit(ReviewerAssignmentError(failure.message));
      },
      (_) {
        print('[DEBUG BLOC] Assignment created successfully');
        emit(const ReviewerAssignmentSuccess('Assignment created successfully'));
        add(LoadReviewerAssignments(event.tenantId));
      },
    );
  }

  Future<void> _onUpdateReviewerAssignment(
    UpdateReviewerAssignment event,
    Emitter<ReviewerAssignmentState> emit,
  ) async {
    print('[DEBUG BLOC] Updating reviewer assignment');
    emit(const ReviewerAssignmentLoading(message: 'Updating assignment...'));

    final result = await _repository.updateReviewerAssignment(
      assignmentId: event.assignmentId,
      gradeMin: event.gradeMin,
      gradeMax: event.gradeMax,
    );

    result.fold(
      (failure) {
        print('[DEBUG BLOC] Update failed: ${failure.message}');
        emit(ReviewerAssignmentError(failure.message));
      },
      (_) {
        print('[DEBUG BLOC] Assignment updated successfully');
        emit(const ReviewerAssignmentSuccess('Assignment updated successfully'));
      },
    );
  }

  Future<void> _onDeleteReviewerAssignment(
    DeleteReviewerAssignment event,
    Emitter<ReviewerAssignmentState> emit,
  ) async {
    print('[DEBUG BLOC] Deleting reviewer assignment');
    emit(const ReviewerAssignmentLoading(message: 'Deleting assignment...'));

    final result = await _repository.deleteReviewerAssignment(event.assignmentId);

    result.fold(
      (failure) {
        print('[DEBUG BLOC] Delete failed: ${failure.message}');
        emit(ReviewerAssignmentError(failure.message));
      },
      (_) {
        print('[DEBUG BLOC] Assignment deleted successfully');
        emit(const ReviewerAssignmentSuccess('Assignment deleted successfully'));
      },
    );
  }
}
