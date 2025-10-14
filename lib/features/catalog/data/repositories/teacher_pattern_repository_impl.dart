// features/catalog/data/repositories/teacher_pattern_repository_impl.dart
import '../../../../core/domain/errors/failures.dart';
import '../../domain/entities/teacher_pattern_entity.dart';
import '../../domain/repositories/teacher_pattern_repository.dart';
import '../datasources/teacher_pattern_data_source.dart';
import '../models/teacher_pattern_model.dart';

/// Implementation of teacher pattern repository
class TeacherPatternRepositoryImpl implements ITeacherPatternRepository {
  final TeacherPatternDataSource dataSource;

  TeacherPatternRepositoryImpl(this.dataSource);

  @override
  Future<List<TeacherPatternEntity>> getPatternsByTeacherAndSubject({
    required String teacherId,
    required String subjectId,
  }) async {
    try {
      final patterns = await dataSource.getPatternsByTeacherAndSubject(
        teacherId: teacherId,
        subjectId: subjectId,
      );
      return patterns.map((p) => p.toEntity()).toList();
    } catch (e) {
      throw ServerFailure('Failed to fetch patterns: ${e.toString()}');
    }
  }

  @override
  Future<List<TeacherPatternEntity>> getPatternsByTeacher({
    required String teacherId,
  }) async {
    try {
      final patterns = await dataSource.getPatternsByTeacher(teacherId: teacherId);
      return patterns.map((p) => p.toEntity()).toList();
    } catch (e) {
      throw ServerFailure('Failed to fetch patterns: ${e.toString()}');
    }
  }

  @override
  Future<TeacherPatternEntity?> getPatternById(String patternId) async {
    try {
      final pattern = await dataSource.getPatternById(patternId);
      return pattern?.toEntity();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<TeacherPatternEntity> saveOrUpdatePattern({
    required TeacherPatternEntity pattern,
  }) async {
    try {
      // Smart de-duplication: Check if identical pattern exists
      final sectionsJson = pattern.sections.map((s) => s.toJson()).toList();
      final existingPattern = await dataSource.findPatternWithSameSections(
        teacherId: pattern.teacherId,
        subjectId: pattern.subjectId,
        sections: sectionsJson,
      );

      if (existingPattern != null) {
        // Pattern exists - increment use count and update last_used_at
        final updated = await dataSource.incrementUseCount(existingPattern.id);
        return updated.toEntity();
      } else {
        // Create new pattern
        final model = TeacherPatternModel.fromEntity(pattern);
        final created = await dataSource.createPattern(model);
        return created.toEntity();
      }
    } catch (e) {
      throw ServerFailure('Failed to save pattern: ${e.toString()}');
    }
  }

  @override
  Future<TeacherPatternEntity> createPattern({
    required TeacherPatternEntity pattern,
  }) async {
    try {
      final model = TeacherPatternModel.fromEntity(pattern);
      final created = await dataSource.createPattern(model);
      return created.toEntity();
    } catch (e) {
      throw ServerFailure('Failed to create pattern: ${e.toString()}');
    }
  }

  @override
  Future<TeacherPatternEntity> updatePattern({
    required TeacherPatternEntity pattern,
  }) async {
    try {
      final sectionsJson = pattern.sections.map((s) => s.toJson()).toList();

      final updates = <String, dynamic>{
        'name': pattern.name,
        'sections': sectionsJson,
        'total_questions': pattern.totalQuestions,
        'total_marks': pattern.totalMarks,
      };

      final updated = await dataSource.updatePattern(
        patternId: pattern.id,
        updates: updates,
      );

      return updated.toEntity();
    } catch (e) {
      throw ServerFailure('Failed to update pattern: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePattern(String patternId) async {
    try {
      await dataSource.deletePattern(patternId);
    } catch (e) {
      throw ServerFailure('Failed to delete pattern: ${e.toString()}');
    }
  }

  @override
  Future<void> incrementUseCount(String patternId) async {
    try {
      await dataSource.incrementUseCount(patternId);
    } catch (e) {
      throw ServerFailure('Failed to increment use count: ${e.toString()}');
    }
  }

  @override
  Future<TeacherPatternEntity> renamePattern({
    required String patternId,
    required String newName,
  }) async {
    try {
      final updates = <String, dynamic>{'name': newName};
      final updated = await dataSource.updatePattern(
        patternId: patternId,
        updates: updates,
      );
      return updated.toEntity();
    } catch (e) {
      throw ServerFailure('Failed to rename pattern: ${e.toString()}');
    }
  }

  @override
  Future<List<TeacherPatternEntity>> getMostUsedPatterns({
    required String teacherId,
    required String subjectId,
    int limit = 5,
  }) async {
    try {
      final patterns = await dataSource.getFrequentlyUsedPatterns(
        teacherId: teacherId,
        subjectId: subjectId,
        limit: limit,
      );
      return patterns.map((p) => p.toEntity()).toList();
    } catch (e) {
      throw ServerFailure('Failed to fetch frequently used patterns: ${e.toString()}');
    }
  }

  @override
  Future<List<TeacherPatternEntity>> getRecentPatterns({
    required String teacherId,
    required String subjectId,
    int limit = 5,
  }) async {
    try {
      final patterns = await dataSource.getRecentPatterns(
        teacherId: teacherId,
        subjectId: subjectId,
        limit: limit,
      );
      return patterns.map((p) => p.toEntity()).toList();
    } catch (e) {
      throw ServerFailure('Failed to fetch recent patterns: ${e.toString()}');
    }
  }
}
