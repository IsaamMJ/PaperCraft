import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/features/student_management/domain/entities/student_entity.dart';
import 'package:papercraft/features/student_management/domain/repositories/student_repository.dart';

class GetStudentsByGradeSectionUseCase {
  final StudentRepository repository;

  GetStudentsByGradeSectionUseCase(this.repository);

  Future<Either<Failure, List<StudentEntity>>> call(
    GetStudentsParams params,
  ) async {
    return await repository.getStudentsByGradeSection(params.gradeSectionId);
  }
}

class GetStudentsParams extends Equatable {
  final String gradeSectionId;

  const GetStudentsParams({required this.gradeSectionId});

  @override
  List<Object?> get props => [gradeSectionId];
}
