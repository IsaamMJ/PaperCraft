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
      print('📦 [Repo] Getting subjects for Grade=$gradeId, Section=$sectionId');

      final models = await _dataSource.getSubjectsForGradeSection(
        tenantId,
        gradeId,
        sectionId,
      );

      final entities = models.map((model) => model.toEntity()).toList();
      print('✅ [Repo] Retrieved ${entities.length} subjects');

      return Right(entities);
    } catch (e) {
      print('❌ [Repo] Error getting subjects: $e');
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
      print('📦 [Repo] Adding subject to section');

      final model = GradeSubjectModel.fromEntity(gradeSubject);
      final resultModel = await _dataSource.addSubjectToSection(model);

      print('✅ [Repo] Subject added successfully');
      return Right(resultModel.toEntity());
    } catch (e) {
      print('❌ [Repo] Error adding subject: $e');
      return Left(StorageFailure(message: 'Failed to add subject: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> removeSubjectFromSection(
    String gradeSubjectId,
  ) async {
    try {
      print('📦 [Repo] Removing subject: $gradeSubjectId');

      await _dataSource.removeSubjectFromSection(gradeSubjectId);

      print('✅ [Repo] Subject removed successfully');
      return const Right(null);
    } catch (e) {
      print('❌ [Repo] Error removing subject: $e');
      return Left(StorageFailure(message: 'Failed to remove subject: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> updateGradeSubject(
    GradeSubject gradeSubject,
  ) async {
    try {
      print('📦 [Repo] Updating subject: ${gradeSubject.id}');

      final model = GradeSubjectModel.fromEntity(gradeSubject);
      await _dataSource.updateGradeSubject(model);

      print('✅ [Repo] Subject updated successfully');
      return const Right(null);
    } catch (e) {
      print('❌ [Repo] Error updating subject: $e');
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
      print('📦 [Repo] Getting all subjects for Grade=$gradeId');

      final models = await _dataSource.getSubjectsForGrade(tenantId, gradeId);
      final entities = models.map((model) => model.toEntity()).toList();

      print('✅ [Repo] Retrieved ${entities.length} subjects for grade');
      return Right(entities);
    } catch (e) {
      print('❌ [Repo] Error getting subjects for grade: $e');
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
      print('📦 [Repo] Adding ${subjectIds.length} subjects to section');

      final models = await _dataSource.addMultipleSubjectsToSection(
        tenantId,
        gradeId,
        sectionId,
        subjectIds,
      );

      final entities = models.map((model) => model.toEntity()).toList();
      print('✅ [Repo] Added ${entities.length} subjects successfully');

      return Right(entities);
    } catch (e) {
      print('❌ [Repo] Error adding multiple subjects: $e');
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
      print('📦 [Repo] Clearing all subjects from section');

      await _dataSource.clearSubjectsFromSection(tenantId, gradeId, sectionId);

      print('✅ [Repo] Subjects cleared successfully');
      return const Right(null);
    } catch (e) {
      print('❌ [Repo] Error clearing subjects: $e');
      return Left(StorageFailure(message: 'Failed to clear subjects: $e'));
    }
  }
}
