import 'package:equatable/equatable.dart';

/// Represents a single class (grade + section) that a teacher teaches
///
/// Example: Grade 5, Section A
/// Used for displaying the Classes Card Section in teacher home page
class TeacherClass extends Equatable {
  final String gradeId;
  final int gradeNumber;
  final String sectionName;
  final List<String> subjectNames; // List of subjects taught in this class

  const TeacherClass({
    required this.gradeId,
    required this.gradeNumber,
    required this.sectionName,
    required this.subjectNames,
  });

  /// Display name: "Grade 5-A"
  String get displayName => 'Grade $gradeNumber-$sectionName';

  /// Color based on grade number for visual differentiation
  /// Returns a seed value for gradient colors
  int get colorSeed => gradeNumber * 7; // Ensures consistent colors per grade

  @override
  List<Object?> get props => [gradeId, gradeNumber, sectionName, subjectNames];

  @override
  String toString() => 'TeacherClass(grade: $gradeNumber, section: $sectionName)';
}
