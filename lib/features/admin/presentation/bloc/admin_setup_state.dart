import 'package:equatable/equatable.dart';
import '../../domain/entities/admin_setup_state.dart' as domain;

/// Base state for AdminSetupBloc
abstract class AdminSetupUIState extends Equatable {
  const AdminSetupUIState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class AdminSetupInitial extends AdminSetupUIState {
  const AdminSetupInitial();
}

/// Loading available grades
class LoadingGrades extends AdminSetupUIState {
  const LoadingGrades();
}

/// Grades loaded successfully
class GradesLoaded extends AdminSetupUIState {
  final List<int> availableGrades;

  const GradesLoaded({required this.availableGrades});

  @override
  List<Object?> get props => [availableGrades];
}

/// Loading subject suggestions
class LoadingSubjectSuggestions extends AdminSetupUIState {
  final int gradeNumber;

  const LoadingSubjectSuggestions({required this.gradeNumber});

  @override
  List<Object?> get props => [gradeNumber];
}

/// Subject suggestions loaded
class SubjectSuggestionsLoaded extends AdminSetupUIState {
  final int gradeNumber;
  final List<String> suggestions;

  const SubjectSuggestionsLoaded({
    required this.gradeNumber,
    required this.suggestions,
  });

  @override
  List<Object?> get props => [gradeNumber, suggestions];
}

/// Setup state updated
class AdminSetupUpdated extends AdminSetupUIState {
  final domain.AdminSetupState setupState;

  const AdminSetupUpdated({required this.setupState});

  @override
  List<Object?> get props => [setupState];
}

/// Step validation failed
class StepValidationFailed extends AdminSetupUIState {
  final String errorMessage;

  const StepValidationFailed({required this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}

/// Saving admin setup
class SavingAdminSetup extends AdminSetupUIState {
  const SavingAdminSetup();
}

/// Admin setup saved successfully
class AdminSetupSaved extends AdminSetupUIState {
  const AdminSetupSaved();
}

/// Error occurred during setup
class AdminSetupError extends AdminSetupUIState {
  final String errorMessage;

  const AdminSetupError({required this.errorMessage});

  @override
  List<Object?> get props => [errorMessage];
}
