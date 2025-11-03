import 'package:equatable/equatable.dart';

/// Represents a grade with its sections during admin setup
class AdminSetupGrade extends Equatable {
  final String gradeId;
  final int gradeNumber;
  final List<String> sections; // ['A', 'B', 'C']
  final List<String> subjects; // ['Math', 'Science', etc]

  const AdminSetupGrade({
    required this.gradeId,
    required this.gradeNumber,
    required this.sections,
    required this.subjects,
  });

  /// Add a section to this grade
  AdminSetupGrade addSection(String section) {
    if (sections.contains(section)) return this;
    return AdminSetupGrade(
      gradeId: gradeId,
      gradeNumber: gradeNumber,
      sections: [...sections, section],
      subjects: subjects,
    );
  }

  /// Remove a section from this grade
  AdminSetupGrade removeSection(String section) {
    return AdminSetupGrade(
      gradeId: gradeId,
      gradeNumber: gradeNumber,
      sections: sections.where((s) => s != section).toList(),
      subjects: subjects,
    );
  }

  /// Add a subject to this grade
  AdminSetupGrade addSubject(String subject) {
    if (subjects.contains(subject)) return this;
    return AdminSetupGrade(
      gradeId: gradeId,
      gradeNumber: gradeNumber,
      sections: sections,
      subjects: [...subjects, subject],
    );
  }

  /// Remove a subject from this grade
  AdminSetupGrade removeSubject(String subject) {
    return AdminSetupGrade(
      gradeId: gradeId,
      gradeNumber: gradeNumber,
      sections: sections,
      subjects: subjects.where((s) => s != subject).toList(),
    );
  }

  @override
  List<Object?> get props => [gradeId, gradeNumber, sections, subjects];

  @override
  String toString() => 'AdminSetupGrade(grade: $gradeNumber, sections: $sections, subjects: $subjects)';
}
