import 'package:dartz/dartz.dart';

import '../../../../core/domain/errors/failures.dart';
import '../../domain/entities/grade_section.dart';
import '../../domain/repositories/grade_section_repository.dart';
import '../datasources/grade_section_remote_datasource.dart';

/// Implementation of GradeSectionRepository using Supabase as data source
///
/// Handles error conversion: exceptions → Failure objects
/// All operations are wrapped in try-catch to provide Either<Failure, T>
class GradeSectionRepositoryImpl implements GradeSectionRepository {
  final GradeSectionRemoteDataSource remoteDataSource;

  GradeSectionRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<GradeSection>>> getGradeSections({
    required String tenantId,
    String? gradeId,
    bool activeOnly = true,
  }) async {
    try {
      final sections = await remoteDataSource.getGradeSections(
        tenantId: tenantId,
        gradeId: gradeId,
        activeOnly: activeOnly,
      );

      return Right(sections);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch grade sections: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, GradeSection?>> getGradeSectionById(String id) async {
    try {
      final section = await remoteDataSource.getGradeSectionById(id);
      return Right(section);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch grade section: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, GradeSection>> createGradeSection(
    GradeSection section,
  ) async {
    try {
      final createdSection = await remoteDataSource.createGradeSection(section);
      return Right(createdSection);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to create grade section: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> updateGradeSection(GradeSection section) async {
    try {
      await remoteDataSource.updateGradeSection(section);
      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to update grade section: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteGradeSection(String id) async {
    try {
      await remoteDataSource.deleteGradeSection(id);
      return const Right(null);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to delete grade section: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<String>>> getGradesWithSections({
    required String tenantId,
    bool activeOnly = true,
  }) async {
    try {
      final grades = await remoteDataSource.getGradesWithSections(
        tenantId: tenantId,
        activeOnly: activeOnly,
      );

      return Right(grades);
    } on Exception catch (e) {
      return Left(
        ServerFailure('Failed to fetch grades with sections: ${e.toString()}'),
      );
    }
  }
}
