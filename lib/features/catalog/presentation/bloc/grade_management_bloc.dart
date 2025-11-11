import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/grade_entity.dart';
import '../../domain/entities/grade_section.dart';
import '../../domain/entities/grade_subject.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/repositories/grade_section_repository.dart';
import '../../domain/repositories/grade_repository.dart';
import '../../domain/repositories/grade_subject_repository.dart';
import '../../domain/repositories/subject_repository.dart';
import '../../../authentication/domain/services/user_state_service.dart';

// =============== EVENTS ===============
abstract class GradeManagementEvent extends Equatable {
  const GradeManagementEvent();

  @override
  List<Object?> get props => [];
}

class LoadGradesWithSections extends GradeManagementEvent {
  const LoadGradesWithSections();
}

class AddGradeEvent extends GradeManagementEvent {
  final int gradeNumber;

  const AddGradeEvent(this.gradeNumber);

  @override
  List<Object?> get props => [gradeNumber];
}

class DeleteGradeEvent extends GradeManagementEvent {
  final String gradeId;
  final int gradeNumber;

  const DeleteGradeEvent(this.gradeId, this.gradeNumber);

  @override
  List<Object?> get props => [gradeId, gradeNumber];
}

class AddSectionEvent extends GradeManagementEvent {
  final String gradeId;
  final int gradeNumber;
  final String sectionName;

  const AddSectionEvent(this.gradeId, this.gradeNumber, this.sectionName);

  @override
  List<Object?> get props => [gradeId, gradeNumber, sectionName];
}

class RemoveSectionEvent extends GradeManagementEvent {
  final String gradeId;
  final int gradeNumber;
  final String sectionId;

  const RemoveSectionEvent(this.gradeId, this.gradeNumber, this.sectionId);

  @override
  List<Object?> get props => [gradeId, gradeNumber, sectionId];
}

class ToggleExpandGradeEvent extends GradeManagementEvent {
  final String? gradeId;

  const ToggleExpandGradeEvent(this.gradeId);

  @override
  List<Object?> get props => [gradeId];
}

class ApplyQuickPatternEvent extends GradeManagementEvent {
  final String gradeId;
  final int gradeNumber;
  final List<String> sections;

  const ApplyQuickPatternEvent(this.gradeId, this.gradeNumber, this.sections);

  @override
  List<Object?> get props => [gradeId, gradeNumber, sections];
}

// =============== SUBJECT EVENTS ===============
class LoadSubjectsForSectionEvent extends GradeManagementEvent {
  final String gradeId;
  final String sectionId; // This is now the section ID (UUID)
  final String sectionName; // Added: the actual section name (A, B, C, etc.)

  const LoadSubjectsForSectionEvent(
    this.gradeId,
    this.sectionId, {
    required this.sectionName,
  });

  @override
  List<Object?> get props => [gradeId, sectionId, sectionName];
}

class SelectSubjectSectionEvent extends GradeManagementEvent {
  final String? sectionId; // null to deselect

  const SelectSubjectSectionEvent(this.sectionId);

  @override
  List<Object?> get props => [sectionId];
}

class AddSubjectToSectionEvent extends GradeManagementEvent {
  final String gradeId;
  final String sectionId;
  final String sectionName; // Section name (e.g., "A", "B") not UUID
  final String subjectId;

  const AddSubjectToSectionEvent(
    this.gradeId,
    this.sectionId,
    this.sectionName,
    this.subjectId,
  );

  @override
  List<Object?> get props => [gradeId, sectionId, sectionName, subjectId];
}

class RemoveSubjectFromSectionEvent extends GradeManagementEvent {
  final String gradeId;
  final String sectionId;
  final String gradeSubjectId;

  const RemoveSubjectFromSectionEvent(
    this.gradeId,
    this.sectionId,
    this.gradeSubjectId,
  );

  @override
  List<Object?> get props => [gradeId, sectionId, gradeSubjectId];
}

class ApplySubjectPatternEvent extends GradeManagementEvent {
  final String gradeId;
  final String sectionId;
  final List<String> subjectIds;

