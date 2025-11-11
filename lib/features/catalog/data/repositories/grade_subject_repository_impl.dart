import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../../domain/entities/grade_subject.dart';
import '../../domain/repositories/grade_subject_repository.dart';
import '../datasources/grade_subject_data_source.dart';
import '../models/grade_subject_model.dart';

/// Implementation of GradeSubjectRepository
/// Handles CRUD operations for grade-section-subject relationships
class GradeSubjectRepositoryImpl implements GradeSubjectRepository {
  final GradeSubjectDataSource _dataSource;

  GradeSubjectRepositoryImpl(this._dataSource);

  @override
  Future<Either<Failure, List<GradeSubject>>> getSubjectsForGradeSection({
    required String tenantId,
    required String gradeId,
    required String sectionId,
    bool activeOnly = true,
  }) async {
    try {

      final models = await _dataSource.getSubjectsForGradeSection(
        tenantId,
        gradeId,
        sectionId,
      );

      final entities = models.map((model) => model.toEntity()).toList();

      return Right(entities);
    } catch (e) {
      return Left(StorageFailure(message: 'Failed to get subjects: $e'));
    }
  }

  @override
  Future<Either<Failure, GradeSubject?>> getGradeSubjectById(String id) async {
    try {
      final model = await _dataSource.getGradeSubjectById(id);
      if (model == null) return const Right(null);

      return Right(model.toEntity());
    } catch (e) {
      return Left(StorageFailure(message: 'Failed to get grade subject: $e'));
    }
  }

  @override
  Future<Either<Failure, GradeSubject>> addSubjectToSection(
    GradeSubject gradeSubject,
  ) async {
    try {

      final model = GradeSubjectModel.fromEntity(gradeSubject);
      final resultModel = await _dataSource.addSubjectToSection(model);

      return Right(resultModel.toEntity());
    } catch (e) {
      return Left(StorageFailure(message: 'Failed to add subject: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeSubjectFromSection(
    String gradeSubjectId,
  ) async {
    try {

      await _dataSource.removeSubjectFromSection(gradeSubjectId);

      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(message: 'Failed to remove subject: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateGradeSubject(
    GradeSubject gradeSubject,
  ) async {
    try {

      final model = GradeSubjectModel.fromEntity(gradeSubject);
      await _dataSource.updateGradeSubject(model);

      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(message: 'Failed to update subject: $e'));
    }
  }

  @override
  Future<Either<Failure, List<GradeSubject>>> getSubjectsForGrade({
    required String tenantId,
    required String gradeId,
    bool activeOnly = true,
  }) async {
    try {

      final models = await _dataSource.getSubjectsForGrade(tenantId, gradeId);
      final entities = models.map((model) => model.toEntity()).toList();

      return Right(entities);
    } catch (e) {
      return Left(StorageFailure(message: 'Failed to get subjects: $e'));
    }
  }

  @override
  Future<Either<Failure, List<GradeSubject>>> addMultipleSubjectsToSection({
    required String tenantId,
    required String gradeId,
    required String sectionId,
    required List<String> subjectIds,
  }) async {
    try {

      final models = await _dataSource.addMultipleSubjectsToSection(
        tenantId,
        gradeId,
        sectionId,
        subjectIds,
      );

      final entities = models.map((model) => model.toEntity()).toList();

      return Right(entities);
    } catch (e) {
      return Left(StorageFailure(message: 'Failed to add subjects: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> clearSubjectsFromSection({
    required String tenantId,
    required String gradeId,
    required String sectionId,
  }) async {
    try {

      await _dataSource.clearSubjectsFromSection(tenantId, gradeId, sectionId);

      return const Right(null);
    } catch (e) {
      return Left(StorageFailure(message: 'Failed to clear subjects: $e'));
    }
  }
}
