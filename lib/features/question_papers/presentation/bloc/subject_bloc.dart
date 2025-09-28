// features/question_papers/presentation/bloc/subject_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/subject_entity.dart';
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
  }

  Future<void> _onLoadSubjects(LoadSubjects event, Emitter<SubjectState> emit) async {
    emit(const SubjectLoading(message: 'Loading subjects...'));

    final result = await _getSubjectsUseCase();

    result.fold(
          (failure) {
        print('🔍 DEBUG: SubjectBloc received failure: ${failure.runtimeType} - ${failure.message}');
        emit(SubjectError(failure.message));
      },
          (subjects) {
        print('🔍 DEBUG: SubjectBloc received subjects: ${subjects.length}');
        emit(SubjectsLoaded(subjects));
      },
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
}