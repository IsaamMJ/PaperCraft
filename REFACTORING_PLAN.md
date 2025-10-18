# Papercraft App - Refactoring & Performance Plan

**Date:** 2025-10-17
**Status:** Ready for Implementation
**Focus:** Code Organization, Architecture, Performance

---

## Executive Summary

This plan addresses scalability, maintainability, and performance issues identified in the codebase. The app has 224 Dart files with several large files (1589 lines max), architectural violations (direct service locator calls in BLoC layer), and performance bottlenecks (heavy computations in build methods).

**Estimated Impact:**
- **Performance:** 40-60% improvement in UI responsiveness
- **Maintainability:** Easier to onboard new developers, faster feature development
- **Code Quality:** Reduced technical debt, better testability

---

## Phase 1: Code Organization & Cleanup

### Priority: HIGH | Estimated Time: 3-4 days

### 1.1 Split Large Files

**Target Files (>900 lines):**

#### 1. `pdf_generation_service.dart` (1589 lines)
**Location:** `lib/features/pdf_generation/domain/services/pdf_generation_service.dart`

**Split Into:**
```
lib/features/pdf_generation/domain/services/
├── pdf_generation_service.dart          (Core orchestration - ~200 lines)
├── pdf_layout_renderer.dart             (Layout rendering logic - ~400 lines)
├── pdf_question_renderer.dart           (Question rendering - ~400 lines)
├── pdf_header_footer_renderer.dart      (Headers/footers - ~200 lines)
├── pdf_table_renderer.dart              (Table generation - ~200 lines)
└── pdf_answer_key_renderer.dart         (Answer key generation - ~189 lines)
```

**Benefits:** Easier to test, maintain, and extend with new layouts

---

#### 2. `question_bank_page.dart` (1223 lines)
**Location:** `lib/features/question_bank/presentation/pages/question_bank_page.dart`

**Split Into:**
```
lib/features/question_bank/presentation/pages/
├── question_bank_page.dart              (Main page scaffold - ~300 lines)
└── widgets/
    ├── question_bank_tab_view.dart      (Tab content - ~250 lines)
    ├── question_bank_filters.dart       (Filter widgets - ~150 lines)
    ├── question_bank_paper_list.dart    (Paper list rendering - ~300 lines)
    └── question_bank_stats_header.dart  (Stats display - ~150 lines)
```

**Benefits:** Better separation of concerns, easier to optimize individual widgets

---

#### 3. `question_input_coordinator.dart` (1050 lines)
**Location:** `lib/features/paper_creation/domain/services/question_input_coordinator.dart`

**Split Into:**
```
lib/features/paper_creation/domain/services/
├── question_input_coordinator.dart      (Main coordinator - ~200 lines)
├── question_validation_service.dart     (Validation logic - ~250 lines)
├── question_state_manager.dart          (State management - ~300 lines)
└── question_serialization_service.dart  (Serialization - ~300 lines)
```

**Benefits:** Single responsibility, easier to unit test

---

#### 4. `question_paper_create_page.dart` (965 lines)
**Location:** `lib/features/paper_creation/presentation/pages/question_paper_create_page.dart`

**Split Into:**
```
lib/features/paper_creation/presentation/pages/
├── question_paper_create_page.dart      (Main scaffold - ~250 lines)
└── widgets/
    ├── paper_creation_form.dart         (Form inputs - ~300 lines)
    ├── section_management_panel.dart    (Section UI - ~250 lines)
    └── question_addition_panel.dart     (Add question UI - ~165 lines)
```

**Benefits:** Easier to maintain form logic, better widget reusability

---

#### 5. `paper_review_page.dart` (962 lines)
**Location:** `lib/features/paper_review/presentation/pages/paper_review_page.dart`

**Split Into:**
```
lib/features/paper_review/presentation/pages/
├── paper_review_page.dart               (Main scaffold - ~200 lines)
└── widgets/
    ├── review_question_list.dart        (Question display - ~300 lines)
    ├── review_action_panel.dart         (Approve/reject - ~250 lines)
    └── review_comments_panel.dart       (Comments UI - ~212 lines)
```

**Benefits:** Clearer review workflow, easier to add new review features

---

#### 6. `main_scaffold_screen.dart` (959 lines)
**Location:** `lib/features/shared/presentation/main_scaffold_screen.dart`

