# Implementation Details - Inline Edit Features

## Overview
This document provides technical details about the implementation of:
1. Edit Section Headings
2. Edit Match the Following Questions

---

## Architecture Overview

```
┌─────────────────────────────────────────────┐
│   QuestionPaperDetailPage                   │
│   - _showEditSectionModal()                 │
│   - _showEditQuestionModal()                │
└────────────┬────────────────────────────────┘
             │
             ├─→ SectionEditModal (NEW)
             │   - Handles section name editing
             │   - Returns new section name
             │
             └─→ QuestionInlineEditModal (ENHANCED)
                 - Detects match_following type
                 - Shows appropriate UI for question type
                 - Returns updated text and options

         ↓ (via BLoC events)

┌─────────────────────────────────────────────┐
│   QuestionPaperBloc                         │
│   - UpdateSectionName event (NEW)           │
│   - UpdateQuestionInline event (EXISTING)   │
└────────────┬────────────────────────────────┘
             │
             ├─→ _onUpdateSectionName()
             │   - Updates section.name
             │   - Updates questions map keys
             │   - Saves to database
             │
             └─→ _onUpdateQuestionInline()
                 - Updates question text/options
                 - Handles all question types
                 - Saves to database

         ↓

┌─────────────────────────────────────────────┐
│   UpdatePaperUseCase                        │
│   - Persists changes to Supabase            │
└─────────────────────────────────────────────┘
```

---

## File Changes Detail

### 1. section_edit_modal.dart (NEW FILE)

**Location**: `lib/features/paper_workflow/presentation/widgets/section_edit_modal.dart`

**Purpose**: Modal dialog for editing section names

**Key Components**:
```dart
class SectionEditModal extends StatefulWidget {
  final String sectionName;              // Current section name
  final int sectionNumber;               // Section number (for display)
  final Function(String newName) onSave; // Callback with new name
  final VoidCallback onCancel;           // Cancel callback
}
```

**Functionality**:
- Single text field for section name
- Validates non-empty name
- Skips save if name unchanged
- Shows loading state during save

**Data Flow**:
1. User enters new section name
2. User clicks "Save Changes"
3. Validation runs (non-empty check)
4. `onSave` callback invoked with new name
5. Modal closes automatically

---

### 2. question_inline_edit_modal.dart (MODIFIED)

**Location**: `lib/features/paper_workflow/presentation/widgets/question_inline_edit_modal.dart`

**New Properties Added**:
```dart
late List<TextEditingController> _columnAControllers;
late List<TextEditingController> _columnBControllers;
```

**New Methods Added**:

#### `_isMatchFollowing()`
```dart
bool _isMatchFollowing() => widget.question.type == 'match_following';
```
Quick check for match_following question type.

#### `_parseMatchingPairs()`
```dart
void _parseMatchingPairs() {
  // Extracts options by finding '---SEPARATOR---'
  // Creates controllers for each column
  // Logs parsed data for debugging
}
```
Parses the options list using the separator marker.

**Modified Methods**:

#### `initState()`
- Detects question type
- For match_following: calls `_parseMatchingPairs()`
- For others: uses regular option controllers

#### `dispose()`
- Disposes column controllers in addition to option controllers

#### `_addOption()`
- For match_following: adds pair (both columns)
- For others: adds single option

#### `_removeOption()`
- For match_following: removes pair (disposes both)
- For others: removes single option

#### `_saveChanges()`
- Detects question type
- **For match_following**:
  - Collects Column A items
  - Collects Column B items
  - Validates both non-empty
  - Validates equal count
  - Combines with separator: `[...colA, '---SEPARATOR---', ...colB]`
- **For others**: existing logic

**UI Changes**:

New container for match_following (replaces options section):
```
┌─────────────────────────────────┐
│ Column A     →     Column B     │
├─────────────────────────────────┤
│ [TextField] → [TextField]  [del]│
│ [TextField] → [TextField]  [del]│
│ [TextField] → [TextField]  [del]│
│                                 │
│        [+ Add Pair]             │
└─────────────────────────────────┘
```

---

### 3. question_paper_detail_page.dart (MODIFIED)

**Location**: `lib/features/paper_workflow/presentation/pages/question_paper_detail_page.dart`

**Changes**:

1. **Added Import**:
```dart
import '../widgets/section_edit_modal.dart';
```

