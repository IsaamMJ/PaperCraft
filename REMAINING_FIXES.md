# Remaining Fixes for Dynamic Sections Migration

## Status: 95% Complete - Final Cleanup Needed

### ✅ COMPLETED
- Database migration applied
- All exam type files deleted
- Domain, data, and BLoC layers for teacher patterns complete
- UI components created
- Paper creation page updated
- Question input coordinator updated
- PDF generation services updated
- Dependency injection updated
- Main compilation errors in core files fixed

### 🔧 REMAINING ERRORS TO FIX

#### 1. Teacher Pattern Repository Implementation
**File**: `lib/features/catalog/data/repositories/teacher_pattern_repository_impl.dart`
**Issue**: Method signatures don't match interface
**Fix**: Update all methods to match ITeacherPatternRepository interface

#### 2. Teacher Pattern BLoC
**File**: `lib/features/catalog/presentation/bloc/teacher_pattern_bloc.dart`
**Issues**:
- Line 53: `getFrequentlyUsed()` doesn't exist
- Line 69: Missing `pattern` parameter
- Line 89: `update()` method doesn't exist
**Fix**: Update to use correct use case methods

#### 3. Question Paper Edit Page
**File**: `lib/features/paper_creation/presentation/pages/question_paper_edit_page.dart`
**Issues**:
- Imports ExamTypeEntity (deleted)
- References `paper.examTypeId` and `paper.examTypeEntity`
**Fix**: Update to use `paper.paperSections` instead

#### 4. Question Input Dialog
**File**: `lib/features/paper_creation/presentation/widgets/question_input/question_input_dialog.dart`
**Issues**:
- Imports ExamTypeEntity
- Uses `sections` and `examType` parameters instead of `paperSections`
**Fix**: Update QuestionInputCoordinator calls to use `paperSections`

#### 5. Paper Review Page
**File**: `lib/features/paper_review/presentation/pages/paper_review_page.dart`
**Issues**: Multiple references to `paper.examTypeEntity`
**Fix**: Remove duration/exam type references (no longer available)

#### 6. Paper Cloud Data Source
**File**: `lib/features/paper_workflow/data/datasources/paper_cloud_data_source.dart`
**Issue**: Line 56 references `paper.examTypeId`
**Fix**: Remove this field reference

#### 7. Paper Local Data Source (Hive)
**File**: `lib/features/paper_workflow/data/datasources/paper_local_data_source_hive.dart`
**Issues**:
- Imports ExamTypeEntity
- References `paper.examTypeId` and `paper.examTypeEntity`
- Lines 541-554: Uses old `examTypeEntity` in fromHive
**Fix**: Update to use `paperSections`

#### 8. Section Ordering Helper
**File**: `lib/features/paper_workflow/domain/services/section_ordering_helper.dart`
**Issue**: Imports and uses ExamTypeEntity
**Fix**: Update to use PaperSectionEntity

## QUICK FIX COMMANDS

### Global Find & Replace Suggestions:
1. Replace `paper.examTypeEntity.sections` with `paper.paperSections`
2. Replace `paper.examTypeId` with `// removed - using dynamic sections`
3. Replace `paper.examTypeEntity.formattedDuration` with `// duration removed`
4. Remove all `import exam_type_entity.dart` statements

### Files That Need Manual Review:
1. `teacher_pattern_repository_impl.dart` - Interface mismatch
2. `teacher_pattern_bloc.dart` - Use case calls incorrect
3. `question_paper_edit_page.dart` - Complete refactor needed
4. `paper_local_data_source_hive.dart` - Hive storage updates

## TESTING CHECKLIST (After Fixes)
- [ ] App compiles without errors
- [ ] Teacher can create paper with custom sections
- [ ] Pattern auto-saves after paper creation
- [ ] Pattern loads from dropdown
- [ ] PDF generates correctly
- [ ] Paper saves to database
- [ ] Paper loads from database
- [ ] No crashes in admin dashboard

## ESTIMATED TIME: 2-3 hours
