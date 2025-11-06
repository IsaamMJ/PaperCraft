import 'package:equatable/equatable.dart';

/// Base event for AdminSetupBloc
abstract class AdminSetupEvent extends Equatable {
  const AdminSetupEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize admin setup wizard with tenant info
class InitializeAdminSetupEvent extends AdminSetupEvent {
  final String tenantId;

  const InitializeAdminSetupEvent({required this.tenantId});

  @override
  List<Object?> get props => [tenantId];
}

/// Load available grades for the tenant
class LoadAvailableGradesEvent extends AdminSetupEvent {
  final String tenantId;

  const LoadAvailableGradesEvent({required this.tenantId});

  @override
  List<Object?> get props => [tenantId];
}

/// Add a grade to the setup
class AddGradeEvent extends AdminSetupEvent {
  final int gradeNumber;
  final String gradeId; // Database ID of the grade (optional, for teacher onboarding)

  const AddGradeEvent({
    required this.gradeNumber,
    this.gradeId = '', // Default empty for admin setup (grades don't exist yet)
  });

  @override
  List<Object?> get props => [gradeNumber, gradeId];
}

/// Remove a grade from the setup
class RemoveGradeEvent extends AdminSetupEvent {
  final int gradeNumber;

  const RemoveGradeEvent({required this.gradeNumber});

  @override
  List<Object?> get props => [gradeNumber];
}

/// Update sections for a grade
class UpdateSectionsEvent extends AdminSetupEvent {
  final int gradeNumber;
  final List<String> sections;

  const UpdateSectionsEvent({
    required this.gradeNumber,
    required this.sections,
  });

  @override
  List<Object?> get props => [gradeNumber, sections];
}

/// Add a section to a grade
class AddSectionEvent extends AdminSetupEvent {
  final int gradeNumber;
  final String sectionName;

  const AddSectionEvent({
    required this.gradeNumber,
    required this.sectionName,
  });

  @override
  List<Object?> get props => [gradeNumber, sectionName];
}

/// Remove a section from a grade
class RemoveSectionEvent extends AdminSetupEvent {
  final int gradeNumber;
  final String sectionName;

  const RemoveSectionEvent({
    required this.gradeNumber,
    required this.sectionName,
  });

  @override
  List<Object?> get props => [gradeNumber, sectionName];
}

/// Load subject suggestions for a grade
class LoadSubjectSuggestionsEvent extends AdminSetupEvent {
  final int gradeNumber;

  const LoadSubjectSuggestionsEvent({required this.gradeNumber});

  @override
  List<Object?> get props => [gradeNumber];
}

/// Update subjects for a grade
class UpdateSubjectsEvent extends AdminSetupEvent {
  final int gradeNumber;
  final List<String> subjects;

  const UpdateSubjectsEvent({
    required this.gradeNumber,
    required this.subjects,
  });

  @override
  List<Object?> get props => [gradeNumber, subjects];
}

/// Add a subject to a grade
class AddSubjectEvent extends AdminSetupEvent {
  final int gradeNumber;
  final String subjectName;

  const AddSubjectEvent({
    required this.gradeNumber,
    required this.subjectName,
  });

  @override
  List<Object?> get props => [gradeNumber, subjectName];
}

/// Remove a subject from a grade
class RemoveSubjectEvent extends AdminSetupEvent {
  final int gradeNumber;
  final String subjectName;

  const RemoveSubjectEvent({
    required this.gradeNumber,
    required this.subjectName,
  });

  @override
  List<Object?> get props => [gradeNumber, subjectName];
}

/// Add a subject to a specific grade+section (per-section subject selection)
class AddSubjectToGradeSectionEvent extends AdminSetupEvent {
  final int gradeNumber;
  final String section;
  final String subjectName;

  const AddSubjectToGradeSectionEvent({
    required this.gradeNumber,
    required this.section,
    required this.subjectName,
  });

  @override
  List<Object?> get props => [gradeNumber, section, subjectName];
}

/// Remove a subject from a specific grade+section (per-section subject selection)
class RemoveSubjectFromGradeSectionEvent extends AdminSetupEvent {
  final int gradeNumber;
  final String section;
  final String subjectName;

  const RemoveSubjectFromGradeSectionEvent({
    required this.gradeNumber,
    required this.section,
    required this.subjectName,
  });

  @override
  List<Object?> get props => [gradeNumber, section, subjectName];
}

/// Move to next step in the wizard
class NextStepEvent extends AdminSetupEvent {
  const NextStepEvent();
}

/// Move to previous step in the wizard
class PreviousStepEvent extends AdminSetupEvent {
  const PreviousStepEvent();
}

/// Validate current step and show errors if any
class ValidateStepEvent extends AdminSetupEvent {
  const ValidateStepEvent();
}

/// Update school name and address
class UpdateSchoolDetailsEvent extends AdminSetupEvent {
  final String schoolName;
  final String schoolAddress;

  const UpdateSchoolDetailsEvent({
    required this.schoolName,
    required this.schoolAddress,
  });

  @override
  List<Object?> get props => [schoolName, schoolAddress];
}

/// Save the complete admin setup with tenant details
class SaveAdminSetupEvent extends AdminSetupEvent {
  const SaveAdminSetupEvent();

  @override
  List<Object?> get props => [];
}
