// features/assignments/presentation/bloc/teacher_assignment_bloc.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../catalog/domain/repositories/grade_repository.dart';
import '../../../catalog/domain/repositories/subject_repository.dart';
import '../../domain/repositories/assignment_repository.dart';

// =============== EVENTS ===============
abstract class TeacherAssignmentEvent extends Equatable {
  const TeacherAssignmentEvent();

  @override
  List<Object?> get props => [];
}

class LoadTeacherAssignments extends TeacherAssignmentEvent {
  final UserEntity teacher;

  const LoadTeacherAssignments(this.teacher);

  @override
  List<Object> get props => [teacher];
}

class AssignGrade extends TeacherAssignmentEvent {
  final String teacherId;
  final String gradeId;

  const AssignGrade(this.teacherId, this.gradeId);

  @override
  List<Object> get props => [teacherId, gradeId];
}

class RemoveGrade extends TeacherAssignmentEvent {
  final String teacherId;
  final String gradeId;

  const RemoveGrade(this.teacherId, this.gradeId);

  @override
  List<Object> get props => [teacherId, gradeId];
}

class AssignSubject extends TeacherAssignmentEvent {
  final String teacherId;
  final String subjectId;

  const AssignSubject(this.teacherId, this.subjectId);

  @override
  List<Object> get props => [teacherId, subjectId];
}

class RemoveSubject extends TeacherAssignmentEvent {
  final String teacherId;
  final String subjectId;

  const RemoveSubject(this.teacherId, this.subjectId);

  @override
  List<Object> get props => [teacherId, subjectId];
}

// =============== STATES ===============
abstract class TeacherAssignmentState extends Equatable {
  const TeacherAssignmentState();

  @override
  List<Object?> get props => [];
}

class TeacherAssignmentInitial extends TeacherAssignmentState {}

class TeacherAssignmentLoading extends TeacherAssignmentState {
  final String? message;

  const TeacherAssignmentLoading({this.message});

  @override
  List<Object?> get props => [message];
}

class TeacherAssignmentLoaded extends TeacherAssignmentState {
  final UserEntity teacher;
  final List<GradeEntity> assignedGrades;
  final List<SubjectEntity> assignedSubjects;
  final List<GradeEntity> availableGrades;
  final List<SubjectEntity> availableSubjects;

  const TeacherAssignmentLoaded({
    required this.teacher,
    required this.assignedGrades,
    required this.assignedSubjects,
    required this.availableGrades,
    required this.availableSubjects,
  });

  @override
  List<Object> get props => [
    teacher,
    assignedGrades,
    assignedSubjects,
    availableGrades,
    availableSubjects,
  ];
}

class TeacherAssignmentError extends TeacherAssignmentState {
  final String message;

  const TeacherAssignmentError(this.message);

  @override
  List<Object> get props => [message];
}

class AssignmentSuccess extends TeacherAssignmentState {
  final String message;

  const AssignmentSuccess(this.message);

  @override
  List<Object> get props => [message];
}

// =============== BLOC ===============
class TeacherAssignmentBloc extends Bloc<TeacherAssignmentEvent, TeacherAssignmentState> {
  final AssignmentRepository _assignmentRepository;
  final GradeRepository _gradeRepository;
  final SubjectRepository _subjectRepository;
  final UserStateService _userStateService;

  TeacherAssignmentBloc(
      this._assignmentRepository,
      this._gradeRepository,
      this._subjectRepository,
      this._userStateService,
      ) : super(TeacherAssignmentInitial()) {
    on<LoadTeacherAssignments>(_onLoadTeacherAssignments);
    on<AssignGrade>(_onAssignGrade);
    on<RemoveGrade>(_onRemoveGrade);
    on<AssignSubject>(_onAssignSubject);
    on<RemoveSubject>(_onRemoveSubject);
  }

