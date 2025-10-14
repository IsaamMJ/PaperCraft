// features/catalog/domain/repositories/teacher_pattern_repository.dart
import '../entities/teacher_pattern_entity.dart';

/// Repository interface for managing teacher patterns
/// Handles CRUD operations and smart save logic with de-duplication
abstract class ITeacherPatternRepository {
  /// Get all patterns for a specific teacher and subject
  /// Returns patterns sorted by use count and last used date
  Future<List<TeacherPatternEntity>> getPatternsByTeacherAndSubject({
    required String teacherId,
    required String subjectId,
  });

  /// Get all patterns for a teacher across all subjects
  Future<List<TeacherPatternEntity>> getPatternsByTeacher({
    required String teacherId,
  });

  /// Get a single pattern by ID
  Future<TeacherPatternEntity?> getPatternById(String patternId);

  /// Save or update a pattern
  /// If an identical pattern exists (same sections), increments use_count
  /// Otherwise creates a new pattern entry
  Future<TeacherPatternEntity> saveOrUpdatePattern({
    required TeacherPatternEntity pattern,
  });

  /// Create a new pattern
  Future<TeacherPatternEntity> createPattern({
    required TeacherPatternEntity pattern,
  });

  /// Update an existing pattern
  Future<TeacherPatternEntity> updatePattern({
    required TeacherPatternEntity pattern,
  });

  /// Delete a pattern
  Future<void> deletePattern(String patternId);

  /// Increment use count for a pattern
  /// Called when teacher loads a pattern for a new paper
  Future<void> incrementUseCount(String patternId);

  /// Rename a pattern
  Future<TeacherPatternEntity> renamePattern({
    required String patternId,
    required String newName,
  });

  /// Get most frequently used patterns for a teacher
  Future<List<TeacherPatternEntity>> getMostUsedPatterns({
    required String teacherId,
    required String subjectId,
    int limit = 5,
  });

  /// Get recently used patterns for a teacher
  Future<List<TeacherPatternEntity>> getRecentPatterns({
    required String teacherId,
    required String subjectId,
    int limit = 5,
  });
}