**Split Into:**
```
lib/features/shared/presentation/
├── main_scaffold_screen.dart            (Main scaffold - ~200 lines)
└── widgets/
    ├── app_navigation_bar.dart          (Bottom nav - ~250 lines)
    ├── app_drawer.dart                  (Side drawer - ~300 lines)
    └── scaffold_header.dart             (App bar - ~209 lines)
```

**Benefits:** Easier navigation customization per role

---

#### 7. `question_paper_detail_page.dart` (913 lines)
**Location:** `lib/features/paper_workflow/presentation/pages/question_paper_detail_page.dart`

**Split Into:**
```
lib/features/paper_workflow/presentation/pages/
├── question_paper_detail_page.dart      (Main page - ~200 lines)
└── widgets/
    ├── paper_detail_header.dart         (Header info - ~200 lines)
    ├── paper_detail_questions.dart      (Question list - ~300 lines)
    └── paper_detail_actions.dart        (Action buttons - ~213 lines)
```

**Benefits:** Easier to maintain detail view, better performance

---

#### 8. `injection_container.dart` (908 lines)
**Location:** `lib/core/infrastructure/di/injection_container.dart`

**Split Into:**
```
lib/core/infrastructure/di/
├── injection_container.dart             (Main container - ~100 lines)
├── core_dependencies.dart               (Core services - ~150 lines)
├── auth_dependencies.dart               (Auth feature - ~150 lines)
├── paper_dependencies.dart              (Paper features - ~250 lines)
├── catalog_dependencies.dart            (Catalog feature - ~150 lines)
└── feature_dependencies.dart            (Other features - ~108 lines)
```

**Benefits:** Feature-based DI organization, easier to manage dependencies

---

### 1.2 Remove Unused Code

**Actions:**
- Run `flutter analyze` and remove unused imports
- Search for unused classes/methods with IDE tools
- Remove commented-out code blocks
- Remove unused assets from `pubspec.yaml`

**Estimated Lines Removed:** 500-800 lines

---

### 1.3 Improve Folder Structure

**Current Issues:**
- Mixed concerns in `domain/services` (some should be in infrastructure)
- Presentation widgets not grouped by feature area
- Shared widgets scattered across features

**Proposed Reorganization:**

```
lib/features/paper_creation/
├── domain/
│   ├── entities/
│   ├── repositories/           (interfaces)
│   ├── usecases/
│   └── value_objects/          (NEW: for validation logic)
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/           (implementations)
├── infrastructure/             (NEW: for services)
│   ├── coordinators/           (question_input_coordinator.dart)
│   ├── validators/             (question_validation_service.dart)
│   └── serializers/            (question_serialization_service.dart)
└── presentation/
    ├── pages/
    ├── widgets/
    │   ├── forms/              (NEW: form-related widgets)
    │   ├── sections/           (NEW: section management)
    │   └── questions/          (question input widgets)
    └── bloc/
```

---

## Phase 2: Architecture Strengthening

### Priority: HIGH | Estimated Time: 4-5 days

### 2.1 Remove Direct Service Locator Calls

**Critical Violation Found:**

**File:** `lib/features/question_bank/presentation/bloc/question_bank_bloc.dart:65`
```dart
// CURRENT (WRONG):
final enrichedPapers = await sl<PaperDisplayService>().enrichPapers(paginatedResult.items);

// SHOULD BE:
final enrichedPapers = await _paperDisplayService.enrichPapers(paginatedResult.items);
```

**File:** `lib/features/home/presentation/bloc/home_bloc.dart:121`
```dart
// CURRENT (WRONG):
final enrichedPaper = (await sl<PaperDisplayService>().enrichPapers([paperModel])).first;

// SHOULD BE:
final enrichedPaper = (await _paperDisplayService.enrichPapers([paperModel])).first;
```

**Fix Required:**
1. Add `PaperDisplayService` to QuestionBankBloc constructor
2. Add `PaperDisplayService` to HomeBloc constructor
3. Update DI registration in `injection_container.dart`

**Benefits:** Better testability, clearer dependencies, follows Clean Architecture

---

### 2.2 Standardize Error Handling

**Current Issues:**
- Inconsistent error handling across layers
- Some places use try/catch, others use Either/Result
- Error messages not user-friendly

