// features/question_papers/presentation/bloc/exam_type_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/repositories/exam_type_repository.dart';

// =============== EVENTS ===============
abstract class ExamTypeEvent extends Equatable {
  const ExamTypeEvent();

  @override
  List<Object?> get props => [];
}

class LoadExamTypes extends ExamTypeEvent {
  const LoadExamTypes();
}

class CreateExamType extends ExamTypeEvent {
  final ExamTypeEntity examType;

  const CreateExamType(this.examType);

  @override
  List<Object> get props => [examType];
}

class UpdateExamType extends ExamTypeEvent {
  final ExamTypeEntity examType;

  const UpdateExamType(this.examType);

  @override
  List<Object> get props => [examType];
}

class DeleteExamType extends ExamTypeEvent {
  final String id;

  const DeleteExamType(this.id);

  @override
  List<Object> get props => [id];
}

// =============== STATES ===============
abstract class ExamTypeState extends Equatable {
  const ExamTypeState();

  @override
  List<Object?> get props => [];
}

class ExamTypeInitial extends ExamTypeState {}

class ExamTypeLoading extends ExamTypeState {
  final String? message;

  const ExamTypeLoading({this.message});

  @override
  List<Object?> get props => [message];
}

class ExamTypesLoaded extends ExamTypeState {
  final List<ExamTypeEntity> examTypes;

  const ExamTypesLoaded(this.examTypes);

  @override
  List<Object> get props => [examTypes];
}

class ExamTypeCreated extends ExamTypeState {
  final ExamTypeEntity examType;

  const ExamTypeCreated(this.examType);

  @override
  List<Object> get props => [examType];
}

class ExamTypeUpdated extends ExamTypeState {
  final ExamTypeEntity examType;

  const ExamTypeUpdated(this.examType);

  @override
  List<Object> get props => [examType];
}

class ExamTypeDeleted extends ExamTypeState {
  final String id;

  const ExamTypeDeleted(this.id);

  @override
  List<Object> get props => [id];
}

class ExamTypeError extends ExamTypeState {
  final String message;

  const ExamTypeError(this.message);

  @override
  List<Object> get props => [message];
}

// =============== BLOC ===============
class ExamTypeBloc extends Bloc<ExamTypeEvent, ExamTypeState> {
  final ExamTypeRepository _repository;

  ExamTypeBloc({required ExamTypeRepository repository})
      : _repository = repository,
        super(ExamTypeInitial()) {
    on<LoadExamTypes>(_onLoadExamTypes);
    on<CreateExamType>(_onCreateExamType);
    on<UpdateExamType>(_onUpdateExamType);
    on<DeleteExamType>(_onDeleteExamType);
  }

  Future<void> _onLoadExamTypes(LoadExamTypes event, Emitter<ExamTypeState> emit) async {
    emit(const ExamTypeLoading(message: 'Loading exam types...'));

    final result = await _repository.getExamTypes();

    result.fold(
          (failure) => emit(ExamTypeError(failure.message)),
          (examTypes) => emit(ExamTypesLoaded(examTypes)),
    );
  }

  Future<void> _onCreateExamType(CreateExamType event, Emitter<ExamTypeState> emit) async {
    emit(const ExamTypeLoading(message: 'Creating exam type...'));

    final result = await _repository.createExamType(event.examType);

    result.fold(
          (failure) => emit(ExamTypeError(failure.message)),
          (examType) => emit(ExamTypeCreated(examType)),
    );
  }

  Future<void> _onUpdateExamType(UpdateExamType event, Emitter<ExamTypeState> emit) async {
    emit(const ExamTypeLoading(message: 'Updating exam type...'));

    final result = await _repository.updateExamType(event.examType);

    result.fold(
          (failure) => emit(ExamTypeError(failure.message)),
          (examType) => emit(ExamTypeUpdated(examType)),
    );
  }

  Future<void> _onDeleteExamType(DeleteExamType event, Emitter<ExamTypeState> emit) async {
    emit(const ExamTypeLoading(message: 'Deleting exam type...'));

    final result = await _repository.deleteExamType(event.id);

    result.fold(
          (failure) => emit(ExamTypeError(failure.message)),
          (_) => emit(ExamTypeDeleted(event.id)),
    );
  }
}