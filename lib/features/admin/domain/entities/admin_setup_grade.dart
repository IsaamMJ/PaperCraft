import 'package:equatable/equatable.dart';
import 'admin_setup_section.dart';

/// Represents a grade with its sections and subjects during admin setup
/// Each section can have different subjects
class AdminSetupGrade extends Equatable {
  final String gradeId;
  final int gradeNumber;
  final List<AdminSetupSection> sections; // [Section A with subjects, Section B with subjects, etc]

  const AdminSetupGrade({
    required this.gradeId,
    required this.gradeNumber,
    required this.sections,
  });

  /// Get section by name
  AdminSetupSection? getSectionByName(String sectionName) {
    try {
      return sections.firstWhere((s) => s.sectionName == sectionName);
    } catch (e) {
      return null;
    }
  }

  /// Add a new section with empty subjects
  AdminSetupGrade addSection(String sectionName) {
    if (getSectionByName(sectionName) != null) return this;
    return AdminSetupGrade(
      gradeId: gradeId,
      gradeNumber: gradeNumber,
      sections: [
        ...sections,
        AdminSetupSection(sectionName: sectionName, subjects: []),
      ],
    );
  }

  /// Remove a section from this grade
  AdminSetupGrade removeSection(String sectionName) {
    return AdminSetupGrade(
      gradeId: gradeId,
      gradeNumber: gradeNumber,
      sections: sections.where((s) => s.sectionName != sectionName).toList(),
    );
  }

  /// Add a subject to a specific section
  AdminSetupGrade addSubjectToSection(String sectionName, String subject) {
    final section = getSectionByName(sectionName);
    if (section == null) return this;

    final updatedSections = sections.map((s) {
      if (s.sectionName == sectionName) {
        return s.addSubject(subject);
      }
      return s;
    }).toList();

    return AdminSetupGrade(
      gradeId: gradeId,
      gradeNumber: gradeNumber,
      sections: updatedSections,
    );
  }

  /// Remove a subject from a specific section
  AdminSetupGrade removeSubjectFromSection(String sectionName, String subject) {
    final section = getSectionByName(sectionName);
    if (section == null) return this;

    final updatedSections = sections.map((s) {
      if (s.sectionName == sectionName) {
        return s.removeSubject(subject);
      }
      return s;
    }).toList();

    return AdminSetupGrade(
      gradeId: gradeId,
      gradeNumber: gradeNumber,
      sections: updatedSections,
    );
  }

  /// Update subjects for a specific section
  AdminSetupGrade updateSectionSubjects(
    String sectionName,
    List<String> subjects,
  ) {
    final section = getSectionByName(sectionName);
    if (section == null) return this;

    final updatedSections = sections.map((s) {
      if (s.sectionName == sectionName) {
        return s.updateSubjects(subjects);
      }
      return s;
    }).toList();

    return AdminSetupGrade(
      gradeId: gradeId,
      gradeNumber: gradeNumber,
      sections: updatedSections,
    );
  }

  /// Get all subjects across all sections
  List<String> getAllSubjects() {
    final allSubjects = <String>{};
    for (final section in sections) {
      allSubjects.addAll(section.subjects);
    }
    return allSubjects.toList();
  }

  @override
  List<Object?> get props => [gradeId, gradeNumber, sections];

  @override
  String toString() => 'AdminSetupGrade(grade: $gradeNumber, sections: ${sections.length})';
}
