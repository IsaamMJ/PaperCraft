import 'package:equatable/equatable.dart';
import 'admin_setup_grade.dart';

/// Represents the complete admin setup state during the onboarding wizard
class AdminSetupState extends Equatable {
  final String tenantId;
  final List<AdminSetupGrade> selectedGrades; // Grades selected in step 1
  final Map<int, List<String>> sectionsPerGrade; // Grade number → sections
  final Map<int, List<String>> subjectsPerGrade; // Grade number → subjects
  final int currentStep; // 1, 2, 3, 4
  final bool isInitialized; // Whether setup is complete

  const AdminSetupState({
    required this.tenantId,
    this.selectedGrades = const [],
    this.sectionsPerGrade = const {},
    this.subjectsPerGrade = const {},
    this.currentStep = 1,
    this.isInitialized = false,
  });

  /// Add a grade to the setup
  AdminSetupState addGrade(AdminSetupGrade grade) {
    final grades = [...selectedGrades];
    if (!grades.any((g) => g.gradeNumber == grade.gradeNumber)) {
      grades.add(grade);
      grades.sort((a, b) => a.gradeNumber.compareTo(b.gradeNumber));
    }
    return copyWith(selectedGrades: grades);
  }

  /// Remove a grade from the setup
  AdminSetupState removeGrade(int gradeNumber) {
    final newGrades = selectedGrades.where((g) => g.gradeNumber != gradeNumber).toList();
    final newSections = Map<int, List<String>>.from(sectionsPerGrade);
    final newSubjects = Map<int, List<String>>.from(subjectsPerGrade);

    newSections.remove(gradeNumber);
    newSubjects.remove(gradeNumber);

    return copyWith(
      selectedGrades: newGrades,
      sectionsPerGrade: newSections,
      subjectsPerGrade: newSubjects,
    );
  }

  /// Update sections for a specific grade
  AdminSetupState updateSectionsForGrade(int gradeNumber, List<String> sections) {
    final newSections = Map<int, List<String>>.from(sectionsPerGrade);
    newSections[gradeNumber] = sections;
    return copyWith(sectionsPerGrade: newSections);
  }

  /// Update subjects for a specific grade
  AdminSetupState updateSubjectsForGrade(int gradeNumber, List<String> subjects) {
    final newSubjects = Map<int, List<String>>.from(subjectsPerGrade);
    newSubjects[gradeNumber] = subjects;
    return copyWith(subjectsPerGrade: newSubjects);
  }

  /// Move to next step
  AdminSetupState nextStep() {
    return copyWith(currentStep: (currentStep + 1).clamp(1, 4));
  }

  /// Move to previous step
  AdminSetupState previousStep() {
    return copyWith(currentStep: (currentStep - 1).clamp(1, 4));
  }

  /// Get sections for a specific grade
  List<String> getSectionsForGrade(int gradeNumber) {
    return sectionsPerGrade[gradeNumber] ?? [];
  }

  /// Get subjects for a specific grade
  List<String> getSubjectsForGrade(int gradeNumber) {
    return subjectsPerGrade[gradeNumber] ?? [];
  }

  /// Validate current step
  bool validateCurrentStep() {
    switch (currentStep) {
      case 1:
        // At least 1 grade selected
        return selectedGrades.isNotEmpty;
      case 2:
        // All selected grades must have at least 1 section
        return selectedGrades.every((grade) =>
            (sectionsPerGrade[grade.gradeNumber]?.isNotEmpty ?? false));
      case 3:
        // All selected grades must have at least 1 subject
        return selectedGrades.every((grade) =>
            (subjectsPerGrade[grade.gradeNumber]?.isNotEmpty ?? false));
      case 4:
        // Review step - always valid
        return true;
      default:
        return false;
    }
  }

  /// Copy with modified fields
  AdminSetupState copyWith({
    String? tenantId,
    List<AdminSetupGrade>? selectedGrades,
    Map<int, List<String>>? sectionsPerGrade,
    Map<int, List<String>>? subjectsPerGrade,
    int? currentStep,
    bool? isInitialized,
  }) {
    return AdminSetupState(
      tenantId: tenantId ?? this.tenantId,
      selectedGrades: selectedGrades ?? this.selectedGrades,
      sectionsPerGrade: sectionsPerGrade ?? this.sectionsPerGrade,
      subjectsPerGrade: subjectsPerGrade ?? this.subjectsPerGrade,
      currentStep: currentStep ?? this.currentStep,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  @override
  List<Object?> get props => [
    tenantId,
    selectedGrades,
    sectionsPerGrade,
    subjectsPerGrade,
    currentStep,
    isInitialized,
  ];

  @override
  String toString() => 'AdminSetupState(grades: ${selectedGrades.length}, step: $currentStep)';
}
