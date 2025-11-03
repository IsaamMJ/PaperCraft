import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../../domain/entities/teacher_subject.dart';
import '../../domain/repositories/teacher_subject_repository.dart';
import '../datasources/teacher_subject_remote_datasource.dart';

/// Implementation of TeacherSubjectRepository using Supabase
class TeacherSubjectRepositoryImpl implements TeacherSubjectRepository {
  final TeacherSubjectRemoteDataSource remoteDataSource;

  TeacherSubjectRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<TeacherSubject>>> getTeacherSubjects({
    required String tenantId,
    String? teacherId,
    String? academicYear,
    bool activeOnly = true,
  }) async {
    // This method requires both teacherId and academicYear
    if (teacherId == null || academicYear == null) {
      return const Left(
        ValidationFailure('teacherId and academicYear are required'),
      );
    }

    try {
      final subjects = await remoteDataSource.getTeacherSubjects(
        tenantId: tenantId,
        teacherId: teacherId,
        academicYear: academicYear,
        activeOnly: activeOnly,
      );

      return Right(subjects);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch teacher subjects: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<TeacherSubject>>> getTeachersFor({
    required String tenantId,
    required String gradeId,
    required String subjectId,
    required String section,
    required String academicYear,
    bool activeOnly = true,
  }) async {
    try {
      final teachers = await remoteDataSource.getTeachersFor(
        tenantId: tenantId,
        gradeId: gradeId,
        subjectId: subjectId,
        section: section,
        academicYear: academicYear,
        activeOnly: activeOnly,
      );

      return Right(teachers);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch teachers for subject: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> saveTeacherSubjects({
    required String tenantId,
    required String teacherId,
    required String academicYear,
    required List<TeacherSubject> assignments,
  }) async {
    try {
      await remoteDataSource.saveTeacherSubjects(
        tenantId: tenantId,
        teacherId: teacherId,
        academicYear: academicYear,
        assignments: assignments,
      );

      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to save teacher subjects: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deactivateTeacherSubject(String id) async {
    try {
      await remoteDataSource.deactivateTeacherSubject(id);
      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to deactivate teacher subject: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, TeacherSubject?>> getTeacherSubjectById(String id) async {
    try {
      final subject = await remoteDataSource.getTeacherSubjectById(id);
      return Right(subject);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch teacher subject: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, int>> countTeachersFor({
    required String tenantId,
    required String gradeId,
    required String subjectId,
    required String section,
    required String academicYear,
  }) async {
    try {
      final count = await remoteDataSource.countTeachersFor(
        tenantId: tenantId,
        gradeId: gradeId,
        subjectId: subjectId,
        section: section,
        academicYear: academicYear,
      );

      return Right(count);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to count teachers: ${e.toString()}'),
      );
    }
  }
}