**Solution:**

Create standardized error types:
```dart
// lib/core/domain/failures/failures.dart
abstract class Failure {
  final String message;
  final String? technicalDetails;
  final FailureType type;

  const Failure(this.message, this.type, [this.technicalDetails]);
}

enum FailureType {
  network,
  server,
  validation,
  notFound,
  unauthorized,
  unknown,
}

class NetworkFailure extends Failure { ... }
class ServerFailure extends Failure { ... }
class ValidationFailure extends Failure { ... }
```

**Update all repositories/use cases to return:**
```dart
Future<Either<Failure, T>> execute();
```

---

### 2.3 Create Proper Service Abstractions

**Current Issue:** Services directly depend on concrete implementations

**Solution:**

Create interfaces for services:
```dart
// lib/core/domain/interfaces/i_paper_display_service.dart
abstract class IPaperDisplayService {
  Future<List<QuestionPaperEntity>> enrichPapers(List<QuestionPaperEntity> papers);
}

// lib/features/paper_workflow/domain/services/paper_display_service.dart
class PaperDisplayService implements IPaperDisplayService {
  @override
  Future<List<QuestionPaperEntity>> enrichPapers(...) { ... }
}
```

**Register in DI:**
```dart
sl.registerLazySingleton<IPaperDisplayService>(
  () => PaperDisplayService(sl(), sl()),
);
```

**Benefits:** Easier to mock in tests, swappable implementations

---

## Phase 3: Performance Optimization

### Priority: HIGH | Estimated Time: 3-4 days

### 3.1 Move Heavy Computations Out of Build Methods

#### Issue #1: Filtering in Build Method (HIGH SEVERITY)

**File:** `question_bank_page.dart:453-497`

**Current Implementation:**
```dart
Widget _buildPapersForPeriod(List<QuestionPaperEntity> allPapers, String period) {
  final papers = _filterPapersByPeriod(allPapers, period); // EXPENSIVE!
  final groupedPapers = _groupPapersByClass(papers);       // EXPENSIVE!
  // ... build UI
}
```

**Solution: Move to BLoC State**

Update `QuestionBankState`:
```dart
class QuestionBankLoaded extends QuestionBankState {
  final List<QuestionPaperEntity> papers;
  final Map<String, List<QuestionPaperEntity>> thisMonth;
  final Map<String, List<QuestionPaperEntity>> previous;
  final Map<String, List<QuestionPaperEntity>> archive;
  // ... other fields

  // Compute these in the BLoC when data loads
}
```

**Update BLoC:**
```dart
Future<void> _onLoadQuestionBankPaginated(...) async {
  // ... load papers ...

  // Compute filtered groups ONCE
  final thisMonth = _groupPapersByClass(_filterByPeriod(papers, 'this_month'));
  final previous = _groupPapersByClass(_filterByPeriod(papers, 'previous'));
  final archive = _groupPapersByMonth(_filterByPeriod(papers, 'archive'));

  emit(QuestionBankLoaded(
    papers: papers,
    thisMonth: thisMonth,
    previous: previous,
    archive: archive,
    // ...
  ));
}
```

**Update UI:**
```dart
Widget _buildPapersForPeriod(Map<String, List<QuestionPaperEntity>> groupedPapers) {
  // Just use pre-computed data!
  return CustomScrollView(
    slivers: groupedPapers.entries.map((entry) =>
      _buildModernClassSection(entry.key, entry.value)
    ).toList(),
  );
}
```

**Expected Impact:** 70-80% reduction in rebuild time for tab switches

---

#### Issue #2: Sorting in Build Method (HIGH SEVERITY)

**File:** `home_page.dart:628-636`

**Current Implementation:**
```dart
List<QuestionPaperEntity> _getAllPapers(HomeLoadedState state, bool isAdmin) {
  final allPapers = [...state.papers, ...state.submissions];
  allPapers.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt)); // EXPENSIVE!
  return allPapers;
}
```

**Solution: Pre-sort in BLoC**

```dart
// In HomeBloc
Future<void> _loadTeacherPapers(...) async {
  // ... load papers ...

  // Sort ONCE when loading
  drafts.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  submissions.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

  emit(HomeLoaded(drafts: drafts, submissions: submissions));
}
```

