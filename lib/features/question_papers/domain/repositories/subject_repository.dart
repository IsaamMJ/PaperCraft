// features/question_papers/domain/repositories/subject_repository.dart
import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/subject_entity.dart';

abstract class SubjectRepository {
  Future<Either<Failure, List<SubjectEntity>>> getSubjects();
  Future<Either<Failure, List<SubjectEntity>>> getSubjectsByGrade(int gradeLevel);
  Future<Either<Failure, SubjectEntity?>> getSubjectById(String id);

  // NEW CRUD METHODS
  Future<Either<Failure, SubjectEntity>> createSubject(SubjectEntity subject);
  Future<Either<Failure, SubjectEntity>> updateSubject(SubjectEntity subject);
  Future<Either<Failure, void>> deleteSubject(String id);
}