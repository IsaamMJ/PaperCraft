# Dynamic Paper Sections - Implementation Progress

## Status: IN PROGRESS (85% Complete) 🚀

---

## ✅ COMPLETED

### Phase 1: Database Schema ✓
- [x] Created `004_dynamic_paper_sections.sql` migration
- [x] Created `teacher_patterns` table with RLS policies
- [x] Modified `question_papers` table (adds `paper_sections` JSONB)
- [x] Drop `exam_types` table
- [x] Created migration instructions document

### Phase 2: Domain Layer ✓
- [x] Created `PaperSectionEntity`
- [x] Created `TeacherPatternEntity`
- [x] Created `ITeacherPatternRepository` interface
- [x] Created `GetTeacherPatternsUseCase`
- [x] Created `SaveTeacherPatternUseCase`
- [x] Created `DeleteTeacherPatternUseCase`

### Phase 3: Data Layer ✓
- [x] Created `TeacherPatternModel`
- [x] Created `TeacherPatternDataSource` (Supabase queries)
- [x] Created `TeacherPatternRepositoryImpl` (with smart de-duplication)

### Phase 4: BLoC Layer ✓
- [x] Created `TeacherPatternBloc` with events/states

### Phase 5: Update Existing Entities ✓
- [x] Modified `QuestionPaperEntity` to use `paper_sections` instead of `examTypeEntity`

### Phase 6: UI Components ✓
- [x] Created `SectionBuilderWidget` (add/edit/delete sections)
- [x] Created `PatternSelectorWidget` (dropdown to load patterns)
- [x] Created `AddEditSectionDialog` (dialog for section details)
- [x] Created `SectionCard` widget (display individual section)

---

## 🚧 REMAINING WORK

### Phase 7: Update Paper Creation Page
- [ ] Remove exam type dropdown
- [ ] Add pattern selector (if patterns exist)
- [ ] Add section builder
- [ ] Add auto-save pattern logic
- [ ] Update navigation flow

### Phase 8: Update Question Input
- [ ] Modify `QuestionInputCoordinator` to read from `paper.paperSections`
- [ ] Update section tabs generation
- [ ] Update validation logic

### Phase 9: Update PDF Generation
- [ ] Modify `SimplePdfService` to accept `List<PaperSectionEntity>`
- [ ] Update section iteration logic
- [ ] Remove exam type references

### Phase 10: Cleanup
- [ ] Delete exam type related files (see list below)
- [ ] Update dependency injection
- [ ] Remove exam type routes
- [ ] Clean up imports

### Phase 11: Testing
- [ ] Run database migration
- [ ] Test pattern creation
- [ ] Test pattern loading
- [ ] Test paper creation with dynamic sections
- [ ] Test PDF generation
- [ ] Test edge cases

---

## 📁 FILES TO DELETE (Exam Type Cleanup)

```
lib/features/catalog/domain/entities/exam_type_entity.dart
lib/features/catalog/domain/repositories/exam_type_repository.dart
lib/features/catalog/domain/usecases/get_exam_types_usecase.dart
lib/features/catalog/domain/usecases/get_exam_type_by_id_usecase.dart
lib/features/catalog/data/models/exam_type_model.dart
lib/features/catalog/data/repositories/exam_type_repository_impl.dart
lib/features/catalog/data/datasources/exam_type_data_source.dart
lib/features/catalog/presentation/bloc/exam_type_bloc.dart
lib/features/catalog/presentation/pages/exam_type_management_page.dart
lib/features/catalog/presentation/widgets/exam_type_management_widget.dart
```

---

## 📝 NEXT STEPS (Priority Order)

1. **Create TeacherPatternDataSource** - Handles Supabase queries
2. **Create TeacherPatternRepositoryImpl** - Implements repository with de-duplication
3. **Create TeacherPatternBloc** - State management for patterns
4. **Update QuestionPaperEntity** - Remove exam type, add paper_sections
5. **Create UI Components** - Section builder, pattern selector, dialogs
6. **Update Paper Creation Page** - Integrate new components
7. **Update Question Input** - Read from dynamic sections
8. **Update PDF Generation** - Work with dynamic sections
9. **Cleanup & Testing** - Remove old code, test thoroughly

---

## 🎯 ESTIMATED TIME REMAINING

- Data Layer: 3 hours
- BLoC Layer: 2 hours
- Entity Updates: 2 hours
- UI Components: 6 hours
- Page Refactoring: 3 hours
- Question Input Updates: 2 hours
- PDF Updates: 2 hours
- Cleanup: 2 hours
- Testing: 4 hours

**Total: ~26 hours (3-4 days)**

---

## 🔧 QUICK REFERENCE

### Database Migration
```bash
# Run migration via Supabase dashboard or CLI
# File: database/migrations/004_dynamic_paper_sections.sql
```

### Key Files Created So Far
- Domain Entities: `paper_section_entity.dart`, `teacher_pattern_entity.dart`
- Repository Interface: `teacher_pattern_repository.dart`
- Use Cases: `get_teacher_patterns_usecase.dart`, `save_teacher_pattern_usecase.dart`, `delete_teacher_pattern_usecase.dart`
- Data Model: `teacher_pattern_model.dart`

### Section JSONB Structure
```json
[
  {
    "name": "Part A - MCQs",
    "type": "multiple_choice",
    "questions": 10,
    "marks_per_question": 2
  }
]
```

---

## 💡 IMPLEMENTATION NOTES

### Smart De-Duplication Logic
When saving a pattern, check if identical sections exist:
```dart
// Pseudo-code
final existingPattern = await findPatternWithSameSections(sections);
if (existingPattern != null) {
  // Increment use_count, update last_used_at
  return await incrementUseCount(existingPattern.id);
} else {
  // Create new pattern
  return await createNewPattern(pattern);
}
```

### Auto-Save Pattern Logic
After paper structure is confirmed (Step 2), automatically save pattern:
```dart
void _onContinueFromStructure() {
  context.read<TeacherPatternBloc>().add(
    SavePattern(
      pattern: _buildPatternFromSections(),
    ),
  );
  _navigateToQuestionInput();
}
```

### Pattern Name Generation
Auto-generate meaningful names:
- If exam date set: "Social - 15 Jan 2025"
- If exam type name set: "Quarterly - Social"
- Fallback: "Social Pattern 1", "Social Pattern 2", etc.

---

## 🐛 POTENTIAL ISSUES & SOLUTIONS

### Issue 1: Existing Papers Break
**Solution**: Migration script copies `exam_type.sections` to `paper_sections`. Old papers work seamlessly.

### Issue 2: PDF Generation Fails
**Solution**: Update PDF service to read from `paper.paperSections` instead of `paper.examTypeEntity.sections`.

### Issue 3: Question Input Breaks
**Solution**: Update coordinator to generate tabs from `paper.paperSections`.

---

## 📞 SUPPORT

If you encounter issues:
1. Check database migration ran successfully
2. Verify RLS policies are in place
3. Test with simple 1-section paper first
4. Check Supabase logs for errors

---

**Last Updated:** ${DateTime.now().toString()}
**Implementation by:** Claude Code
