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
  final String sectionId;

  const LoadSubjectsForSectionEvent(this.gradeId, this.sectionId);

  @override
  List<Object?> get props => [gradeId, sectionId];
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
    print('📚 [GradeManagementBloc] Loading grades with sections');
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
          print('❌ [GradeManagementBloc] Failed to load grades: ${failure.message}');
          return <GradeEntity>[];
        },
        (gradesList) => gradesList,
      );

      if (grades.isEmpty) {
        print('⚠️ [GradeManagementBloc] No grades found');
        emit(GradeManagementLoaded(
          grades: [],
          sectionsPerGrade: {},
          tenantName: _getTenantName(),
        ));
        return;
      }

      print('✅ [GradeManagementBloc] Loaded ${grades.length} grades');

      _gradesCache = grades;
      _sectionsCache = {};

      // Load sections for each grade
      for (final grade in grades) {
        print('   Loading sections for Grade ${grade.gradeNumber} (ID: ${grade.id})');
        final sectionsResult = await _sectionRepository.getGradeSections(
          tenantId: tenantId,
          gradeId: grade.id,
        );

        final sections = sectionsResult.fold(
          (failure) {
            print('   ❌ Failed to load sections: ${failure.message}');
            return <GradeSection>[];
          },
          (sectionsList) {
            print('   ✅ Loaded ${sectionsList.length} sections');
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
      print('❌ [GradeManagementBloc] Exception: $e');
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onAddGrade(
    AddGradeEvent event,
    Emitter<GradeManagementState> emit,
  ) async {
    print('➕ [GradeManagementBloc] Adding grade: Grade ${event.gradeNumber}');

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
          print('❌ [GradeManagementBloc] Failed to add grade: ${failure.message}');
          emit(GradeManagementError(failure.message));
        },
        (createdGrade) {
          print('✅ [GradeManagementBloc] Grade added: ${createdGrade.displayName}');
          _gradesCache.add(createdGrade);
          _sectionsCache[createdGrade.id] = [];
          _emitLoaded();
        },
      );
    } catch (e) {
      print('❌ [GradeManagementBloc] Exception in add grade: $e');
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onDeleteGrade(
    DeleteGradeEvent event,
    Emitter<GradeManagementState> emit,
  ) async {
    print('🗑️ [GradeManagementBloc] Deleting grade: Grade ${event.gradeNumber} (ID: ${event.gradeId})');

    try {
      final result = await _gradeRepository.deleteGrade(event.gradeId);

      result.fold(
        (failure) {
          print('❌ [GradeManagementBloc] Failed to delete grade: ${failure.message}');
          emit(GradeManagementError(failure.message));
        },
        (_) {
          print('✅ [GradeManagementBloc] Grade deleted successfully');
          // Create NEW list to force Equatable to detect changes
          final updatedGrades = List<GradeEntity>.from(_gradesCache);
          updatedGrades.removeWhere((g) => g.id == event.gradeId);
          _gradesCache = updatedGrades;
          _sectionsCache.remove(event.gradeId);
          _expandedGradeId = null;
          print('   Cache updated. Total grades: ${updatedGrades.length}');
          _emitLoaded();
        },
      );
    } catch (e) {
      print('❌ [GradeManagementBloc] Exception in delete grade: $e');
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onAddSection(
    AddSectionEvent event,
    Emitter<GradeManagementState> emit,
  ) async {
    print('➕ [GradeManagementBloc] Adding section: Grade ${event.gradeNumber}, Section ${event.sectionName}');

    try {
      final tenantId = _userStateService.currentTenantId ?? '';
      final now = DateTime.now();
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
          print('❌ [GradeManagementBloc] Failed to add section: ${failure.message}');
          print('   GradeID: ${event.gradeId}, SectionName: ${event.sectionName}, TenantID: $tenantId');
          emit(GradeManagementError('Failed to add section: ${failure.message}'));
        },
        (createdSection) {
          print('✅ [GradeManagementBloc] Section added successfully: ${createdSection.sectionName}');
          final currentSections = List<GradeSection>.from(_sectionsCache[event.gradeId] ?? []);
          currentSections.add(createdSection);
          _sectionsCache[event.gradeId] = currentSections;
          print('   Cache updated. Total sections for grade: ${currentSections.length}');
          _emitLoaded();
        },
      );
    } catch (e) {
      print('❌ [GradeManagementBloc] Exception in add section: $e');
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onRemoveSection(
    RemoveSectionEvent event,
    Emitter<GradeManagementState> emit,
  ) async {
    print('🗑️ [GradeManagementBloc] Removing section: Grade ${event.gradeNumber}, Section ID ${event.sectionId}');

    try {
      final result = await _sectionRepository.deleteGradeSection(event.sectionId);

      result.fold(
        (failure) {
          print('❌ [GradeManagementBloc] Failed to remove section: ${failure.message}');
          emit(GradeManagementError(failure.message));
        },
        (_) {
          print('✅ [GradeManagementBloc] Section removed successfully');
          // Create NEW list to force Equatable to detect changes
          final currentSections = List<GradeSection>.from(_sectionsCache[event.gradeId] ?? []);
          currentSections.removeWhere((s) => s.id == event.sectionId);
          _sectionsCache[event.gradeId] = currentSections;
          print('   Cache updated. Total sections for grade: ${currentSections.length}');
          _emitLoaded();
        },
      );
    } catch (e) {
      print('❌ [GradeManagementBloc] Exception in remove section: $e');
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onToggleExpand(
    ToggleExpandGradeEvent event,
    Emitter<GradeManagementState> emit,
  ) async {
    print('➡️ [GradeManagementBloc] Toggling expand for grade: ${event.gradeId}');

    if (_expandedGradeId == event.gradeId) {
      _expandedGradeId = null;
    } else {
      _expandedGradeId = event.gradeId;
    }
    _emitLoaded();
  }

  Future<void> _onApplyQuickPattern(
    ApplyQuickPatternEvent event,
    Emitter<GradeManagementState> emit,
  ) async {
    print('⚡ [GradeManagementBloc] Applying quick pattern to Grade ${event.gradeNumber}');
    print('   Sections: ${event.sections}');

    try {
      final tenantId = _userStateService.currentTenantId ?? '';
      final now = DateTime.now();

      // Remove existing sections
      final existingSections = _sectionsCache[event.gradeId] ?? [];
      for (final section in existingSections) {
        await _sectionRepository.deleteGradeSection(section.id);
      }

      // Add new sections from pattern
      final newSectionsList = <GradeSection>[];

      for (int i = 0; i < event.sections.length; i++) {
        final newSection = GradeSection(
          id: const Uuid().v4(), // Generate UUID
          tenantId: tenantId,
          gradeId: event.gradeId,
          sectionName: event.sections[i],
          displayOrder: i + 1,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        final result = await _sectionRepository.createGradeSection(newSection);
        result.fold(
          (failure) {
            print('❌ Failed to create section ${event.sections[i]}: ${failure.message}');
            print('   GradeID: ${event.gradeId}, TenantID: $tenantId, SectionName: ${event.sections[i]}');
          },
          (createdSection) {
            print('✅ Created section: ${createdSection.sectionName}');
            newSectionsList.add(createdSection);
          },
        );
      }

      // Update cache with new list
      _sectionsCache[event.gradeId] = newSectionsList;
      print('✅ [GradeManagementBloc] Quick pattern applied successfully - Total sections: ${newSectionsList.length}');
      _emitLoaded();
    } catch (e) {
      print('❌ [GradeManagementBloc] Exception in apply pattern: $e');
      emit(GradeManagementError(e.toString()));
    }
  }

  void _emitLoaded() {
    // Create new Map instance to force Equatable to detect changes
    final sectionsMap = Map<String, List<GradeSection>>.from(_sectionsCache);
    final subjectsMap = Map<String, List<GradeSubject>>.from(_subjectsCache);
    final availableSubjectsMap = Map<int, List<SubjectEntity>>.from(_availableSubjectsCache);
    print('📤 [GradeManagementBloc] Emitting loaded state with ${_gradesCache.length} grades');
    print('   Sections cache: ${sectionsMap.entries.map((e) => '${e.key}=${e.value.length}').join(", ")}');
    print('   Subjects cache: ${subjectsMap.entries.map((e) => '${e.key}=${e.value.length}').join(", ")}');
    print('   Available subjects cache: ${availableSubjectsMap.entries.map((e) => 'Grade${e.key}=${e.value.length}').join(", ")}');

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
    print('📚 [GradeManagementBloc] Loading subjects for Grade=${event.gradeId}, Section=${event.sectionId}');

    try {
      final tenantId = _userStateService.currentTenantId;
      if (tenantId == null) {
        emit(const GradeManagementError('Tenant not found'));
        return;
      }

      final result = await _subjectRepository.getSubjectsForGradeSection(
        tenantId: tenantId,
        gradeId: event.gradeId,
        sectionId: event.sectionId,
      );

      result.fold(
        (failure) {
          print('❌ [GradeManagementBloc] Failed to load subjects: ${failure.message}');
          emit(GradeManagementError(failure.message));
        },
        (subjects) {
          print('✅ [GradeManagementBloc] Loaded ${subjects.length} subjects');
          final currentSubjects = List<GradeSubject>.from(_subjectsCache[event.sectionId] ?? []);
          // Replace with loaded subjects
          _subjectsCache[event.sectionId] = subjects;
          _emitLoaded();
        },
      );
    } catch (e) {
      print('❌ [GradeManagementBloc] Exception loading subjects: $e');
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onSelectSubjectSection(
    SelectSubjectSectionEvent event,
    Emitter<GradeManagementState> emit,
  ) async {
    print('➡️ [GradeManagementBloc] Selecting subject section: ${event.sectionId}');
    _selectedSubjectSectionId = event.sectionId;
    _emitLoaded();
  }

  Future<void> _onAddSubjectToSection(
    AddSubjectToSectionEvent event,
    Emitter<GradeManagementState> emit,
  ) async {
    print('➕ [GradeManagementBloc] Adding subject ${event.subjectId} to section ${event.sectionName}');

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
          print('❌ [GradeManagementBloc] Failed to add subject: ${failure.message}');
          emit(GradeManagementError(failure.message));
        },
        (createdSubject) {
          print('✅ [GradeManagementBloc] Subject added successfully');
          // Reload subjects for the section to ensure UI updates with the new subject
          _loadSubjectsForSectionAfterAdd(event.gradeId, event.sectionId, emit);
        },
      );
    } catch (e) {
      print('❌ [GradeManagementBloc] Exception in add subject: $e');
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _loadSubjectsForSectionAfterAdd(
    String gradeId,
    String sectionId,
    Emitter<GradeManagementState> emit,
  ) async {
    print('🔄 [GradeManagementBloc] Reloading subjects after add for Section=$sectionId');

    try {
      final tenantId = _userStateService.currentTenantId;
      if (tenantId == null) {
        emit(const GradeManagementError('Tenant not found'));
        return;
      }

      final result = await _subjectRepository.getSubjectsForGradeSection(
        tenantId: tenantId,
        gradeId: gradeId,
        sectionId: sectionId,
      );

      result.fold(
        (failure) {
          print('❌ [GradeManagementBloc] Failed to reload subjects after add: ${failure.message}');
          emit(GradeManagementError(failure.message));
        },
        (subjects) {
          print('✅ [GradeManagementBloc] Reloaded ${subjects.length} subjects after add');
          _subjectsCache[sectionId] = subjects;
          _emitLoaded();
        },
      );
    } catch (e) {
      print('❌ [GradeManagementBloc] Exception reloading subjects after add: $e');
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onRemoveSubjectFromSection(
    RemoveSubjectFromSectionEvent event,
    Emitter<GradeManagementState> emit,
  ) async {
    print('🗑️ [GradeManagementBloc] Removing subject ${event.gradeSubjectId} from section ${event.sectionId}');

    try {
      final result = await _subjectRepository.removeSubjectFromSection(event.gradeSubjectId);

      result.fold(
        (failure) {
          print('❌ [GradeManagementBloc] Failed to remove subject: ${failure.message}');
          emit(GradeManagementError(failure.message));
        },
        (_) {
          print('✅ [GradeManagementBloc] Subject removed successfully');
          final updatedSubjects = List<GradeSubject>.from(_subjectsCache[event.sectionId] ?? []);
          updatedSubjects.removeWhere((s) => s.id == event.gradeSubjectId);
          _subjectsCache[event.sectionId] = updatedSubjects;
          _emitLoaded();
        },
      );
    } catch (e) {
      print('❌ [GradeManagementBloc] Exception in remove subject: $e');
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onApplySubjectPattern(
    ApplySubjectPatternEvent event,
    Emitter<GradeManagementState> emit,
  ) async {
    print('⚡ [GradeManagementBloc] Applying subject pattern to section ${event.sectionId}');
    print('   Subjects: ${event.subjectIds}');

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
          print('❌ [GradeManagementBloc] Failed to clear subjects: ${failure.message}');
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
              print('❌ [GradeManagementBloc] Failed to add subjects: ${failure.message}');
              emit(GradeManagementError(failure.message));
            },
            (newSubjects) {
              print('✅ [GradeManagementBloc] Pattern applied successfully - ${newSubjects.length} subjects added');
              _subjectsCache[event.sectionId] = newSubjects;
              _emitLoaded();
            },
          );
        },
      );
    } catch (e) {
      print('❌ [GradeManagementBloc] Exception in apply pattern: $e');
      emit(GradeManagementError(e.toString()));
    }
  }

  Future<void> _onLoadAvailableSubjectsForGrade(
    LoadAvailableSubjectsForGradeEvent event,
    Emitter<GradeManagementState> emit,
  ) async {
    print('📚 [GradeManagementBloc] Loading available subjects for Grade ${event.gradeNumber}');

    try {
      final result = await _subjectCatalogRepository.getSubjectsByGrade(event.gradeNumber);

      result.fold(
        (failure) {
          print('❌ [GradeManagementBloc] Failed to load available subjects: ${failure.message}');
          emit(GradeManagementError(failure.message));
        },
        (subjects) {
          print('✅ [GradeManagementBloc] Loaded ${subjects.length} available subjects for Grade ${event.gradeNumber}');
          _availableSubjectsCache[event.gradeNumber] = subjects;
          _emitLoaded();
        },
      );
    } catch (e) {
      print('❌ [GradeManagementBloc] Exception loading available subjects: $e');
      emit(GradeManagementError(e.toString()));
    }
  }
}
