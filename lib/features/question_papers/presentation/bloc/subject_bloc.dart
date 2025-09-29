// features/question_papers/presentation/bloc/subject_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/repositories/subject_repository.dart';
import '../../domain/usecases/get_subjects_usecase.dart';

// =============== EVENTS ===============
abstract class SubjectEvent extends Equatable {
  const SubjectEvent();

  @override
  List<Object?> get props => [];
}

class LoadSubjects extends SubjectEvent {
  const LoadSubjects();
}

class LoadSubjectsByGrade extends SubjectEvent {
  final int gradeLevel;

  const LoadSubjectsByGrade(this.gradeLevel);

  @override
  List<Object> get props => [gradeLevel];
}

class LoadSubjectById extends SubjectEvent {
  final String subjectId;

  const LoadSubjectById(this.subjectId);

  @override
  List<Object> get props => [subjectId];
}

// NEW CRUD EVENTS
class CreateSubject extends SubjectEvent {
  final SubjectEntity subject;

  const CreateSubject(this.subject);

  @override
  List<Object> get props => [subject];
}

class UpdateSubject extends SubjectEvent {
  final SubjectEntity subject;

  const UpdateSubject(this.subject);

  @override
  List<Object> get props => [subject];
}

class DeleteSubject extends SubjectEvent {
  final String id;

  const DeleteSubject(this.id);

  @override
  List<Object> get props => [id];
}

// =============== STATES ===============
abstract class SubjectState extends Equatable {
  const SubjectState();

  @override
  List<Object?> get props => [];
}

class SubjectInitial extends SubjectState {}

class SubjectLoading extends SubjectState {
  final String? message;

  const SubjectLoading({this.message});

  @override
  List<Object?> get props => [message];
}

class SubjectsLoaded extends SubjectState {
  final List<SubjectEntity> subjects;

  const SubjectsLoaded(this.subjects);

  @override
  List<Object> get props => [subjects];
}

class SubjectsByGradeLoaded extends SubjectState {
  final int gradeLevel;
  final List<SubjectEntity> subjects;

  const SubjectsByGradeLoaded(this.gradeLevel, this.subjects);

  @override
  List<Object> get props => [gradeLevel, subjects];
}

class SubjectLoaded extends SubjectState {
  final SubjectEntity? subject;
  final String subjectId;

  const SubjectLoaded(this.subjectId, this.subject);

  @override
  List<Object?> get props => [subjectId, subject];
}

// NEW CRUD STATES
class SubjectCreated extends SubjectState {
  final SubjectEntity subject;

  const SubjectCreated(this.subject);

  @override
  List<Object> get props => [subject];
}

class SubjectUpdated extends SubjectState {
  final SubjectEntity subject;

  const SubjectUpdated(this.subject);

  @override
  List<Object> get props => [subject];
}

class SubjectDeleted extends SubjectState {
  final String id;

  const SubjectDeleted(this.id);

  @override
  List<Object> get props => [id];
}

class SubjectError extends SubjectState {
  final String message;

  const SubjectError(this.message);

  @override
  List<Object> get props => [message];
}

// =============== BLOC ===============
class SubjectBloc extends Bloc<SubjectEvent, SubjectState> {
  final GetSubjectsUseCase _getSubjectsUseCase;
  final GetSubjectsByGradeUseCase _getSubjectsByGradeUseCase;
  final GetSubjectByIdUseCase _getSubjectByIdUseCase;

  SubjectBloc({
    required GetSubjectsUseCase getSubjectsUseCase,
    required GetSubjectsByGradeUseCase getSubjectsByGradeUseCase,
    required GetSubjectByIdUseCase getSubjectByIdUseCase,
  })  : _getSubjectsUseCase = getSubjectsUseCase,
        _getSubjectsByGradeUseCase = getSubjectsByGradeUseCase,
        _getSubjectByIdUseCase = getSubjectByIdUseCase,
        super(SubjectInitial()) {
    on<LoadSubjects>(_onLoadSubjects);
    on<LoadSubjectsByGrade>(_onLoadSubjectsByGrade);
    on<LoadSubjectById>(_onLoadSubjectById);
    // NEW CRUD HANDLERS
    on<CreateSubject>(_onCreateSubject);
    on<UpdateSubject>(_onUpdateSubject);
    on<DeleteSubject>(_onDeleteSubject);
  }

  Future<void> _onLoadSubjects(LoadSubjects event, Emitter<SubjectState> emit) async {
    emit(const SubjectLoading(message: 'Loading subjects...'));

    final result = await _getSubjectsUseCase();

    result.fold(
          (failure) => emit(SubjectError(failure.message)),
          (subjects) => emit(SubjectsLoaded(subjects)),
    );
  }

  Future<void> _onLoadSubjectsByGrade(LoadSubjectsByGrade event, Emitter<SubjectState> emit) async {
    emit(SubjectLoading(message: 'Loading subjects for grade ${event.gradeLevel}...'));

    final result = await _getSubjectsByGradeUseCase(event.gradeLevel);

    result.fold(
          (failure) => emit(SubjectError(failure.message)),
          (subjects) => emit(SubjectsByGradeLoaded(event.gradeLevel, subjects)),
    );
  }

  Future<void> _onLoadSubjectById(LoadSubjectById event, Emitter<SubjectState> emit) async {
    emit(SubjectLoading(message: 'Loading subject...'));

    final result = await _getSubjectByIdUseCase(event.subjectId);

    result.fold(
          (failure) => emit(SubjectError(failure.message)),
          (subject) => emit(SubjectLoaded(event.subjectId, subject)),
    );
  }

  // =============== NEW CRUD HANDLERS ===============

  Future<void> _onCreateSubject(CreateSubject event, Emitter<SubjectState> emit) async {
    emit(const SubjectLoading(message: 'Creating subject...'));

    final subjectRepository = sl<SubjectRepository>();
    final result = await subjectRepository.createSubject(event.subject);

    result.fold(
          (failure) => emit(SubjectError(failure.message)),
          (subject) => emit(SubjectCreated(subject)),
    );
  }

  Future<void> _onUpdateSubject(UpdateSubject event, Emitter<SubjectState> emit) async {
    emit(const SubjectLoading(message: 'Updating subject...'));

    final subjectRepository = sl<SubjectRepository>();
    final result = await subjectRepository.updateSubject(event.subject);

    result.fold(
          (failure) => emit(SubjectError(failure.message)),
          (subject) => emit(SubjectUpdated(subject)),
    );
  }

  Future<void> _onDeleteSubject(DeleteSubject event, Emitter<SubjectState> emit) async {
    emit(const SubjectLoading(message: 'Deleting subject...'));

    final subjectRepository = sl<SubjectRepository>();
    final result = await subjectRepository.deleteSubject(event.id);

    result.fold(
          (failure) => emit(SubjectError(failure.message)),
          (_) => emit(SubjectDeleted(event.id)),
    );
  }
}