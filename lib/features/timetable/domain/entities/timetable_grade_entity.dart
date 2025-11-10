import 'package:equatable/equatable.dart';

/// Represents a grade with its available sections for the timetable
class TimetableGradeEntity extends Equatable {
  final String gradeId;
  final int gradeNumber;
  final List<String> sections; // ['A', 'B', 'C', etc.]

  const TimetableGradeEntity({
    required this.gradeId,
    required this.gradeNumber,
    required this.sections,
  });

  @override
  List<Object?> get props => [gradeId, gradeNumber, sections];

  @override
  String toString() =>
      'TimetableGradeEntity(grade: $gradeNumber, sections: ${sections.join(", ")})';
}

/// Data structure returned from GetTimetableGradesAndSections use case
class TimetableGradesAndSectionsData extends Equatable {
  final List<TimetableGradeEntity> grades;
  final Map<int, List<String>> sectionsByGradeNumber; // gradeNumber -> [sections]

  const TimetableGradesAndSectionsData({
    required this.grades,
    required this.sectionsByGradeNumber,
  });

  @override
  List<Object?> get props => [grades, sectionsByGradeNumber];
}