2. **Modified `_buildSection()`**:
   - Wrapped text in `Row` with `Expanded`
   - Added edit button (only if `!widget.isViewOnly`)
   - Button calls `_showEditSectionModal()`

3. **New Method `_showEditSectionModal()`**:
```dart
void _showEditSectionModal(String sectionName, int sectionNumber) {
  // 1. Get BLoC reference
  // 2. Show SectionEditModal dialog
  // 3. On save: dispatch UpdateSectionName event
  // 4. Close modal
  // 5. Show any errors with SnackBar
}
```

**Error Handling**:
- Wraps event dispatch in try-catch
- Shows detailed debug logs
- Displays user-friendly error messages

---

### 4. question_paper_bloc.dart (MODIFIED)

**Location**: `lib/features/paper_workflow/presentation/bloc/question_paper_bloc.dart`

**New Event Class**:
```dart
class UpdateSectionName extends QuestionPaperEvent {
  final String oldSectionName;
  final String newSectionName;

  const UpdateSectionName({
    required this.oldSectionName,
    required this.newSectionName,
  });

  @override
  List<Object> get props => [oldSectionName, newSectionName];
}
```

**New Handler Registration** (in constructor):
```dart
on<UpdateSectionName>(_onUpdateSectionName);
```

**New Handler Method `_onUpdateSectionName()`**:

**Steps**:
1. Verify state is `QuestionPaperLoaded`
2. Verify paper is loaded
3. Find section by old name in `paperSections`
4. Update section object with new name
5. Update `questions` map (rename key)
6. Create updated paper entity
7. Emit intermediate state with updates
8. Save to database via `_updatePaperUseCase`
9. Emit final state with saved data

**Error Handling**:
- Check state type
- Check paper exists
- Check section exists
- Handle database save failures
- Detailed logging at each step

**Logging Output**:
```
🎯 [BLoC] UpdateSectionName event received
   - Old section name: "..."
   - New section name: "..."
   📋 Checking paper structure...
   🔄 Updating section: old→new
   ✅ Section name updated successfully
   💾 Saving updated paper to database...
   ✅ Paper saved to database successfully
   📢 Section name update complete
```

---

## Data Flow Examples

### Example 1: Edit Section Name

```
User Input
  ↓
_showEditSectionModal("Arithmetic", 1)
  ↓
SectionEditModal opens
User types "Advanced Arithmetic"
User clicks "Save Changes"
  ↓
onSave callback: _showEditSectionModal()
  ↓
bloc.add(UpdateSectionName(
  oldSectionName: "Arithmetic",
  newSectionName: "Advanced Arithmetic"
))
  ↓
_onUpdateSectionName handler runs:
  1. Find section with name "Arithmetic" in paperSections
  2. Create new section with name "Advanced Arithmetic"
  3. Update questions map: {"Arithmetic": [...]} → {"Advanced Arithmetic": [...]}
  4. Create new QuestionPaperEntity with updates
  5. Save to database
  6. Emit new state
  ↓
UI updates with new section name
"Section 1: Advanced Arithmetic (5 questions)"
```

### Example 2: Edit Match the Following

```
User Input
  ↓
_showEditQuestionModal(matchQuestion, index, sectionName)
  ↓
QuestionInlineEditModal detects match_following type
  ↓
_parseMatchingPairs() runs:
  options = ["Apple", "Mango", "---SEPARATOR---", "Fruit 1", "Fruit 2"]
  columnA = ["Apple", "Mango"]
  columnB = ["Fruit 1", "Fruit 2"]
  Creates controllers for each
  ↓
UI shows:
  Column A          Column B
  [Apple]    →      [Fruit 1]
  [Mango]    →      [Fruit 2]
  ↓
User edits:
  Column A          Column B
  [Apple]    →      [Red Fruit]
  [Mango]    →      [Yellow Fruit]
  ↓
User clicks "Save Changes"
  ↓
_saveChanges() runs:
  1. Extract Column A: ["Apple", "Mango"]
  2. Extract Column B: ["Red Fruit", "Yellow Fruit"]
  3. Validate: both non-empty ✓
  4. Validate: equal length (2 == 2) ✓
  5. Combine: ["Apple", "Mango", "---SEPARATOR---", "Red Fruit", "Yellow Fruit"]
  ↓
onSave callback with combined options
  ↓
bloc.add(UpdateQuestionInline(
  sectionName: sectionName,
  questionIndex: index,
  updatedText: originalText,
  updatedOptions: [...combined...]
))
  ↓
_onUpdateQuestionInline handler runs:
  1. Update question options
  2. Save to database
  3. Emit new state
  ↓
UI updates with new question options
```

