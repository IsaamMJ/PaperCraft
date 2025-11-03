import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/admin_setup_grade.dart';
import '../../domain/entities/admin_setup_state.dart' as domain;
import '../../domain/usecases/get_available_grades_usecase.dart';
import '../../domain/usecases/get_subject_suggestions_usecase.dart';
import '../../domain/usecases/save_admin_setup_usecase.dart';
import 'admin_setup_event.dart';
import 'admin_setup_state.dart';

/// BLoC for managing admin setup wizard
class AdminSetupBloc extends Bloc<AdminSetupEvent, AdminSetupUIState> {
  final GetAvailableGradesUseCase getAvailableGradesUseCase;
  final GetSubjectSuggestionsUseCase getSubjectSuggestionsUseCase;
  final SaveAdminSetupUseCase saveAdminSetupUseCase;

  // Current setup state maintained by the BLoC
  domain.AdminSetupState _setupState = const domain.AdminSetupState(
    tenantId: '',
  );

  AdminSetupBloc({
    required this.getAvailableGradesUseCase,
    required this.getSubjectSuggestionsUseCase,
    required this.saveAdminSetupUseCase,
  }) : super(const AdminSetupInitial()) {
    on<InitializeAdminSetupEvent>(_onInitialize);
    on<LoadAvailableGradesEvent>(_onLoadAvailableGrades);
    on<AddGradeEvent>(_onAddGrade);
    on<RemoveGradeEvent>(_onRemoveGrade);
    on<AddSectionEvent>(_onAddSection);
    on<RemoveSectionEvent>(_onRemoveSection);
    on<UpdateSectionsEvent>(_onUpdateSections);
    on<LoadSubjectSuggestionsEvent>(_onLoadSubjectSuggestions);
    on<AddSubjectEvent>(_onAddSubject);
    on<RemoveSubjectEvent>(_onRemoveSubject);
    on<UpdateSubjectsEvent>(_onUpdateSubjects);
    on<UpdateSchoolDetailsEvent>(_onUpdateSchoolDetails);
    on<NextStepEvent>(_onNextStep);
    on<PreviousStepEvent>(_onPreviousStep);
    on<ValidateStepEvent>(_onValidateStep);
    on<SaveAdminSetupEvent>(_onSaveAdminSetup);
  }

  /// Initialize the setup wizard
  Future<void> _onInitialize(
    InitializeAdminSetupEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    _setupState = domain.AdminSetupState(tenantId: event.tenantId);
    emit(AdminSetupUpdated(setupState: _setupState));

    // Load available grades
    add(LoadAvailableGradesEvent(tenantId: event.tenantId));
  }

  /// Load available grades for the tenant
  Future<void> _onLoadAvailableGrades(
    LoadAvailableGradesEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    emit(const LoadingGrades());

    final result = await getAvailableGradesUseCase(tenantId: event.tenantId);

    result.fold(
      (failure) => emit(AdminSetupError(errorMessage: failure.message)),
      (grades) {
        // Create AdminSetupGrade entities for each grade
        final setupGrades = grades.map((gradeNum) {
          return AdminSetupGrade(
            gradeId: '', // Will be assigned by DB
            gradeNumber: gradeNum,
            sections: [],
            subjects: [],
          );
        }).toList();

        emit(GradesLoaded(availableGrades: grades));
      },
    );
  }

  /// Add a grade to the setup
  Future<void> _onAddGrade(
    AddGradeEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    final newGrade = AdminSetupGrade(
      gradeId: '', // Will be assigned by DB
      gradeNumber: event.gradeNumber,
      sections: [],
      subjects: [],
    );

    _setupState = _setupState.addGrade(newGrade);
    emit(AdminSetupUpdated(setupState: _setupState));
  }

  /// Remove a grade from the setup
  Future<void> _onRemoveGrade(
    RemoveGradeEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    _setupState = _setupState.removeGrade(event.gradeNumber);
    emit(AdminSetupUpdated(setupState: _setupState));
  }

  /// Add a section to a grade
  Future<void> _onAddSection(
    AddSectionEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    final currentSections = _setupState.getSectionsForGrade(event.gradeNumber);
    if (!currentSections.contains(event.sectionName)) {
      final newSections = [...currentSections, event.sectionName];
      _setupState = _setupState.updateSectionsForGrade(
        event.gradeNumber,
        newSections,
      );
      emit(AdminSetupUpdated(setupState: _setupState));
    }
  }

  /// Remove a section from a grade
  Future<void> _onRemoveSection(
    RemoveSectionEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    final currentSections = _setupState.getSectionsForGrade(event.gradeNumber);
    final newSections = currentSections
        .where((s) => s != event.sectionName)
        .toList();

    _setupState = _setupState.updateSectionsForGrade(
      event.gradeNumber,
      newSections,
    );
    emit(AdminSetupUpdated(setupState: _setupState));
  }

