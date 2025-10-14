# Teachers Workflow - Remaining Friction Points

**Last Updated**: 2025-10-14
**Status**: 30 friction points remaining to be fixed

---

## 🔴 CRITICAL - Remaining (3 friction points)

### 1. No Way to Preview PDF Before Finalizing
- **Location**: `question_paper_create_page.dart` - missing feature
- **Impact**: MEDIUM - Teachers finalize without seeing final layout
- **Current State**: "Finalize" directly changes status, must edit to regenerate PDF
- **Proposed Fix**:
  - Add "Preview & Finalize" button
  - Show PDF preview with "Confirm Finalization" action
  - Allow adjustments before final submission

### 2. No Error Recovery When Finalization Fails
- **Location**: `question_paper_detail_page.dart:790-810`
- **Impact**: MEDIUM - Paper stuck in limbo if finalization errors
- **Current State**: Snackbar error only, no retry option
- **Proposed Fix**:
  - Show detailed error dialog
  - Add "Retry" button
  - Allow "Keep as Draft" option

### 3. No Search/Filter on Home Page
- **Location**: `home_page.dart:180-200`
- **Impact**: MEDIUM - Hard to find specific papers in long lists
- **Proposed Fix**:
  - Add search bar below tabs
  - Filter by title, subject, class, date range
  - Show "X results" count

---

## 🟡 MEDIUM - Remaining (12 friction points)

### 4. Question Type Icons Not Intuitive
- **Location**: `question_input_coordinator.dart:400-450`
- **Issue**: MCQ, Fill-in-blank, Short answer use similar icons
- **Fix**: Use more distinctive icons with labels

### 5. No Character/Word Count for Long Answers
- **Location**: `question_input_coordinator.dart:500-550`
- **Issue**: Teachers can't gauge answer space needed
- **Fix**: Add live character count under text fields

### 6. Cannot Add Images to Questions (Future - Skip)
- **Location**: `question_input_coordinator.dart` - missing feature
- **Issue**: Math/Science questions need diagrams
- **Fix**: Add image picker with preview

### 7. No Way to Set Marking Scheme (Future - Skip)
- **Location**: `question_paper_create_page.dart` - missing feature
- **Issue**: Teachers manually write marking schemes separately
- **Fix**: Add optional marking scheme field per question

### 8. No Templates for Common Paper Types
- **Location**: `home_page.dart` - missing feature
- **Issue**: Teachers start from scratch every time
- **Fix**: Add template gallery (midterm, final, quiz formats)

### 9. Cannot Adjust Per-Question Marks After Creation
- **Location**: `question_paper_detail_page.dart:920-950`
- **Issue**: Must delete and recreate question to change marks
- **Fix**: Add inline edit for marks field

### 10. No Indication of Unsaved Changes
- **Location**: `question_paper_edit_page.dart:200-300`
- **Issue**: Teachers may lose changes by navigating away
- **Fix**: Show "Unsaved changes" badge, confirm before exit

### 11. Cannot Rearrange Sections
- **Location**: `question_paper_create_page.dart` - missing feature
- **Issue**: Section order fixed after creation
- **Fix**: Add drag-to-reorder for sections

### 12. No Way to Add Instructions Per Section
- **Location**: `question_paper_create_page.dart:300-350`
- **Issue**: General instructions only, not section-specific
- **Fix**: Add optional "Section Instructions" field

### 13. Cannot Set Time Limits Per Section
- **Location**: `question_paper_create_page.dart` - missing feature
- **Issue**: Teachers want to guide pacing
- **Fix**: Add optional time suggestion per section

### 14. No Formatting Options for Questions
- **Location**: `question_input_coordinator.dart:500-550`
- **Issue**: Cannot bold/italicize important terms
- **Fix**: Add basic rich text toolbar (bold, italic, underline)

### 15. Cannot Preview Individual Questions
- **Location**: `question_input_coordinator.dart` - missing feature
- **Issue**: Don't see formatted output until full PDF
- **Fix**: Add "Preview" button per question

---

## 🟢 MINOR - Remaining (12 friction points)

### 16. No Statistics on Paper Difficulty
- **Location**: `question_paper_detail_page.dart` - missing feature
- **Issue**: No way to gauge if paper is balanced
- **Fix**: Show difficulty distribution (Easy/Med/Hard based on marks)

### 17. Cannot Export to Word/Google Docs
- **Location**: `question_paper_detail_page.dart` - missing feature
- **Issue**: PDF only, cannot edit externally
- **Fix**: Add .docx export option

### 18. No Option to Randomize Question Order
- **Location**: `question_paper_create_page.dart` - missing feature
- **Issue**: Teachers want different versions for anti-cheating
- **Fix**: Add "Generate variants" option with randomized order

### 19. No Keyboard Shortcuts
- **Location**: Entire app
- **Issue**: Must use mouse for all actions
- **Fix**: Add Ctrl+S (save), Ctrl+N (new), etc.

### 20. Cannot Change Paper Status Directly
- **Location**: `home_page.dart:400-500`
- **Issue**: Must open detail page to finalize
- **Fix**: Add status dropdown on card

### 21. No Recently Used Subjects List
- **Location**: `question_paper_create_page.dart:350-400`
- **Issue**: Must scroll through all subjects every time
- **Fix**: Show last 5 used subjects at top

### 22. No Recently Used Classes List
- **Location**: `question_paper_create_page.dart:400-450`
- **Issue**: Teachers teach same classes repeatedly
- **Fix**: Show current year's classes at top

### 23. No Confirmation When Exiting Unsaved Work
- **Location**: `question_paper_create_page.dart`, `question_paper_edit_page.dart`
- **Issue**: Back button may lose work (though auto-save helps)
- **Fix**: Show dialog if unsaved changes exist

### 24. Cannot Collapse/Expand Sections in Preview
- **Location**: `question_paper_detail_page.dart:600-700`
- **Issue**: Long papers hard to navigate
- **Fix**: Make sections collapsible

### 25. Cannot Set Font Size Preference
- **Location**: App-wide
- **Issue**: Text size fixed, may be too small for some
- **Fix**: Add accessibility settings

### 26. No Dark Mode
- **Location**: App-wide
- **Issue**: Bright UI tiring for long sessions
- **Fix**: Add theme toggle

### 27. No Undo/Redo for Question Edits
- **Location**: `question_input_coordinator.dart`
- **Issue**: Must manually revert changes
- **Fix**: Add edit history stack

---

## Priority Recommendations

### Phase 1 (Next Sprint) - Focus on Critical Issues
1. **PDF Preview Before Finalize** - Prevent layout surprises
2. **Error Recovery on Finalization** - Handle failures gracefully
3. **Search/Filter on Home** - Findability for large lists

### Phase 2 - Workflow Efficiency
4. Question Type Icons - Better UX
5. Character/Word Count - Better planning
6. Templates - Quick starts
7. Adjust Marks After Creation - Flexibility

### Phase 3 - Feature Completeness
8. Unsaved Changes Indicator - Prevent data loss
9. Rearrange Sections - Flexibility
10. Section Instructions - Better clarity
11. Individual Question Preview - Confidence

### Phase 4 - Polish & Accessibility
12. Change Status Directly on Card - Efficiency
13. Collapsible Sections - Navigation
14. Dark Mode - Accessibility
15. Keyboard Shortcuts - Power users

---

## Notes

- **Future Items (Skip for Now)**: Image upload and marking schemes - marked for future implementation
- **Total Remaining**: 27 friction points across Critical (3), Medium (12), Minor (12)
- **Quick Wins**: Items 4, 5, 20, 21, 22, 23 can be done in 1-2 hours each