  const ApplySubjectPatternEvent(
    this.gradeId,
    this.sectionId,
    this.subjectIds,
  );

  @override
  List<Object?> get props => [gradeId, sectionId, subjectIds];
}

class LoadAvailableSubjectsForGradeEvent extends GradeManagementEvent {
  final int gradeNumber;

  const LoadAvailableSubjectsForGradeEvent(this.gradeNumber);

  @override
  List<Object?> get props => [gradeNumber];
}

// =============== STATES ===============
abstract class GradeManagementState extends Equatable {
  const GradeManagementState();

  @override
  List<Object?> get props => [];
}

class GradeManagementInitial extends GradeManagementState {
  const GradeManagementInitial();
}

class GradeManagementLoading extends GradeManagementState {
  const GradeManagementLoading();
}

class GradeManagementLoaded extends GradeManagementState {
  final List<GradeEntity> grades;
  final Map<String, List<GradeSection>> sectionsPerGrade; // gradeId → [GradeSection...]
  final Map<String, List<GradeSubject>> subjectsPerSection; // sectionId → [GradeSubject...]
  final Map<int, List<SubjectEntity>> availableSubjectsPerGrade; // gradeNumber → [SubjectEntity...]
  final String? expandedGradeId;
  final String? selectedSubjectSectionId; // For subjects tab
  final String tenantName;

  const GradeManagementLoaded({
    required this.grades,
    required this.sectionsPerGrade,
    this.subjectsPerSection = const {},
    this.availableSubjectsPerGrade = const {},
    this.expandedGradeId,
    this.selectedSubjectSectionId,
    required this.tenantName,
  });

  @override
  List<Object?> get props => [
    grades,
    sectionsPerGrade,
    subjectsPerSection,
    availableSubjectsPerGrade,
    expandedGradeId,
    selectedSubjectSectionId,
    tenantName,
  ];
}

class GradeManagementError extends GradeManagementState {
  final String message;

  const GradeManagementError(this.message);

  @override
  List<Object?> get props => [message];
}

// =============== BLOC ===============
class GradeManagementBloc extends Bloc<GradeManagementEvent, GradeManagementState> {
  final GradeRepository _gradeRepository;
  final GradeSectionRepository _sectionRepository;
  final GradeSubjectRepository _subjectRepository;
  final SubjectRepository _subjectCatalogRepository;
  final UserStateService _userStateService;

  // Cache for sections
  Map<String, List<GradeSection>> _sectionsCache = {};
  Map<String, List<GradeSubject>> _subjectsCache = {};
  Map<int, List<SubjectEntity>> _availableSubjectsCache = {};
  List<GradeEntity> _gradesCache = [];
  String? _expandedGradeId;
  String? _selectedSubjectSectionId;

  GradeManagementBloc({
    required GradeRepository gradeRepository,
    required GradeSectionRepository sectionRepository,
    required GradeSubjectRepository subjectRepository,
    required SubjectRepository subjectCatalogRepository,
    required UserStateService userStateService,
  })  : _gradeRepository = gradeRepository,
        _sectionRepository = sectionRepository,
        _subjectRepository = subjectRepository,
        _subjectCatalogRepository = subjectCatalogRepository,
        _userStateService = userStateService,
        super(const GradeManagementInitial()) {
    on<LoadGradesWithSections>(_onLoadGradesWithSections);
    on<AddGradeEvent>(_onAddGrade);
    on<DeleteGradeEvent>(_onDeleteGrade);
    on<AddSectionEvent>(_onAddSection);
    on<RemoveSectionEvent>(_onRemoveSection);
    on<ToggleExpandGradeEvent>(_onToggleExpand);
    on<ApplyQuickPatternEvent>(_onApplyQuickPattern);
    on<LoadSubjectsForSectionEvent>(_onLoadSubjectsForSection);
    on<SelectSubjectSectionEvent>(_onSelectSubjectSection);
    on<AddSubjectToSectionEvent>(_onAddSubjectToSection);
    on<RemoveSubjectFromSectionEvent>(_onRemoveSubjectFromSection);
    on<ApplySubjectPatternEvent>(_onApplySubjectPattern);
    on<LoadAvailableSubjectsForGradeEvent>(_onLoadAvailableSubjectsForGrade);
  }