  Future<void> _onLoadTeacherAssignments(
      LoadTeacherAssignments event,
      Emitter<TeacherAssignmentState> emit,
      ) async {
    emit(const TeacherAssignmentLoading(message: 'Loading assignments...'));

    try {
      final academicYear = _userStateService.currentAcademicYear;

      // Load in parallel
      final results = await Future.wait([
        _assignmentRepository.getTeacherAssignedGrades(event.teacher.id, academicYear),
        _assignmentRepository.getTeacherAssignedSubjects(event.teacher.id, academicYear),
        _gradeRepository.getGrades(),
        _subjectRepository.getSubjects(),
      ]);

      // Extract results with proper typing
      final assignedGradesResult = results[0] as Either<Failure, List<GradeEntity>>;
      final assignedSubjectsResult = results[1] as Either<Failure, List<SubjectEntity>>;
      final allGradesResult = results[2] as Either<Failure, List<GradeEntity>>;
      final allSubjectsResult = results[3] as Either<Failure, List<SubjectEntity>>;

      // Check for failures
      if (assignedGradesResult.isLeft() ||
          assignedSubjectsResult.isLeft() ||
          allGradesResult.isLeft() ||
          allSubjectsResult.isLeft()) {

        // Extract error message from first failure
        String errorMessage = 'Failed to load assignments';
        assignedGradesResult.fold((failure) => errorMessage = failure.message, (_) {});

        print('[TeacherAssignmentBloc] Load failed: $errorMessage');
        emit(TeacherAssignmentError(errorMessage));
        return;
      }

      // Extract successful values
      final assignedGrades = assignedGradesResult.fold(
            (_) => <GradeEntity>[],
            (grades) => grades,
      );

      final assignedSubjects = assignedSubjectsResult.fold(
            (_) => <SubjectEntity>[],
            (subjects) => subjects,
      );

      final allGrades = allGradesResult.fold(
            (_) => <GradeEntity>[],
            (grades) => grades,
      );

      final allSubjects = allSubjectsResult.fold(
            (_) => <SubjectEntity>[],
            (subjects) => subjects,
      );

      print('[TeacherAssignmentBloc] Loaded: ${assignedGrades.length} grades, ${assignedSubjects.length} subjects for ${event.teacher.fullName}');

      emit(TeacherAssignmentLoaded(
        teacher: event.teacher,
        assignedGrades: assignedGrades,
        assignedSubjects: assignedSubjects,
        availableGrades: allGrades,
        availableSubjects: allSubjects,
      ));
    } catch (e) {
      print('[TeacherAssignmentBloc] Exception: $e');
      emit(TeacherAssignmentError('Error: ${e.toString()}'));
    }
  }

  Future<void> _onAssignGrade(
      AssignGrade event,
      Emitter<TeacherAssignmentState> emit,
      ) async {
    emit(const TeacherAssignmentLoading(message: 'Assigning grade...'));

    try {
      final academicYear = _userStateService.currentAcademicYear;

      final result = await _assignmentRepository.assignGradeToTeacher(
        teacherId: event.teacherId,
        gradeId: event.gradeId,
        academicYear: academicYear,
      );

      result.fold(
        (failure) {
          print('[TeacherAssignmentBloc] Assign grade failed: ${failure.message}');
          emit(TeacherAssignmentError(failure.message));
        },
        (_) {
          print('[TeacherAssignmentBloc] Grade assigned successfully');
          emit(const AssignmentSuccess('Grade assigned successfully'));
        },
      );
    } catch (e) {
      print('[TeacherAssignmentBloc] Exception assigning grade: $e');
      emit(TeacherAssignmentError('Failed to assign grade: ${e.toString()}'));
    }
  }

  Future<void> _onRemoveGrade(
      RemoveGrade event,
      Emitter<TeacherAssignmentState> emit,
      ) async {
    emit(const TeacherAssignmentLoading(message: 'Removing grade...'));

    final academicYear = _userStateService.currentAcademicYear;

    final result = await _assignmentRepository.removeGradeAssignment(
      teacherId: event.teacherId,
      gradeId: event.gradeId,
      academicYear: academicYear,
    );

    result.fold(
          (failure) => emit(TeacherAssignmentError(failure.message)),
          (_) => emit(const AssignmentSuccess('Grade removed successfully')),
    );
  }

  Future<void> _onAssignSubject(
      AssignSubject event,
      Emitter<TeacherAssignmentState> emit,
      ) async {
    emit(const TeacherAssignmentLoading(message: 'Assigning subject...'));

    try {
      final academicYear = _userStateService.currentAcademicYear;

      final result = await _assignmentRepository.assignSubjectToTeacher(
        teacherId: event.teacherId,
        subjectId: event.subjectId,
        academicYear: academicYear,
      );

      result.fold(
        (failure) {
          print('[TeacherAssignmentBloc] Assign subject failed: ${failure.message}');
          emit(TeacherAssignmentError(failure.message));
        },
        (_) {
          print('[TeacherAssignmentBloc] Subject assigned successfully');
          emit(const AssignmentSuccess('Subject assigned successfully'));
        },
      );
    } catch (e) {
      print('[TeacherAssignmentBloc] Exception assigning subject: $e');
      emit(TeacherAssignmentError('Failed to assign subject: ${e.toString()}'));
    }
  }

  Future<void> _onRemoveSubject(
      RemoveSubject event,
      Emitter<TeacherAssignmentState> emit,
      ) async {
    emit(const TeacherAssignmentLoading(message: 'Removing subject...'));

    final academicYear = _userStateService.currentAcademicYear;

    final result = await _assignmentRepository.removeSubjectAssignment(
      teacherId: event.teacherId,
      subjectId: event.subjectId,
      academicYear: academicYear,
    );

    result.fold(
          (failure) => emit(TeacherAssignmentError(failure.message)),
          (_) => emit(const AssignmentSuccess('Subject removed successfully')),
    );
  }
}