import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/grade_section_repository.dart';
import '../../domain/usecases/load_grade_sections_usecase.dart';
import '../../domain/usecases/create_grade_section_usecase.dart';
import '../../domain/usecases/delete_grade_section_usecase.dart';
import 'grade_section_event.dart';
import 'grade_section_state.dart';

/// BLoC for managing grade sections
class GradeSectionBloc extends Bloc<GradeSectionEvent, GradeSectionState> {
  final LoadGradeSectionsUseCase loadGradeSectionsUseCase;
  final CreateGradeSectionUseCase createGradeSectionUseCase;
  final DeleteGradeSectionUseCase deleteGradeSectionUseCase;
  final GradeSectionRepository repository;

  GradeSectionBloc({
    required this.loadGradeSectionsUseCase,
    required this.createGradeSectionUseCase,
    required this.deleteGradeSectionUseCase,
    required this.repository,
  }) : super(const GradeSectionInitial()) {
    on<LoadGradeSectionsEvent>(_onLoadGradeSections);
    on<CreateGradeSectionEvent>(_onCreateGradeSection);
    on<DeleteGradeSectionEvent>(_onDeleteGradeSection);
    on<RefreshGradeSectionsEvent>(_onRefreshGradeSections);
  }

  /// Load grade sections
  Future<void> _onLoadGradeSections(
    LoadGradeSectionsEvent event,
    Emitter<GradeSectionState> emit,
  ) async {
    emit(const GradeSectionLoading());

    final result = await loadGradeSectionsUseCase(
      tenantId: event.tenantId,
      gradeId: event.gradeId,
    );

    result.fold(
      (failure) => emit(GradeSectionError(failure.message)),
      (sections) {
        if (sections.isEmpty) {
          emit(const GradeSectionEmpty());
        } else {
          emit(GradeSectionLoaded(sections));
        }
      },
    );
  }

  /// Create a new grade section
  Future<void> _onCreateGradeSection(
    CreateGradeSectionEvent event,
    Emitter<GradeSectionState> emit,
  ) async {
    emit(const GradeSectionCreating());

    final result = await createGradeSectionUseCase(
      tenantId: event.tenantId,
      gradeId: event.gradeId,
      sectionName: event.sectionName,
      displayOrder: event.displayOrder,
    );

    result.fold(
      (failure) => emit(GradeSectionCreationError(failure.message)),
      (section) {
        emit(GradeSectionCreated(section));
        // Auto-reload sections after creation
        add(LoadGradeSectionsEvent(
          tenantId: event.tenantId,
          gradeId: event.gradeId,
        ));
      },
    );
  }

  /// Delete a grade section
  Future<void> _onDeleteGradeSection(
    DeleteGradeSectionEvent event,
    Emitter<GradeSectionState> emit,
  ) async {
    emit(GradeSectionDeleting(event.sectionId));

    final result = await deleteGradeSectionUseCase(sectionId: event.sectionId);

    result.fold(
      (failure) => emit(GradeSectionDeletionError(failure.message)),
      (_) => emit(GradeSectionDeleted(event.sectionId)),
    );
  }

  /// Refresh grade sections
  Future<void> _onRefreshGradeSections(
    RefreshGradeSectionsEvent event,
    Emitter<GradeSectionState> emit,
  ) async {
    add(LoadGradeSectionsEvent(
      tenantId: event.tenantId,
      gradeId: event.gradeId,
    ));
  }
}