---

## State Management Flow

### BLoC States Used

```
QuestionPaperLoaded {
  currentPaper: QuestionPaperEntity,
  editedQuestions: Set<String>,  // For tracking
  // ... other fields
}
```

### State Changes

**For Section Edit**:
```
Initial State
  ↓ (emit intermediate)
QuestionPaperLoaded(currentPaper: updated)
  ↓ (database save completes)
QuestionPaperLoaded(currentPaper: saved)
```

**For Question Edit**:
```
Initial State
  ↓ (emit intermediate with editedQuestions tracking)
QuestionPaperLoaded(currentPaper: updated, editedQuestions: added)
  ↓ (database save completes)
QuestionPaperLoaded(currentPaper: saved, editedQuestions: preserved)
```

---

## Validation Logic

### Section Name Validation
```dart
final updatedName = _sectionNameController.text.trim();

if (updatedName.isEmpty) {
  // Error: Section name cannot be empty
  return;
}

if (updatedName == widget.sectionName) {
  // No change: close without saving
  return;
}
```

### Match Following Validation
```dart
final columnA = controllers.map(text.trim).where(isNotEmpty).toList();
final columnB = controllers.map(text.trim).where(isNotEmpty).toList();

if (columnA.isEmpty || columnB.isEmpty) {
  // Error: Both columns must have at least one item
  return;
}

if (columnA.length != columnB.length) {
  // Error: Both columns must have equal items
  return;
}

// Valid: combine with separator
final combined = [...columnA, '---SEPARATOR---', ...columnB];
```

---

## Testing Recommendations

### Unit Tests
- [ ] `UpdateSectionName` event creation
- [ ] `UpdateSectionName` handler logic
- [ ] Section name validation
- [ ] Match following pair parsing
- [ ] Match following pair validation
- [ ] Options combination with separator

### Widget Tests
- [ ] `SectionEditModal` renders correctly
- [ ] `SectionEditModal` validation shows errors
- [ ] `QuestionInlineEditModal` detects match_following
- [ ] `QuestionInlineEditModal` shows correct UI for match_following
- [ ] Two-column layout renders for match_following

### Integration Tests
- [ ] Edit section name end-to-end
- [ ] Edit match question end-to-end
- [ ] Changes persist after reload
- [ ] Error handling works correctly

---

## Performance Considerations

- **Parsing**: `_parseMatchingPairs()` runs once per match_following question open
- **Controllers**: Created as needed, disposed properly to prevent memory leaks
- **Database**: Single async operation per save (no blocking)
- **UI**: Uses `setState` for local updates before database confirmation

---

## Known Limitations

1. Cannot edit question marks (by design)
2. Cannot delete questions (must use full editor)
3. Cannot change question type (must use full editor)
4. Match pairs must have equal count (validation enforced)

---

## Future Improvements

1. **Validation on blur**: Show errors as user types
2. **Undo/Redo**: Keep undo stack for recent changes
3. **Keyboard shortcuts**: Ctrl+S to save
4. **Bulk operations**: Edit multiple questions at once
5. **Add questions**: Feature #3 deferred for later

---

## Debugging

### Enable Detailed Logging
All debug logs use `print()` statements. Check console/logs for:

```
🔍 [SectionEditModal] Opening/Closing
💾 [SectionEditModal] Save triggered
📝 [DetailPage] Modal operations
🎯 [BLoC] Event received
🔄 [BLoC] Processing
✅ [BLoC] Success
❌ [BLoC] Errors
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Edit button not showing | `isViewOnly=true` | Check paper status |
| Match columns not equal | User error | Add/remove items to balance |
| Section not found | Name mismatch | Check section exists |
| Save fails silently | Database error | Check logs for error message |

---

## Code Statistics

- **Lines added**: ~400
- **Files created**: 1 (`section_edit_modal.dart`)
- **Files modified**: 3 (detail page, inline modal, BLoC)
- **New BLoC events**: 1
- **New BLoC handlers**: 1
- **New UI components**: 2 (Section modal, match UI)

