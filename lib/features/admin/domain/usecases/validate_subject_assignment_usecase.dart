import 'package:dartz/dartz.dart';
import '../../../../core/domain/errors/failures.dart';
import '../entities/admin_setup_state.dart';

class ValidateSubjectAssignmentUseCase {
  /// Validates that all selected grades and sections have at least one subject assigned
  Either<Failure, bool> call(AdminSetupState setupState) {
    try {
      // If no grades are selected, validation passes (not an error)
      if (setupState.selectedGrades.isEmpty) {
        return const Right(true);
      }

      final unassignedGradeSections = <String>[];

      // Check each selected grade
      for (final grade in setupState.selectedGrades) {
        // Check if grade has any sections
        if (grade.sections.isEmpty) {
          unassignedGradeSections.add('Grade ${grade.gradeNumber}: No sections configured');
          continue;
        }

        // Check each section for subjects
        for (final section in grade.sections) {
          if (section.subjects.isEmpty) {
            unassignedGradeSections
                .add('Grade ${grade.gradeNumber}, Section ${section.sectionName}: No subjects assigned');
          }
        }
      }

      if (unassignedGradeSections.isNotEmpty) {
        final message = 'Subject assignment validation failed:\n' + unassignedGradeSections.join('\n');
        return Left(ValidationFailure(message));
      }

      return const Right(true);
    } catch (e) {
      return Left(ValidationFailure('Error validating subject assignments: $e'));
    }
  }

  /// Validates that a specific grade-section has at least one subject
  Either<Failure, bool> validateGradeSectionHasSubjects(
    int gradeNumber,
    String sectionName,
    AdminSetupState setupState,
  ) {
    try {
      final subjects = setupState.getSubjectsForGradeSection(gradeNumber, sectionName);

      if (subjects.isEmpty) {
        return Left(
          ValidationFailure(
              'Grade $gradeNumber, Section $sectionName must have at least one subject assigned'),
        );
      }

      return const Right(true);
    } catch (e) {
      return Left(ValidationFailure('Error validating grade-section subjects: $e'));
    }
  }

  /// Counts total subjects assigned across all grades and sections
  Either<Failure, int> getTotalSubjectsAssigned(AdminSetupState setupState) {
    try {
      int totalSubjects = 0;

      for (final grade in setupState.selectedGrades) {
        for (final section in grade.sections) {
          totalSubjects += section.subjects.length;
        }
      }

      return Right(totalSubjects);
    } catch (e) {
      return Left(ValidationFailure('Error counting assigned subjects: $e'));
    }
  }

  /// Gets detailed validation report for all grades and sections
  Either<Failure, Map<String, dynamic>> getValidationReport(AdminSetupState setupState) {
    try {
      final report = <String, dynamic>{};
      final gradeReports = <Map<String, dynamic>>[];

      report['totalGrades'] = setupState.selectedGrades.length;
      report['totalSections'] = setupState.selectedGrades
          .fold<int>(0, (sum, grade) => sum + grade.sections.length);

      int totalSubjects = 0;
      int completedGradeSections = 0;
      int incompleteGradeSections = 0;

      for (final grade in setupState.selectedGrades) {
        final gradeReport = <String, dynamic>{};
        gradeReport['gradeNumber'] = grade.gradeNumber;
        gradeReport['sectionCount'] = grade.sections.length;

        final sectionReports = <Map<String, dynamic>>[];
        for (final section in grade.sections) {
          final sectionReport = <String, dynamic>{};
          sectionReport['sectionName'] = section.sectionName;
          sectionReport['subjectCount'] = section.subjects.length;
          sectionReport['isComplete'] = section.subjects.isNotEmpty;

          if (section.subjects.isNotEmpty) {
            completedGradeSections++;
            totalSubjects += section.subjects.length;
          } else {
            incompleteGradeSections++;
          }

          sectionReports.add(sectionReport);
        }

        gradeReport['sections'] = sectionReports;
        gradeReports.add(gradeReport);
      }

      report['grades'] = gradeReports;
      report['totalSubjects'] = totalSubjects;
      report['completedGradeSections'] = completedGradeSections;
      report['incompleteGradeSections'] = incompleteGradeSections;
      report['isFullyConfigured'] = incompleteGradeSections == 0;

      return Right(report);
    } catch (e) {
      return Left(ValidationFailure('Error generating validation report: $e'));
    }
  }
}