**Expected Impact:** 50% reduction in home page rebuild time

---

#### Issue #3: File I/O in Presentation Layer (HIGH SEVERITY)

**File:** `question_bank_page.dart:1069-1098`

**Current Implementation:**
```dart
Future<void> _downloadPdfFromBank(QuestionPaperEntity paper) async {
  // ... in presentation layer ...
  final savedFile = File('${directory.path}/$fileName');
  await savedFile.writeAsBytes(pdfBytes); // BLOCKING!
}
```

**Solution: Move to Use Case**

Create new use case:
```dart
// lib/features/pdf_generation/domain/usecases/download_pdf_usecase.dart
class DownloadPdfUseCase {
  final IPdfRepository _pdfRepository;

  Future<Either<Failure, String>> call({
    required String pdfUrl,
    required String fileName,
  }) async {
    // Use compute isolate for file I/O
    return _pdfRepository.downloadPdf(pdfUrl, fileName);
  }
}
```

**Update UI:**
```dart
// In presentation layer
final result = await _downloadPdfUseCase(
  pdfUrl: paper.pdfUrl,
  fileName: fileName,
);

result.fold(
  (failure) => _showError(failure.message),
  (filePath) => _showSuccess('Downloaded to: $filePath'),
);
```

**Expected Impact:** UI stays responsive during large file downloads

---

### 3.2 Add Widget Keys for Better Performance

**Files Affected:**
- `question_bank_page.dart:518, 551, 598, 703`
- `paper_preview_widget.dart:101, 124, 172`

**Current Implementation:**
```dart
...groupedPapers.entries.map((entry) =>
  _buildModernClassSection(entry.key, entry.value)
)
```

**Solution:**
```dart
...groupedPapers.entries.map((entry) =>
  SliverToBoxAdapter(
    key: ValueKey('class_${entry.key}'),
    child: _buildModernClassSection(entry.key, entry.value),
  )
).toList()

// For paper cards
_buildModernPaperCard(papers[index], key: ValueKey(papers[index].id))
```

**Expected Impact:** 20-30% reduction in unnecessary widget rebuilds

---

### 3.3 Optimize List Rendering

**Issue:** Triple-nested maps in `paper_preview_widget.dart:101-234`

**Current Implementation:**
```dart
...paper.questions.entries.map((entry) {
  return Column(
    children: [
      ...entry.value.asMap().entries.map((q) {
        return Column(
          children: [
            ...q.value.options!.asMap().entries.map((opt) {
              // Build option widget
            }).toList(),
          ],
        );
      }).toList(),
    ],
  );
}).toList()
```

**Solution: Use ListView.builder**
```dart
ListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: paper.questions.length,
  itemBuilder: (context, sectionIndex) {
    final section = paper.questions.entries.elementAt(sectionIndex);
    return _QuestionSectionWidget(
      key: ValueKey(section.key),
      section: section,
    );
  },
)
```

**Expected Impact:** 40% improvement in preview screen performance

---

### 3.4 Replace `withOpacity`/`withValues` with Const Colors

**Files Affected:** 40 files with 216 occurrences

**Current Implementation:**
```dart
color: AppColors.primary.withValues(alpha: 0.1)
```

**Solution: Pre-define in AppColors**
```dart
// lib/core/presentation/constants/app_colors.dart
class AppColors {
  static const primary = Color(0xFF6366F1);
  static const primaryLight = Color(0x1A6366F1);  // 10% opacity
  static const primaryLighter = Color(0x0D6366F1); // 5% opacity
  // ... etc
}
```

**Update usage:**
```dart
color: AppColors.primaryLight  // Instead of withValues(alpha: 0.1)
```

**Expected Impact:** 10-15% reduction in color object allocations

---

### 3.5 Cache User Info Lookups

**Issue:** User name lookups happen in filter loops (question_bank_page.dart:480)

**Current:**
```dart
final userName = _userNamesCache[paper.createdBy]?.toLowerCase() ?? '';
if (userName.contains(lowerQuery)) return true;
```

**Solution: Pre-compute searchable text**

Update `QuestionPaperEntity`:
```dart
class QuestionPaperEntity {
  // ... existing fields ...
  final String searchableText; // Computed once: includes title, subject, creator name
}
```

