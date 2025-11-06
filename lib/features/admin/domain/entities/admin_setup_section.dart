import 'package:equatable/equatable.dart';

/// Represents a section with its assigned subjects during admin setup
/// Example: Grade 5 Section A has [Math, Science, English]
class AdminSetupSection extends Equatable {
  final String sectionName; // 'A', 'B', 'C', etc.
  final List<String> subjects; // ['Math', 'Science', 'English']

  const AdminSetupSection({
    required this.sectionName,
    required this.subjects,
  });

  /// Add a subject to this section
  AdminSetupSection addSubject(String subject) {
    if (subjects.contains(subject)) return this;
    return AdminSetupSection(
      sectionName: sectionName,
      subjects: [...subjects, subject],
    );
  }

  /// Remove a subject from this section
  AdminSetupSection removeSubject(String subject) {
    return AdminSetupSection(
      sectionName: sectionName,
      subjects: subjects.where((s) => s != subject).toList(),
    );
  }

  /// Replace all subjects in this section
  AdminSetupSection updateSubjects(List<String> newSubjects) {
    return AdminSetupSection(
      sectionName: sectionName,
      subjects: newSubjects,
    );
  }

  @override
  List<Object?> get props => [sectionName, subjects];

  @override
  String toString() => 'AdminSetupSection($sectionName: $subjects)';
}
