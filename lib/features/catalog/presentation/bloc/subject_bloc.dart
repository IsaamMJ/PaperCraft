// features/catalog/presentation/bloc/subject_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../data/datasources/subject_data_source.dart';
import '../../data/models/subject_catalog_model.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/repositories/subject_repository.dart';
import '../../domain/usecases/get_subjects_usecase.dart';

// =============== EVENTS ===============
abstract class SubjectEvent extends Equatable {
  const SubjectEvent();
  @override
  List<Object?> get props => [];
}

class LoadSubjectCatalog extends SubjectEvent {
  const LoadSubjectCatalog();
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

// NEW: Load assigned subjects for teacher filtering
class LoadAssignedSubjects extends SubjectEvent {
  final String? teacherId; // null for admins
  final String? academicYear;

  const LoadAssignedSubjects({
    this.teacherId,
    this.academicYear,
  });

  @override
  List<Object?> get props => [teacherId, academicYear];
}

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

class SubjectCatalogLoaded extends SubjectState {
  final List<SubjectCatalogModel> catalog;
  const SubjectCatalogLoaded(this.catalog);
  @override
  List<Object> get props => [catalog];
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
  final SubjectRepository _subjectRepository;

  SubjectBloc({
    required GetSubjectsUseCase getSubjectsUseCase,
    required GetSubjectsByGradeUseCase getSubjectsByGradeUseCase,
    required GetSubjectByIdUseCase getSubjectByIdUseCase,
    required SubjectRepository subjectRepository,
  })  : _getSubjectsUseCase = getSubjectsUseCase,
        _getSubjectsByGradeUseCase = getSubjectsByGradeUseCase,
        _getSubjectByIdUseCase = getSubjectByIdUseCase,
        _subjectRepository = subjectRepository,
        super(SubjectInitial()) {
    on<LoadSubjectCatalog>(_onLoadSubjectCatalog);
    on<LoadSubjects>(_onLoadSubjects);
    on<LoadSubjectsByGrade>(_onLoadSubjectsByGrade);
    on<LoadSubjectById>(_onLoadSubjectById);
    on<LoadAssignedSubjects>(_onLoadAssignedSubjects); // NEW HANDLER
    on<CreateSubject>(_onCreateSubject);
    on<UpdateSubject>(_onUpdateSubject);
    on<DeleteSubject>(_onDeleteSubject);
  }

  Future<void> _onLoadSubjectCatalog(LoadSubjectCatalog event, Emitter<SubjectState> emit) async {
    emit(const SubjectLoading(message: 'Loading subject catalog...'));

    try {
      final dataSource = sl<SubjectDataSource>();
      final catalog = await dataSource.getSubjectCatalog();
      emit(SubjectCatalogLoaded(catalog));
    } catch (e) {
      emit(SubjectError('Failed to load catalog: ${e.toString()}'));
    }
  }

  Future<void> _onLoadSubjects(LoadSubjects event, Emitter<SubjectState> emit) async {
    emit(const SubjectLoading(message: 'Loading subjects...'));

    try {
      final result = await _getSubjectsUseCase();
      result.fold(
        (failure) {
          print('[SubjectBloc] Load subjects failed: ${failure.message}');
          emit(SubjectError(failure.message));
        },
        (subjects) {
          print('[SubjectBloc] Loaded ${subjects.length} subjects');
          emit(SubjectsLoaded(subjects));
        },
      );
    } catch (e) {
      print('[SubjectBloc] Exception loading subjects: $e');
      emit(SubjectError('Failed to load subjects: ${e.toString()}'));
    }
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
    emit(const SubjectLoading(message: 'Loading subject...'));
    final result = await _getSubjectByIdUseCase(event.subjectId);
    result.fold(
          (failure) => emit(SubjectError(failure.message)),
          (subject) => emit(SubjectLoaded(event.subjectId, subject)),
    );
  }

  // =============== NEW: ASSIGNED SUBJECTS HANDLER ===============
  Future<void> _onLoadAssignedSubjects(
      LoadAssignedSubjects event,
      Emitter<SubjectState> emit,
      ) async {
    emit(const SubjectLoading(message: 'Loading assigned subjects...'));

    final result = await _subjectRepository.getAssignedSubjects(
      teacherId: event.teacherId,
      academicYear: event.academicYear,
    );

    result.fold(
          (failure) => emit(SubjectError(failure.message)),
          (subjects) => emit(SubjectsLoaded(subjects)),
    );
  }

  Future<void> _onCreateSubject(CreateSubject event, Emitter<SubjectState> emit) async {
    emit(const SubjectLoading(message: 'Enabling subject...'));

    try {
      final result = await _subjectRepository.createSubject(event.subject);
      result.fold(
        (failure) {
          print('[SubjectBloc] Create subject failed: ${failure.message}');
          emit(SubjectError(failure.message));
        },
        (subject) {
          print('[SubjectBloc] Subject created: ${subject.name}');
          emit(SubjectCreated(subject));
        },
      );
    } catch (e) {
      print('[SubjectBloc] Exception creating subject: $e');
      emit(SubjectError('Failed to create subject: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateSubject(UpdateSubject event, Emitter<SubjectState> emit) async {
    emit(const SubjectLoading(message: 'Updating subject...'));
    final result = await _subjectRepository.updateSubject(event.subject);
    result.fold(
          (failure) => emit(SubjectError(failure.message)),
          (subject) => emit(SubjectUpdated(subject)),
    );
  }

  Future<void> _onDeleteSubject(DeleteSubject event, Emitter<SubjectState> emit) async {
    emit(const SubjectLoading(message: 'Disabling subject...'));
    final result = await _subjectRepository.deleteSubject(event.id);
    result.fold(
          (failure) => emit(SubjectError(failure.message)),
          (_) => emit(SubjectDeleted(event.id)),
    );
  }
}