**Update enrichment:**
```dart
// In PaperDisplayService
Future<List<QuestionPaperEntity>> enrichPapers(...) async {
  for (var paper in papers) {
    final creatorName = await _getUserName(paper.createdBy);
    enrichedPapers.add(paper.copyWith(
      searchableText: '${paper.title} ${paper.subject} $creatorName'.toLowerCase(),
    ));
  }
}
```

**Update filter:**
```dart
papers.where((p) => p.searchableText.contains(lowerQuery))
```

**Expected Impact:** 60% faster search operations

---

## Phase 4: Additional Improvements

### Priority: MEDIUM | Estimated Time: 2-3 days

### 4.1 Add Missing Const Constructors

**Action:** Review all StatelessWidgets and add `const` where possible

**Example:**
```dart
class PaperStatusBadge extends StatelessWidget {
  const PaperStatusBadge({super.key, required this.status}); // Add const

  final PaperStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(...);
  }
}
```

**Estimated Impact:** 5-10% reduction in widget rebuilds

---

### 4.2 Implement Pagination Improvements

**Current:** Load more pagination works, but could be optimized

**Improvements:**
- Add debouncing to scroll listener
- Preload next page when 80% scrolled (not 100%)
- Add placeholder widgets while loading more
- Cache previous pages to avoid re-fetching

---

### 4.3 Add Performance Monitoring

**Implementation:**
```dart
// lib/core/infrastructure/monitoring/performance_monitor.dart
class PerformanceMonitor {
  static void trackBuildTime(String widgetName, VoidCallback build) {
    final stopwatch = Stopwatch()..start();
    build();
    stopwatch.stop();

    if (stopwatch.elapsedMilliseconds > 16) { // 60 FPS threshold
      logger.warning('Slow build: $widgetName took ${stopwatch.elapsedMilliseconds}ms');
    }
  }
}
```

**Usage:**
```dart
@override
Widget build(BuildContext context) {
  return PerformanceMonitor.trackBuildTime('QuestionBankPage', () {
    // ... build logic
  });
}
```

---

## Implementation Order

### Week 1: Foundation
1. **Day 1-2:** Split largest files (pdf_generation_service, question_bank_page)
2. **Day 3-4:** Fix architectural violations (remove sl<> calls)
3. **Day 5:** Move filtering/sorting to BLoC layer

### Week 2: Performance
1. **Day 6-7:** Optimize build methods (keys, const, caching)
2. **Day 8-9:** Move file I/O to proper layer, optimize list rendering
3. **Day 10:** Replace withOpacity with const colors

### Week 3: Polish
1. **Day 11-12:** Reorganize folder structure, split remaining large files
2. **Day 13-14:** Standardize error handling, create service abstractions
3. **Day 15:** Testing, performance verification, documentation

---

## Success Metrics

### Performance Targets:
- ✅ Home page initial load: < 500ms (currently ~1-2s)
- ✅ Question Bank tab switch: < 100ms (currently ~300-500ms)
- ✅ Paper preview open: < 200ms (currently ~500ms+)
- ✅ Search results: < 150ms (currently ~300-400ms)

### Code Quality Targets:
- ✅ Max file size: 500 lines
- ✅ Test coverage: >70% for domain/data layers
- ✅ Zero direct sl<> calls in domain/presentation
- ✅ All repositories return Either<Failure, T>

### Maintainability Targets:
- ✅ Clear folder structure by feature
- ✅ Single responsibility for all services
- ✅ Comprehensive inline documentation
- ✅ Updated architecture documentation

---

## Risk Mitigation

1. **Merge Conflicts:** Work on one feature at a time, commit frequently
2. **Breaking Changes:** Maintain backward compatibility during refactor
3. **Testing Overhead:** Write tests BEFORE refactoring critical paths
4. **Performance Regression:** Benchmark before/after each optimization

---

## Post-Refactoring Checklist

- [ ] Run `flutter analyze` - zero issues
- [ ] Run all tests - 100% passing
- [ ] Performance profiling - targets met
- [ ] Update ARCHITECTURE.md documentation
- [ ] Update CHANGELOG.md
- [ ] Code review by team
- [ ] Merge to main branch
- [ ] Monitor production metrics for 1 week

---

**END OF REFACTORING PLAN**
