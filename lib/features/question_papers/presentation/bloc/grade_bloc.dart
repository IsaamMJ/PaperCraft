// features/question_papers/presentation/bloc/grade_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/grade_entity.dart';
import '../../domain/repositories/grade_repository.dart';

// =============== EVENTS ===============
abstract class GradeEvent extends Equatable {
  const GradeEvent();

  @override
  List<Object?> get props => [];
}

class LoadGrades extends GradeEvent {
  const LoadGrades();
}

class LoadGradeLevels extends GradeEvent {
  const LoadGradeLevels();
}

class LoadGradesByLevel extends GradeEvent {
  final int level;

  const LoadGradesByLevel(this.level);

  @override
  List<Object> get props => [level];
}

class LoadSectionsByGrade extends GradeEvent {
  final int gradeLevel;

  const LoadSectionsByGrade(this.gradeLevel);

  @override
  List<Object> get props => [gradeLevel];
}

// =============== STATES ===============
abstract class GradeState extends Equatable {
  const GradeState();

  @override
  List<Object?> get props => [];
}

class GradeInitial extends GradeState {}

class GradeLoading extends GradeState {
  final String? message;

  const GradeLoading({this.message});

  @override
  List<Object?> get props => [message];
}

class GradesLoaded extends GradeState {
  final List<GradeEntity> grades;

  const GradesLoaded(this.grades);

  @override
  List<Object> get props => [grades];
}

class GradeLevelsLoaded extends GradeState {
  final List<int> gradeLevels;

  const GradeLevelsLoaded(this.gradeLevels);

  @override
  List<Object> get props => [gradeLevels];
}

class GradesByLevelLoaded extends GradeState {
  final int level;
  final List<GradeEntity> grades;

  const GradesByLevelLoaded(this.level, this.grades);

  @override
  List<Object> get props => [level, grades];
}

class SectionsLoaded extends GradeState {
  final int gradeLevel;
  final List<String> sections;

  const SectionsLoaded(this.gradeLevel, this.sections);

  @override
  List<Object> get props => [gradeLevel, sections];
}

class GradeError extends GradeState {
  final String message;

  const GradeError(this.message);

  @override
  List<Object> get props => [message];
}

// =============== BLOC ===============
class GradeBloc extends Bloc<GradeEvent, GradeState> {
  final GradeRepository _repository;

  GradeBloc({required GradeRepository repository})
      : _repository = repository,
        super(GradeInitial()) {
    on<LoadGrades>(_onLoadGrades);
    on<LoadGradeLevels>(_onLoadGradeLevels);
    on<LoadGradesByLevel>(_onLoadGradesByLevel);
    on<LoadSectionsByGrade>(_onLoadSectionsByGrade);
  }

  Future<void> _onLoadGrades(LoadGrades event, Emitter<GradeState> emit) async {
    emit(const GradeLoading(message: 'Loading grades...'));

    final result = await _repository.getGrades();

    result.fold(
          (failure) => emit(GradeError(failure.message)),
          (grades) => emit(GradesLoaded(grades)),
    );
  }

  Future<void> _onLoadGradeLevels(LoadGradeLevels event, Emitter<GradeState> emit) async {
    emit(const GradeLoading(message: 'Loading grade levels...'));

    final result = await _repository.getAvailableGradeLevels();

    result.fold(
          (failure) => emit(GradeError(failure.message)),
          (gradeLevels) => emit(GradeLevelsLoaded(gradeLevels)),
    );
  }

  Future<void> _onLoadGradesByLevel(LoadGradesByLevel event, Emitter<GradeState> emit) async {
    emit(GradeLoading(message: 'Loading grades for level ${event.level}...'));

    final result = await _repository.getGradesByLevel(event.level);

    result.fold(
          (failure) => emit(GradeError(failure.message)),
          (grades) => emit(GradesByLevelLoaded(event.level, grades)),
    );
  }

  Future<void> _onLoadSectionsByGrade(LoadSectionsByGrade event, Emitter<GradeState> emit) async {
    // Don't emit loading state here as it's a quick operation
    final result = await _repository.getSectionsByGradeLevel(event.gradeLevel);

    result.fold(
          (failure) => emit(GradeError(failure.message)),
          (sections) => emit(SectionsLoaded(event.gradeLevel, sections)),
    );
  }
}