  /// Update all sections for a grade
  Future<void> _onUpdateSections(
    UpdateSectionsEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    _setupState = _setupState.updateSectionsForGrade(
      event.gradeNumber,
      event.sections,
    );
    emit(AdminSetupUpdated(setupState: _setupState));
  }

  /// Load subject suggestions for a grade
  Future<void> _onLoadSubjectSuggestions(
    LoadSubjectSuggestionsEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    emit(LoadingSubjectSuggestions(gradeNumber: event.gradeNumber));

    final result = await getSubjectSuggestionsUseCase(
      gradeNumber: event.gradeNumber,
    );

    result.fold(
      (failure) => emit(AdminSetupError(errorMessage: failure.message)),
      (suggestions) {
        emit(SubjectSuggestionsLoaded(
          gradeNumber: event.gradeNumber,
          suggestions: suggestions,
        ));
      },
    );
  }

  /// Add a subject to a grade
  Future<void> _onAddSubject(
    AddSubjectEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    final currentSubjects = _setupState.getSubjectsForGrade(event.gradeNumber);
    if (!currentSubjects.contains(event.subjectName)) {
      final newSubjects = [...currentSubjects, event.subjectName];
      _setupState = _setupState.updateSubjectsForGrade(
        event.gradeNumber,
        newSubjects,
      );
      emit(AdminSetupUpdated(setupState: _setupState));
    }
  }

  /// Remove a subject from a grade
  Future<void> _onRemoveSubject(
    RemoveSubjectEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    final currentSubjects = _setupState.getSubjectsForGrade(event.gradeNumber);
    final newSubjects = currentSubjects
        .where((s) => s != event.subjectName)
        .toList();

    _setupState = _setupState.updateSubjectsForGrade(
      event.gradeNumber,
      newSubjects,
    );
    emit(AdminSetupUpdated(setupState: _setupState));
  }

  /// Update all subjects for a grade
  Future<void> _onUpdateSubjects(
    UpdateSubjectsEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    _setupState = _setupState.updateSubjectsForGrade(
      event.gradeNumber,
      event.subjects,
    );
    emit(AdminSetupUpdated(setupState: _setupState));
  }

  /// Update school name and address
  Future<void> _onUpdateSchoolDetails(
    UpdateSchoolDetailsEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    _setupState = _setupState.copyWith(
      schoolName: event.schoolName,
      schoolAddress: event.schoolAddress,
    );
    emit(AdminSetupUpdated(setupState: _setupState));
  }

  /// Move to next step
  Future<void> _onNextStep(
    NextStepEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    if (_setupState.validateCurrentStep()) {
      _setupState = _setupState.nextStep();
      emit(AdminSetupUpdated(setupState: _setupState));
    } else {
      emit(const StepValidationFailed(
        errorMessage: 'Please complete all required fields',
      ));
    }
  }

  /// Move to previous step
  Future<void> _onPreviousStep(
    PreviousStepEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    _setupState = _setupState.previousStep();
    emit(AdminSetupUpdated(setupState: _setupState));
  }

  /// Validate current step
  Future<void> _onValidateStep(
    ValidateStepEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    if (!_setupState.validateCurrentStep()) {
      final error = _getValidationError();
      emit(StepValidationFailed(errorMessage: error));
    }
  }

  /// Save the complete admin setup
  Future<void> _onSaveAdminSetup(
    SaveAdminSetupEvent event,
    Emitter<AdminSetupUIState> emit,
  ) async {
    if (!_setupState.validateCurrentStep()) {
      emit(const StepValidationFailed(
        errorMessage: 'Please complete all required fields',
      ));
      return;
    }

    emit(const SavingAdminSetup());

    final result = await saveAdminSetupUseCase(
      setupState: _setupState,
      tenantName: _setupState.schoolName.isNotEmpty ? _setupState.schoolName : null,
      tenantAddress: _setupState.schoolAddress.isNotEmpty ? _setupState.schoolAddress : null,
    );

    result.fold(
      (failure) => emit(AdminSetupError(errorMessage: failure.message)),
      (_) {
        _setupState = _setupState.copyWith(isInitialized: true);
        emit(const AdminSetupSaved());
      },
    );
  }

  /// Get validation error message for current step
  String _getValidationError() {
    switch (_setupState.currentStep) {
      case 1:
        return 'Please select at least one grade';
      case 2:
        return 'Please add sections for all selected grades';
      case 3:
        return 'Please select subjects for all grades';
      default:
        return 'Invalid step';
    }
  }

  /// Getter for current setup state
  domain.AdminSetupState get setupState => _setupState;
}
