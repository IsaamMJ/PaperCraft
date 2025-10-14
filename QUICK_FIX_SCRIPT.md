# Quick Fix Script for Remaining Errors

## Status: 47 errors remaining (down from 55+)

### ✅ FIXED
1. ✅ teacher_pattern_repository_impl.dart - All methods now match interface
2. ✅ teacher_pattern_data_source.dart - Added missing methods
3. ✅ teacher_pattern_bloc.dart - Fixed method calls
4. ✅ teacher_pattern_event.dart - Simplified UpdateTeacherPattern

### 🔧 REMAINING FILES TO FIX

#### High Priority (Breaking compilation):

1. **question_paper_edit_page.dart** - Remove all exam type references
2. **question_input_dialog.dart** - Update to use `paperSections`
3. **paper_review_page.dart** - Remove `examTypeEntity` references
4. **paper_cloud_data_source.dart** - Remove `examTypeId`
5. **paper_local_data_source_hive.dart** - Update Hive serialization
6. **section_ordering_helper.dart** - Remove ExamTypeEntity import
7. **save_draft_usecase.dart** - Check for exam type references
8. **shared_bloc_provider.dart** - Check for exam type references

### GLOBAL FIND & REPLACE

Run these replacements across all files:

```dart
// FIND: paper.examTypeEntity.sections
// REPLACE WITH: paper.paperSections

// FIND: paper.examTypeEntity.formattedDuration
// REPLACE WITH: // duration removed

// FIND: paper.examTypeId
// REPLACE WITH: // examTypeId removed

// FIND: import.*exam_type_entity.dart';
// REPLACE WITH: // removed exam type import

// FIND: ExamTypeEntity
// REPLACE WITH: // ExamTypeEntity removed
```

### SPECIFIC FILE FIXES

#### 1. question_input_dialog.dart
**Location**: lib/features/paper_creation/presentation/widgets/question_input/question_input_dialog.dart
**Changes**:
```dart
// OLD:
QuestionInputCoordinator(
  sections: widget.sections,
  examType: widget.examType,
)

// NEW:
QuestionInputCoordinator(
  paperSections: widget.paperSections,
)
```

#### 2. paper_local_data_source_hive.dart
**Location**: lib/features/paper_workflow/data/datasources/paper_local_data_source_hive.dart
**Changes**:
- Remove `ExamTypeEntity` import
- In `fromHive` method (line ~541):
  ```dart
  // Remove examTypeEntity parsing
  // Add paperSections parsing instead:
  paperSections: paperSections,  // from model
  ```

#### 3. paper_cloud_data_source.dart
**Location**: lib/features/paper_workflow/data/datasources/paper_cloud_data_source.dart
**Line 56**: Remove `paper.examTypeId` reference

#### 4. section_ordering_helper.dart
**Location**: lib/features/paper_workflow/domain/services/section_ordering_helper.dart
**Changes**:
- Remove `import exam_type_entity.dart`
- Change `ExamTypeEntity` parameter to `List<PaperSectionEntity>`

### TESTING AFTER FIXES

1. Run `flutter analyze` - should have 0 errors
2. Run `flutter build apk --debug` - should compile
3. Test paper creation flow
4. Test pattern save/load
5. Test PDF generation

### ESTIMATED TIME: 30-45 minutes

All remaining errors follow the same pattern - replace exam type references with paper sections.
