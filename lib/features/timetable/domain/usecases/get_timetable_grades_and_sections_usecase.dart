import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/domain/errors/failures.dart';
import '../entities/timetable_grade_entity.dart';

/// Use case for fetching grades and sections available for creating timetables
///
/// Business Logic:
/// - Fetches grades from the 'grades' table filtered by tenant
/// - Fetches sections from the 'grade_section_subject' junction table filtered by tenant
/// - Deduplicates sections (junction table has multiple rows per section due to different subjects)
/// - Maps sections to grades by gradeNumber
/// - Returns Either<Failure, TimetableGradesAndSectionsData>
///
/// This follows the same pattern as teacher onboarding for data consistency
///
/// Example:
/// ```dart
/// final usecase = GetTimetableGradesAndSectionsUsecase();
/// final result = await usecase(params: GetTimetableGradesAndSectionsParams(
///   tenantId: 'tenant-123',
/// ));
/// result.fold(
///   (failure) => print('Error: ${failure.message}'),
///   (gradesData) => print('Found ${gradesData.grades.length} grades'),
/// );
/// ```
class GetTimetableGradesAndSectionsUsecase {
  GetTimetableGradesAndSectionsUsecase();

  /// Fetch grades and sections for a tenant
  ///
  /// Parameters:
  /// - [params] - Contains tenantId for filtering grades/sections
  ///
  /// Returns:
  /// - [Either<Failure, TimetableGradesAndSectionsData>] - Grades with sections or failure
  Future<Either<Failure, TimetableGradesAndSectionsData>> call({
    required GetTimetableGradesAndSectionsParams params,
  }) async {
    try {
      final supabase = Supabase.instance.client;


      // Step 1: Load grades for this tenant
      final gradesData = await supabase
          .from('grades')
          .select()
          .eq('tenant_id', params.tenantId);


      final availableGrades = (gradesData as List).map((g) {
        return TimetableGradeEntity(
          gradeId: g['id'] as String,
          gradeNumber: g['grade_number'] as int,
          sections: [], // Will be populated below
        );
      }).toList();

      // Step 2: Load sections from grade_section_subject table
      final sectionsRaw = await supabase
          .from('grade_section_subject')
          .select('grade_id, section')
          .eq('tenant_id', params.tenantId);


      // Deduplicate: junction table has multiple rows per (grade_id, section) due to different subjects
      final sectionsMap = <String, Set<String>>{}; // grade_id -> set of sections
      for (var row in (sectionsRaw as List)) {
        final gradeId = row['grade_id'] as String;
        final section = row['section'] as String;
        sectionsMap.putIfAbsent(gradeId, () => {}).add(section);
      }


      // Step 3: Build grade_number lookup map
      final gradeNumberMap = <String, int>{}; // grade_id -> grade_number
      for (var grade in (gradesData as List)) {
        gradeNumberMap[grade['id'] as String] = grade['grade_number'] as int;
      }


      // Step 4: Map sections to grades
      final sectionsByGradeNumber = <int, List<String>>{};
      for (var gradeId in sectionsMap.keys) {
        if (gradeNumberMap.containsKey(gradeId)) {
          final gradeNumber = gradeNumberMap[gradeId]!;
          final sections = sectionsMap[gradeId]!.toList()..sort();
          sectionsByGradeNumber[gradeNumber] = sections;
        }
      }


      // Step 5: Create grades with populated sections
      final gradesWithSections = availableGrades
          .map((grade) {
            final sections = sectionsByGradeNumber[grade.gradeNumber] ?? [];
            return TimetableGradeEntity(
              gradeId: grade.gradeId,
              gradeNumber: grade.gradeNumber,
              sections: sections,
            );
          })
          .toList();


      return Right(
        TimetableGradesAndSectionsData(
          grades: gradesWithSections,
          sectionsByGradeNumber: sectionsByGradeNumber,
        ),
      );
    } catch (e) {
      return Left(
        ServerFailure('Failed to fetch grades and sections: $e'),
      );
    }
  }
}

/// Parameters for GetTimetableGradesAndSectionsUsecase
class GetTimetableGradesAndSectionsParams {
  final String tenantId;

  GetTimetableGradesAndSectionsParams({required this.tenantId});
}
