// features/question_papers/domain/usecases/get_subjects_usecase.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/subject_entity.dart';
import '../repositories/subject_repository.dart';

class GetSubjectsUseCase {
  final SubjectRepository repository;

  GetSubjectsUseCase(this.repository);

  Future<Either<Failure, List<SubjectEntity>>> call() async {
    return await repository.getSubjects();
  }
}

class GetSubjectsByGradeUseCase {
  final SubjectRepository repository;

  GetSubjectsByGradeUseCase(this.repository);

  Future<Either<Failure, List<SubjectEntity>>> call(int gradeLevel) async {
    if (gradeLevel < 1 || gradeLevel > 12) {
      return Left(ValidationFailure('Grade level must be between 1 and 12'));
    }
    return await repository.getSubjectsByGrade(gradeLevel);
  }
}

class GetSubjectByIdUseCase {
  final SubjectRepository repository;

  GetSubjectByIdUseCase(this.repository);

  Future<Either<Failure, SubjectEntity?>> call(String id) async {
    if (id.trim().isEmpty) {
      return Left(ValidationFailure('Subject ID is required'));
    }
    return await repository.getSubjectById(id.trim());
  }
}

class GetSubjectsByGradeAndSectionUseCase {
  final SubjectRepository repository;

  GetSubjectsByGradeAndSectionUseCase(this.repository);

  Future<Either<Failure, List<SubjectEntity>>> call(
    String tenantId,
    String gradeId,
    String section,
  ) async {
    if (tenantId.trim().isEmpty) {
      return Left(ValidationFailure('Tenant ID is required'));
    }
    if (gradeId.trim().isEmpty) {
      return Left(ValidationFailure('Grade ID is required'));
    }
    if (section.trim().isEmpty) {
      return Left(ValidationFailure('Section is required'));
    }
    return await repository.getSubjectsByGradeAndSection(tenantId, gradeId, section);
  }
}