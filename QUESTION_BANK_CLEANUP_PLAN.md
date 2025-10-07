# Question Bank Module - Cleanup Plan

## Current State Analysis

**File**: `lib/features/question_bank/presentation/pages/question_bank_page.dart`
**Size**: 1,518 lines
**Methods**: 40+ methods
**Status**: ❌ BLOATED - Everything in one file

---

## 🔍 **Code Breakdown**

### **State Management** (Lines 28-49)
- 13 state variables
- Animations, controllers, search state
- Filter state (grade, subject)
- PDF generation state
- User name cache

### **UI Components** (40 methods, ~1,400 lines)
1. **Search & Filters** (Lines 108-374)
   - `_buildSearchBar()` - 27 lines
   - `_buildFilterChips()` - 17 lines
   - `_buildGradeFilter()` - 28 lines
   - `_buildSubjectFilter()` - 28 lines
   - `_buildFilterChip()` - 64 lines
   - Helper widgets for loading/error/clear

2. **Tabs** (Lines 375-402)
   - `_buildModernTabs()` - 28 lines

3. **Paper Lists** (Lines 496-720)
   - `_buildPapersForPeriod()` - 34 lines
   - `_buildArchiveView()` - 34 lines
   - `_buildMonthSection()` - 53 lines
   - `_buildStatsHeader()` - 52 lines
   - `_buildModernClassSection()` - 53 lines

4. **Paper Card** (Lines 722-878) ⭐ **MOST REUSABLE**
   - `_buildModernPaperCard()` - 106 lines
   - `_buildModernTag()` - 12 lines
   - `_buildStatusBadge()` - 12 lines
   - `_buildModernMetric()` - 21 lines
   - `_buildModernActions()` - 55 lines (depends on callbacks)

5. **Empty States** (Lines 935-1060)
   - `_buildEmptyForPeriod()` - 55 lines
   - `_buildModernLoading()` - 33 lines
   - `_buildModernEmpty()` - 38 lines

### **Business Logic** (Lines 1061-1518)
- Search/filter logic
- User name loading (API calls)
- PDF preview/download dialogs
- PDF generation (heavy logic - ~200 lines!)
- File handling (open/share)

---

## 🎯 **Proposed Structure**

```
question_bank/
├── domain/
│   ├── usecases/
│   │   ├── get_approved_papers_usecase.dart ✅ (exists)
│   │   └── search_papers_usecase.dart (new)
│   └── services/
│       └── paper_filter_service.dart (new - filter logic)
│
├── presentation/
│   ├── bloc/
│   │   ├── question_bank_bloc.dart (new)
│   │   ├── question_bank_event.dart (new)
│   │   └── question_bank_state.dart (new)
│   │
│   ├── widgets/
│   │   ├── search/
│   │   │   └── paper_search_bar.dart (~50 lines)
│   │   │
│   │   ├── filters/
│   │   │   ├── filter_panel.dart (~150 lines)
│   │   │   ├── grade_filter_chip.dart (~80 lines)
│   │   │   └── subject_filter_chip.dart (~80 lines)
│   │   │
│   │   ├── paper_card/
│   │   │   ├── approved_paper_card.dart (~150 lines) ⭐
│   │   │   ├── paper_tag.dart (~20 lines)
│   │   │   ├── paper_metric.dart (~30 lines)
│   │   │   └── paper_actions.dart (~80 lines)
│   │   │
│   │   ├── lists/
│   │   │   ├── papers_by_period_list.dart (~100 lines)
│   │   │   ├── archive_month_section.dart (~80 lines)
│   │   │   └── class_section.dart (~80 lines)
│   │   │
│   │   ├── empty_states/
│   │   │   ├── empty_period_view.dart (~60 lines)
│   │   │   └── empty_search_view.dart (~50 lines)
│   │   │
│   │   └── pdf/
│   │       ├── pdf_preview_dialog.dart (~100 lines)
│   │       └── pdf_download_dialog.dart (~100 lines)
│   │
│   └── pages/
│       └── question_bank_page.dart (~200 lines) ✅
│
└── services/ (consider moving to shared)
    └── pdf_export_service.dart (~150 lines)
```

---

## 📋 **Extraction Priority**

### **Phase 1: Quick Wins** (Start Here)
1. ✅ **Extract `ApprovedPaperCard`** (~150 lines)
   - Most reusable component
   - Used in all tabs
   - Clear responsibility

2. ✅ **Extract `PaperTag` & `PaperMetric`** (~50 lines total)
   - Simple, pure widgets
   - Used by PaperCard

3. ✅ **Extract `FilterPanel`** (~200 lines)
   - Self-contained
   - Callbacks for filter changes

### **Phase 2: State Management**
4. ✅ **Create `QuestionBankBloc`**
   - Move state variables
   - Handle search/filter events
   - Load papers, grades, subjects

5. ✅ **Extract `PaperFilterService`**
   - Filter logic (grade, subject, search)
   - Grouping logic (by class, by month)

### **Phase 3: Complex Components**
6. ✅ **Extract PDF dialogs** (~200 lines)
   - Preview options dialog
   - Download options dialog

7. ✅ **Extract List widgets** (~300 lines)
   - PapersByPeriodList
   - ArchiveMonthSection
   - ClassSection

### **Phase 4: Services**
8. ✅ **Extract `PdfExportService`** (~200 lines)
   - PDF generation logic
   - File handling
   - Share/open logic

---

## 🚀 **Benefits**

### **Reusability**
- `ApprovedPaperCard` can be used in:
  - Question bank
  - Admin dashboard
  - Teacher submissions view

### **Testability**
- Each widget can be tested independently
- BLoC makes state testable
- Services are mockable

### **Maintainability**
- 1,518 lines → ~200 lines in main page
- Clear separation of concerns
- Easy to find and fix bugs

### **Performance**
- Smaller widget trees rebuild
- Better const optimization
- Lazy loading possible

---

## ⚠️ **Edge Cases to Handle**

1. **Empty States**
   - No papers for period
   - No search results
   - No filters match

2. **Loading States**
   - Initial load
   - Refresh
   - PDF generation
   - User names loading

3. **Error States**
   - Failed to load papers
   - Failed to generate PDF
   - Network errors

4. **PDF Generation**
   - File already exists
   - No permission to write
   - Failed to open file
   - Share cancelled

5. **Search/Filter**
   - Special characters in search
   - No results
   - Multiple filters active

---

## 📝 **Next Steps**

### **Option 1: Extract Components Only** (2-3 hours)
- Create all widget files
- Keep existing state management
- Quick, low-risk

### **Option 2: Full Refactor** (4-5 hours)
- Create BLoC
- Extract all widgets
- Move PDF logic to service
- Comprehensive, long-term solution

### **Option 3: Incremental** (Spread over days)
- Extract 1-2 widgets per session
- Test after each extraction
- Gradual improvement

---

## 🎯 **Recommended Approach**

**Start with Option 1** - Extract components first:

1. Extract `ApprovedPaperCard` (30 min)
2. Extract `FilterPanel` (30 min)
3. Extract `PaperSearchBar` (15 min)
4. Test the page (15 min)
5. Extract PDF dialogs (30 min)
6. **PAUSE & TEST** - Make sure app still works

Then decide if you want to continue with BLoC or stop here.

---

**Ready to start?** I can begin with extracting the `ApprovedPaperCard` widget right now!

