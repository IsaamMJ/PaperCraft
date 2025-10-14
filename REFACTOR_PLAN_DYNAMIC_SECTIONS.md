# Refactor Plan: Dynamic Sections Integration

## Overview
This document outlines the systematic refactor needed to integrate dynamic paper sections into the existing paper creation workflow.

---

## Files Requiring Changes

### 1. QuestionInputCoordinator
**File**: `lib/features/paper_creation/domain/services/question_input_coordinator.dart`

**Current Parameters**:
```dart
final List<ExamSectionEntity> sections;
final ExamTypeEntity examType;
```

**New Parameters**:
```dart
final List<PaperSectionEntity> paperSections;
// Remove: examType parameter
```

**Changes Needed**:
- Replace `widget.sections` with `widget.paperSections` throughout
- Remove all references to `widget.examType`
- Update section iteration to use `PaperSectionEntity` instead of `ExamSectionEntity`
- Update paper creation to pass `paperSections` instead of `examTypeEntity`

---

### 2. QuestionPaperCreatePage
**File**: `lib/features/paper_creation/presentation/pages/question_paper_create_page.dart`

**Current Flow**:
1. Select Grade → Select Subject → Select Exam Type → Select Date
2. Build questions based on exam type sections

**New Flow**:
1. Select Grade → Select Subject → Load Saved Patterns (optional) → Build Sections → Select Date
2. Build questions based on dynamic paper sections

**State Variables to ADD**:
```dart
List<PaperSectionEntity> _paperSections = [];
```

**State Variables to REMOVE**:
```dart
List<ExamTypeEntity> _availableExamTypes = [];
ExamTypeEntity? _selectedExamType;
```

**Imports to ADD**:
```dart
import '../../../catalog/domain/entities/paper_section_entity.dart';
import '../../../catalog/presentation/bloc/teacher_pattern_bloc.dart';
import '../../../catalog/presentation/bloc/teacher_pattern_event.dart';
import '../../../catalog/presentation/bloc/teacher_pattern_state.dart';
import '../../../catalog/presentation/widgets/pattern_selector_widget.dart';
import '../../../catalog/presentation/widgets/section_builder_widget.dart';
```

**Imports to REMOVE**:
```dart
import '../../../catalog/domain/entities/exam_type_entity.dart';
import '../../../catalog/presentation/bloc/exam_type_bloc.dart' as exam_type;
```

**UI Changes**:
- Remove exam type card selection UI (lines ~431-465)
- Add `PatternSelectorWidget` after subject selection
- Add `SectionBuilderWidget` after pattern selector
- Update validation logic in `_isStepValid()` to check `_paperSections.isNotEmpty`
- Update `_generateAutoTitle()` to not use exam type name
- Update `_buildQuestionsStep()` to pass `paperSections` instead of `examType`

---

### 3. QuestionPaperEditPage
**File**: `lib/features/paper_creation/presentation/pages/question_paper_edit_page.dart`

**Changes Needed**:
- Similar to Create Page
- Load existing `paper.paperSections` instead of fetching exam type
- Display sections in read-only mode or allow editing

---

### 4. QuestionPaperModel (Data Layer)
**File**: Search for `question_paper_model.dart` in data layer

**Changes Needed**:
- Add `paper_sections` field to JSON serialization
- Remove `exam_type_id` field from JSON
- Update `fromJson` to parse `paper_sections` JSONB array
- Update `toJson` to serialize `paper_sections`
- Update `toEntity()` to pass `paperSections` instead of fetching `examTypeEntity`

---

### 5. QuestionPaperDataSource
**File**: Search for question paper data source

**Changes Needed**:
- Update queries to include `paper_sections` column
- Remove joins with `exam_types` table
- Update insert/update operations to include `paper_sections`

---

### 6. PDF Generation Services
**Files**: Search for PDF generation services (SimplePdfService, etc.)

**Changes Needed**:
- Accept `List<PaperSectionEntity>` instead of `ExamTypeEntity`
- Update section iteration logic
- Remove references to `examTypeEntity.sections`

---

### 7. Dependency Injection
**File**: `lib/core/infrastructure/di/injection_container.dart`

**Add Registrations**:
```dart
// Teacher Pattern Repository
sl.registerLazySingleton<ITeacherPatternRepository>(
  () => TeacherPatternRepositoryImpl(sl()),
);

// Teacher Pattern Data Source
sl.registerLazySingleton<TeacherPatternDataSource>(
  () => TeacherPatternDataSource(sl()),
);

// Teacher Pattern Use Cases
sl.registerLazySingleton(() => GetTeacherPatternsUseCase(sl()));
sl.registerLazySingleton(() => SaveTeacherPatternUseCase(sl()));
sl.registerLazySingleton() => DeleteTeacherPatternUseCase(sl()));

// Teacher Pattern BLoC
sl.registerFactory(
  () => TeacherPatternBloc(
    getPatterns: sl(),
    savePattern: sl(),
    deletePattern: sl(),
  ),
);
```

---

### 8. Exam Type Cleanup
**Files to DELETE**:
- `lib/features/catalog/domain/entities/exam_type_entity.dart`
- `lib/features/catalog/domain/repositories/exam_type_repository.dart`
- `lib/features/catalog/domain/usecases/get_exam_types_usecase.dart`
- `lib/features/catalog/domain/usecases/get_exam_type_by_id_usecase.dart`
- `lib/features/catalog/data/models/exam_type_model.dart`
- `lib/features/catalog/data/repositories/exam_type_repository_impl.dart`
- `lib/features/catalog/data/datasources/exam_type_data_source.dart`
- `lib/features/catalog/presentation/bloc/exam_type_bloc.dart`
- `lib/features/catalog/presentation/pages/exam_type_management_page.dart`
- `lib/features/catalog/presentation/widgets/exam_type_management_widget.dart`

**DI Cleanup**:
- Remove all exam type related registrations from injection_container.dart

**Route Cleanup**:
- Remove exam type management routes from app_routes.dart

---

## Implementation Order

1. ✅ Create new entities (PaperSectionEntity, TeacherPatternEntity)
2. ✅ Create repository and use cases
3. ✅ Create data layer (models, data source, repository impl)
4. ✅ Create BLoC layer
5. ✅ Update QuestionPaperEntity
6. ✅ Create UI widgets (section builder, pattern selector)
7. **Update QuestionInputCoordinator** ← NEXT
8. **Update QuestionPaperCreatePage**
9. **Update QuestionPaperEditPage**
10. **Update QuestionPaperModel (data layer)**
11. **Update QuestionPaperDataSource**
12. **Update PDF Generation**
13. **Update DI Container**
14. **Clean up exam type files**
15. **Test end-to-end**

---

## Testing Checklist

- [ ] Can create paper with custom sections
- [ ] Can load saved pattern
- [ ] Pattern de-duplication works
- [ ] Pattern use count increments
- [ ] Question input works with dynamic sections
- [ ] PDF generation works with dynamic sections
- [ ] Paper save/load works
- [ ] Paper edit works
- [ ] No references to exam_type_id in database queries
- [ ] No import errors after cleanup

---

## Rollback Strategy

If issues arise:
1. Keep database backup before migration
2. Rollback migration (instructions in migration file)
3. Revert code changes via git
4. Restore exam_types table from backup

---

## Notes

- ExamSectionEntity and PaperSectionEntity have same structure
- May need to create alias or migration path between them
- Auto-save pattern logic should be subtle (no user prompts)
- Pattern name generation should be smart (use exam date or subject)
