import 'package:csv/csv.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/grade_section.dart';
import '../../../catalog/domain/entities/grade_subject.dart';
import '../../../catalog/domain/entities/subject_entity.dart';

/// Service to generate reports in various formats
class ReportGeneratorService {
  /// Generate Academic Structure Report as CSV
  /// Returns a compact, single A4 page printable CSV (landscape orientation recommended)
  static String generateAcademicStructureCSV({
    required List<GradeEntity> grades,
    required Map<String, List<GradeSection>> sectionsPerGrade,
    required Map<String, List<GradeSubject>> subjectsPerSection,
    required Map<String, SubjectEntity> subjectsMap, // subjectId -> SubjectEntity
  }) {
    // Prepare data for CSV
    final List<List<dynamic>> rows = [];

    // Add compact report header
    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year}';

    rows.add(['ACADEMIC STRUCTURE REPORT']);
    rows.add(['Generated:', formattedDate]);
    rows.add([]);

    // Sort grades by grade number
    final sortedGrades = [...grades]..sort((a, b) => a.gradeNumber.compareTo(b.gradeNumber));

    // Track statistics
    int totalSections = 0;
    int totalSubjectAssignments = 0;

    // Create a compact table format: Grade | Section A | Section B | Section C | etc.
    // First, collect all unique section names across all grades
    final allSectionNames = <String>{};
    final sectionsByGrade = <String, List<String>>{};

    for (final grade in sortedGrades) {
      final sections = sectionsPerGrade[grade.id] ?? [];
      final sectionNames = sections
          .map((s) => s.sectionName)
          .toList()
          ..sort();
      sectionsByGrade[grade.id] = sectionNames;
      allSectionNames.addAll(sectionNames);
    }

    // Add column headers: Grade | A | B | C | D | etc.
    final headers = ['Grade'];
    headers.addAll(allSectionNames.toList()..sort());
    rows.add(headers);

    // Add data rows - one row per grade showing subject counts for each section
    for (final grade in sortedGrades) {
      final row = ['Grade ${grade.gradeNumber}'];
      final sections = sectionsPerGrade[grade.id] ?? [];

      for (final sectionName in headers.skip(1)) {
        final section = sections.firstWhere(
          (s) => s.sectionName == sectionName,
          orElse: () => GradeSection(
            id: '',
            tenantId: '',
            gradeId: grade.id,
            sectionName: sectionName,
            displayOrder: 0,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (section.id.isEmpty) {
          // Section doesn't exist for this grade
          row.add('-');
        } else {
          totalSections++;
          final subjects = subjectsPerSection[section.id] ?? [];

          if (subjects.isEmpty) {
            row.add('0');
          } else {
            totalSubjectAssignments += subjects.length;

            // Build compact subject list using abbreviations
            final subjectNames = subjects
                .map((subject) {
                  final subjectEntity = subjectsMap[subject.subjectId];
                  final name = subjectEntity?.name ?? 'Unknown';
                  // Abbreviate to first 3 letters
                  return name.substring(0, (name.length < 3 ? name.length : 3)).toUpperCase();
                })
                .toList()
                ..sort();

            row.add('${subjects.length} (${subjectNames.join(',')})');
          }
        }
      }

      rows.add(row);
    }

    // Add summary statistics at bottom
    rows.add([]);
    rows.add(['SUMMARY']);
    rows.add(['Total Grades:', sortedGrades.length.toString()]);
    rows.add(['Total Sections:', totalSections.toString()]);
    rows.add(['Total Assignments:', totalSubjectAssignments.toString()]);

    if (totalSections > 0) {
      final avgSubjectsPerSection = totalSubjectAssignments / totalSections;
      rows.add(['Average per Section:', avgSubjectsPerSection.toStringAsFixed(1)]);
    }

    // Convert to CSV with proper escaping
    final csv = const ListToCsvConverter().convert(rows);
    return csv;
  }

  /// Generate filename for academic structure report
  static String getAcademicStructureReportFilename() {
    final now = DateTime.now();
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
    return 'academic_structure_$timestamp.csv';
  }
}