  Future<void> _onLoadGradesWithSections(
    LoadGradesWithSections event,
    Emitter<GradeManagementState> emit,
  ) async {
    emit(const GradeManagementLoading());

    try {
      final tenantId = _userStateService.currentTenantId;
      if (tenantId == null) {
        emit(const GradeManagementError('Tenant not found'));
        return;
      }

      final gradesResult = await _gradeRepository.getGrades();

      final grades = gradesResult.fold(
        (failure) {
          return <GradeEntity>[];
        },
        (gradesList) => gradesList,
      );

      if (grades.isEmpty) {
        emit(GradeManagementLoaded(
          grades: [],
          sectionsPerGrade: {},
          tenantName: _getTenantName(),
        ));
        return;
      }


      _gradesCache = grades;
      _sectionsCache = {};

      // Load sections for each grade
      for (final grade in grades) {
        final sectionsResult = await _sectionRepository.getGradeSections(
          tenantId: tenantId,
          gradeId: grade.id,
          // Use activeOnly: true (default) - only show active sections in UI
        );

        final sections = sectionsResult.fold(
          (failure) {
            return <GradeSection>[];
          },
          (sectionsList) {
            return sectionsList;
          },
        );

        _sectionsCache[grade.id] = sections;
      }

      emit(GradeManagementLoaded(
        grades: grades,
        sectionsPerGrade: _sectionsCache,
        tenantName: _getTenantName(),
      ));
    } catch (e) {
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onAddGrade(
    AddGradeEvent event,
    Emitter<GradeManagementState> emit,
  ) async {

    try {
      final tenantId = _userStateService.currentTenantId ?? '';
      final gradeEntity = GradeEntity(
        id: '',
        tenantId: tenantId,
        gradeNumber: event.gradeNumber,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final result = await _gradeRepository.createGrade(gradeEntity);

      result.fold(
        (failure) {
          emit(GradeManagementError(failure.message));
        },
        (createdGrade) {
          _gradesCache.add(createdGrade);
          _sectionsCache[createdGrade.id] = [];
          _emitLoaded();
        },
      );
    } catch (e) {
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onDeleteGrade(
    DeleteGradeEvent event,
    Emitter<GradeManagementState> emit,
  ) async {

    try {
      final result = await _gradeRepository.deleteGrade(event.gradeId);

      result.fold(
        (failure) {
          emit(GradeManagementError(failure.message));
        },
        (_) {
          // Create NEW list to force Equatable to detect changes
          final updatedGrades = List<GradeEntity>.from(_gradesCache);
          updatedGrades.removeWhere((g) => g.id == event.gradeId);
          _gradesCache = updatedGrades;
          _sectionsCache.remove(event.gradeId);
          _expandedGradeId = null;
          _emitLoaded();
        },
      );
    } catch (e) {
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onAddSection(
    AddSectionEvent event,
    Emitter<GradeManagementState> emit,
  ) async {

    try {
      final tenantId = _userStateService.currentTenantId ?? '';
      final now = DateTime.now();

      // Check if section already exists in database before attempting to create
      final existingSectionsResult = await _sectionRepository.getGradeSections(
        tenantId: tenantId,
        gradeId: event.gradeId,
        activeOnly: false,  // Check all sections
      );

      final existingSectionNames = existingSectionsResult.fold(
        (failure) => <String>[],
        (sections) => sections.map((s) => s.sectionName).toSet(),
      );

      // If section already exists, check if it needs reactivation
      if (existingSectionNames.contains(event.sectionName)) {

        final existingSections = existingSectionsResult.fold(
          (failure) => <GradeSection>[],
          (sections) => sections,
        );

        // Find the section and check if it's inactive
        final existingSection = existingSections.firstWhere(
          (s) => s.sectionName == event.sectionName,
          orElse: () => GradeSection(
            id: '',
            tenantId: '',
            gradeId: event.gradeId,
            sectionName: event.sectionName,
            displayOrder: 0,
            isActive: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // If section is inactive, reactivate it
        if (!existingSection.isActive && existingSection.id.isNotEmpty) {
          final reactivated = GradeSection(
            id: existingSection.id,
            tenantId: existingSection.tenantId,
            gradeId: existingSection.gradeId,
            sectionName: existingSection.sectionName,
            displayOrder: existingSection.displayOrder,
            isActive: true,  // MUST be active
            createdAt: existingSection.createdAt,
            updatedAt: DateTime.now(),
          );

          // Update in database
          await _sectionRepository.updateGradeSection(reactivated);

          // Update cache with reactivated sections
          final updatedSections = existingSections.map((s) {
            if (s.sectionName == event.sectionName) {
              return reactivated;
            }
            return s;
          }).toList();
          _sectionsCache[event.gradeId] = updatedSections;
        } else {
          // Section is already active
          _sectionsCache[event.gradeId] = existingSections;
        }

        _emitLoaded();
        return;
      }

      final displayOrder = (_sectionsCache[event.gradeId]?.length ?? 0) + 1;

      final section = GradeSection(
        id: const Uuid().v4(), // Generate UUID
        tenantId: tenantId,
        gradeId: event.gradeId,
        sectionName: event.sectionName,
        displayOrder: displayOrder,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final result = await _sectionRepository.createGradeSection(section);

      result.fold(
        (failure) {
          emit(GradeManagementError('Failed to add section: ${failure.message}'));
        },
        (createdSection) {
          final currentSections = List<GradeSection>.from(_sectionsCache[event.gradeId] ?? []);
          currentSections.add(createdSection);
          _sectionsCache[event.gradeId] = currentSections;
          _emitLoaded();
        },
      );
    } catch (e) {
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onRemoveSection(
    RemoveSectionEvent event,
    Emitter<GradeManagementState> emit,
  ) async {

    try {
      final result = await _sectionRepository.deleteGradeSection(event.sectionId);

      result.fold(
        (failure) {
          emit(GradeManagementError(failure.message));
        },
        (_) {
          // Create NEW list to force Equatable to detect changes
          final currentSections = List<GradeSection>.from(_sectionsCache[event.gradeId] ?? []);
          currentSections.removeWhere((s) => s.id == event.sectionId);
          _sectionsCache[event.gradeId] = currentSections;
          _emitLoaded();
        },
      );
    } catch (e) {
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onToggleExpand(
    ToggleExpandGradeEvent event,
    Emitter<GradeManagementState> emit,
  ) async {

    if (_expandedGradeId == event.gradeId) {
      _expandedGradeId = null;
      // Clear selected section when collapsing to avoid dropdown conflicts
      _selectedSubjectSectionId = null;
    } else {
      _expandedGradeId = event.gradeId;
      // Clear selected section when expanding a different grade
      _selectedSubjectSectionId = null;
    }
    _emitLoaded();
  }

  Future<void> _onApplyQuickPattern(
    ApplyQuickPatternEvent event,
    Emitter<GradeManagementState> emit,
  ) async {

    try {
      final tenantId = _userStateService.currentTenantId ?? '';
      final now = DateTime.now();

      // First, fetch existing sections from database (in case cache is empty)
      // Use activeOnly: false to include all sections, even if soft-deleted
      final existingSectionsResult = await _sectionRepository.getGradeSections(
        tenantId: tenantId,
        gradeId: event.gradeId,
        activeOnly: false,  // Include all sections to find duplicates
      );

      final existingSectionNames = existingSectionsResult.fold(
        (failure) => <String>[],
        (sections) => sections.map((s) => s.sectionName).toSet(),
      );


      // Update cache if sections were fetched
      final existingSections = existingSectionsResult.fold(
        (failure) => _sectionsCache[event.gradeId] ?? [],
        (sections) => sections,
      );
      _sectionsCache[event.gradeId] = existingSections;

      // Build final sections list - combining existing and new
      final newSectionsList = <GradeSection>[];

      for (int i = 0; i < event.sections.length; i++) {
        final sectionName = event.sections[i];

        // Skip if section already exists
        if (existingSectionNames.contains(sectionName)) {
          // Find and add existing section to list
          try {
            var existing = existingSections.firstWhere(
              (s) => s.sectionName == sectionName,
            );

            // If section is inactive, ALWAYS reactivate it
            if (!existing.isActive) {
              final reactivated = GradeSection(
                id: existing.id,
                tenantId: existing.tenantId,
                gradeId: existing.gradeId,
                sectionName: existing.sectionName,
                displayOrder: existing.displayOrder,
                isActive: true,  // MUST be active
                createdAt: existing.createdAt,
                updatedAt: now,
              );

              // Update in database
              await _sectionRepository.updateGradeSection(reactivated);
              existing = reactivated;
            }

            newSectionsList.add(existing);
          } catch (e) {
          }
          continue;
        }

        // Create new section (doesn't exist yet)
        final newSection = GradeSection(
          id: const Uuid().v4(),
          tenantId: tenantId,
          gradeId: event.gradeId,
          sectionName: sectionName,
          displayOrder: i + 1,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        final result = await _sectionRepository.createGradeSection(newSection);

        result.fold(
          (failure) {
            // Don't add failed sections to the list
          },
          (createdSection) {
            newSectionsList.add(createdSection);
          },
        );
      }

      // IMPORTANT: Update cache with the complete list (existing + newly created)
      _sectionsCache[event.gradeId] = newSectionsList;
      _emitLoaded();
    } catch (e) {
      emit(GradeManagementError(e.toString()));
    }
  }

  void _emitLoaded() {
    // Create new Map instance to force Equatable to detect changes
    final sectionsMap = Map<String, List<GradeSection>>.from(_sectionsCache);
    final subjectsMap = Map<String, List<GradeSubject>>.from(_subjectsCache);
    final availableSubjectsMap = Map<int, List<SubjectEntity>>.from(_availableSubjectsCache);

    emit(GradeManagementLoaded(
      grades: _gradesCache,
      sectionsPerGrade: sectionsMap,
      subjectsPerSection: subjectsMap,
      availableSubjectsPerGrade: availableSubjectsMap,
      expandedGradeId: _expandedGradeId,
      selectedSubjectSectionId: _selectedSubjectSectionId,
      tenantName: _getTenantName(),
    ));
  }

  String _getTenantName() {
    return _userStateService.currentTenantName ?? 'School';
  }

  // =============== SUBJECT EVENT HANDLERS ===============
  Future<void> _onLoadSubjectsForSection(
    LoadSubjectsForSectionEvent event,
    Emitter<GradeManagementState> emit,
  ) async {

    try {
      final tenantId = _userStateService.currentTenantId;
      if (tenantId == null) {
        emit(const GradeManagementError('Tenant not found'));
        return;
      }

      final result = await _subjectRepository.getSubjectsForGradeSection(
        tenantId: tenantId,
        gradeId: event.gradeId,
        sectionId: event.sectionName, // Pass section NAME (A, B, C), not UUID
      );

      result.fold(
        (failure) {
          emit(GradeManagementError(failure.message));
        },
        (subjects) {
          // Cache by section ID (UUID) for UI compatibility
          _subjectsCache[event.sectionId] = subjects;
          _emitLoaded();
        },
      );
    } catch (e) {
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onSelectSubjectSection(
    SelectSubjectSectionEvent event,
    Emitter<GradeManagementState> emit,
  ) async {
    _selectedSubjectSectionId = event.sectionId;
    _emitLoaded();
  }

  Future<void> _onAddSubjectToSection(
    AddSubjectToSectionEvent event,
    Emitter<GradeManagementState> emit,
  ) async {

    try {
      final tenantId = _userStateService.currentTenantId ?? '';
      final now = DateTime.now();
      final currentSubjects = _subjectsCache[event.sectionId] ?? [];
      final displayOrder = currentSubjects.length + 1;

      final gradeSubject = GradeSubject(
        id: const Uuid().v4(),
        tenantId: tenantId,
        gradeId: event.gradeId,
        sectionId: event.sectionName, // Use section name, not ID
        subjectId: event.subjectId,
        displayOrder: displayOrder,
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      final result = await _subjectRepository.addSubjectToSection(gradeSubject);

      result.fold(
        (failure) {
          emit(GradeManagementError(failure.message));
        },
        (createdSubject) {
          // Reload subjects for the section to ensure UI updates with the new subject
          _loadSubjectsForSectionAfterAdd(event.gradeId, event.sectionId, emit);
        },
      );
    } catch (e) {
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _loadSubjectsForSectionAfterAdd(
    String gradeId,
    String sectionId, // This is actually section ID (UUID), but we need to get the section name
    Emitter<GradeManagementState> emit,
  ) async {

    try {
      final tenantId = _userStateService.currentTenantId;
      if (tenantId == null) {
        emit(const GradeManagementError('Tenant not found'));
        return;
      }

      // Find the section name from cache
      final sections = _sectionsCache[gradeId] ?? [];
      final section = sections.firstWhere(
        (s) => s.id == sectionId,
        orElse: () => throw Exception('Section not found'),
      );

      final result = await _subjectRepository.getSubjectsForGradeSection(
        tenantId: tenantId,
        gradeId: gradeId,
        sectionId: section.sectionName, // Pass section NAME (A, B, C), not UUID
      );

      result.fold(
        (failure) {
          emit(GradeManagementError(failure.message));
        },
        (subjects) {
          _subjectsCache[sectionId] = subjects;
          _emitLoaded();
        },
      );
    } catch (e) {
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onRemoveSubjectFromSection(
    RemoveSubjectFromSectionEvent event,
    Emitter<GradeManagementState> emit,
  ) async {

    try {
      final result = await _subjectRepository.removeSubjectFromSection(event.gradeSubjectId);

      result.fold(
        (failure) {
          emit(GradeManagementError(failure.message));
        },
        (_) {
          final updatedSubjects = List<GradeSubject>.from(_subjectsCache[event.sectionId] ?? []);
          updatedSubjects.removeWhere((s) => s.id == event.gradeSubjectId);
          _subjectsCache[event.sectionId] = updatedSubjects;
          _emitLoaded();
        },
      );
    } catch (e) {
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onApplySubjectPattern(
    ApplySubjectPatternEvent event,
    Emitter<GradeManagementState> emit,
  ) async {

    try {
      final tenantId = _userStateService.currentTenantId ?? '';

      // Clear existing subjects for this section
      final result = await _subjectRepository.clearSubjectsFromSection(
        tenantId: tenantId,
        gradeId: event.gradeId,
        sectionId: event.sectionId,
      );

      result.fold(
        (failure) {
          emit(GradeManagementError(failure.message));
        },
        (_) async {
          // Add new subjects from pattern
          final addResult = await _subjectRepository.addMultipleSubjectsToSection(
            tenantId: tenantId,
            gradeId: event.gradeId,
            sectionId: event.sectionId,
            subjectIds: event.subjectIds,
          );

          addResult.fold(
            (failure) {
              emit(GradeManagementError(failure.message));
            },
            (newSubjects) {
              _subjectsCache[event.sectionId] = newSubjects;
              _emitLoaded();
            },
          );
        },
      );
    } catch (e) {
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onLoadAvailableSubjectsForGrade(
    LoadAvailableSubjectsForGradeEvent event,
    Emitter<GradeManagementState> emit,
  ) async {

    try {
      final result = await _subjectCatalogRepository.getSubjectsByGrade(event.gradeNumber);

      result.fold(
        (failure) {
          emit(GradeManagementError(failure.message));
        },
        (subjects) {
          _availableSubjectsCache[event.gradeNumber] = subjects;
          _emitLoaded();
        },
      );
    } catch (e) {
      emit(GradeManagementError(e.toString()));
    }
  }
}
