# BLoC Separation Migration Guide

**Status:** IN PROGRESS
**Date:** January 2025

---

## ✅ Completed Steps

### Phase 1-3: BLoC Creation ✅
**Files Created:**
1. ✅ `lib/features/home/presentation/bloc/home_event.dart`
2. ✅ `lib/features/home/presentation/bloc/home_state.dart`
3. ✅ `lib/features/home/presentation/bloc/home_bloc.dart`
4. ✅ `lib/features/question_bank/presentation/bloc/question_bank_event.dart`
5. ✅ `lib/features/question_bank/presentation/bloc/question_bank_state.dart`
6. ✅ `lib/features/question_bank/presentation/bloc/question_bank_bloc.dart`

---

## 🔄 Next Steps

### Phase 4: Update home_page.dart

**File:** `lib/features/home/presentation/pages/home_page.dart`

#### Changes Required:

**1. Import Changes:**
```dart
// REMOVE:
import '../../../paper_workflow/presentation/bloc/question_paper_bloc.dart';

// ADD:
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
```

**2. Remove Caching Variable (Line ~37):**
```dart
// REMOVE this line:
QuestionPaperLoaded? _cachedPaperState;

// Replace with:
HomeLoaded? _cachedHomeState;
```

**3. Update _loadInitialData() method (Line ~87):**
```dart
// REPLACE:
void _loadInitialData() {
  final authState = context.read<AuthBloc>().state;
  if (authState is! AuthAuthenticated) return;

  final bloc = context.read<QuestionPaperBloc>();
  final isAdmin = authState.user.role == UserRole.admin;

  if (isAdmin) {
    bloc.add(const LoadPapersForReview());
  } else {
    bloc.add(const LoadAllTeacherPapers());
    context.read<NotificationBloc>().add(LoadUnreadCount(authState.user.id));
  }
}

// WITH:
void _loadInitialData() {
  final authState = context.read<AuthBloc>().state;
  if (authState is! AuthAuthenticated) return;

  final isAdmin = authState.user.role == UserRole.admin;

  context.read<HomeBloc>().add(LoadHomePapers(
    isAdmin: isAdmin,
    userId: isAdmin ? null : authState.user.id,
  ));

  if (!isAdmin) {
    context.read<NotificationBloc>().add(LoadUnreadCount(authState.user.id));
  }
}
```

**4. Update _handleRefresh() method:**
```dart
// Find _handleRefresh() and REPLACE:
Future<void> _handleRefresh() async {
  setState(() => _isRefreshing = true);
  try {
    _loadInitialData();
    await Future.delayed(const Duration(milliseconds: 800));
  } finally {
    if (mounted) setState(() => _isRefreshing = false);
  }
}

// WITH:
Future<void> _handleRefresh() async {
  setState(() => _isRefreshing = true);
  try {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final isAdmin = authState.user.role == UserRole.admin;
      context.read<HomeBloc>().add(RefreshHomePapers(
        isAdmin: isAdmin,
        userId: isAdmin ? null : authState.user.id,
      ));
    }
    await Future.delayed(const Duration(milliseconds: 800));
  } finally {
    if (mounted) setState(() => _isRefreshing = false);
  }
}
```

**5. Update didChangeDependencies() for auto-reload (Line ~81):**
```dart
// REPLACE:
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  // No automatic reload - data persists across navigation
  // User can pull-to-refresh if needed
}

// WITH:
@override
void didChangeDependencies() {
  super.didChangeDependencies();

  // Auto-reload if coming from another page with stale data
  final currentState = context.read<HomeBloc>().state;
  if (currentState is! HomeLoaded && currentState is! HomeLoading) {
    _loadInitialData();
  }
}
```

**6. Update _buildContent() BlocBuilder (Line ~227):**
```dart
// REPLACE entire BlocBuilder:
sliver: BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
  buildWhen: (previous, current) {
    if (current is QuestionPaperLoading ||
        current is QuestionPaperLoaded ||
        current is QuestionPaperError) {
      return true;
    }
    return false;
  },
  builder: (context, state) {
    // ... existing logic
  },
),

// WITH:
sliver: BlocBuilder<HomeBloc, HomeState>(
  builder: (context, state) {
    if (state is HomeLoading) {
      // Show cached data during loading if available
      if (_cachedHomeState != null) {
        final papers = _getAllPapers(_cachedHomeState!, isAdmin);
        return _buildPapersList(papers, isAdmin);
      }
      return _buildLoading();
    }

    if (state is HomeError) {
      // Show cached data on error if available
      if (_cachedHomeState != null) {
        final papers = _getAllPapers(_cachedHomeState!, isAdmin);
        return _buildPapersList(papers, isAdmin);
      }
      return _buildError(state.message);
    }

    if (state is HomeLoaded) {
      // Cache this state
      _cachedHomeState = state;
      final papers = _getAllPapers(state, isAdmin);
      return _buildPapersList(papers, isAdmin);
    }

    // Fallback: show cached or empty
    if (_cachedHomeState != null) {
      final papers = _getAllPapers(_cachedHomeState!, isAdmin);
      return _buildPapersList(papers, isAdmin);
    }

    return _buildEmpty(isAdmin);
  },
),
```

**7. Update _getAllPapers() method signature (Line ~623):**
```dart
// REPLACE:
List<QuestionPaperEntity> _getAllPapers(QuestionPaperLoaded state, bool isAdmin) {
  if (isAdmin) {
    return [
      ...state.papersForReview,
      ...state.allPapersForAdmin,
    ];
  } else {
    return [
      ...state.drafts,
      ...state.submissions,
    ];
  }
}

// WITH:
List<QuestionPaperEntity> _getAllPapers(HomeLoaded state, bool isAdmin) {
  if (isAdmin) {
    return [
      ...state.papersForReview,
      ...state.allPapersForAdmin,
    ];
  } else {
    return [
      ...state.drafts,
      ...state.submissions,
    ];
  }
}
```

**8. Update Duplicate Paper action (Line ~722):**
```dart
// This line likely needs to stay with QuestionPaperBloc since it's a workflow action
// Keep as is: context.read<QuestionPaperBloc>().add(SaveDraft(duplicatedPaper));
```

---

### Phase 5: Update question_bank_page.dart

**File:** `lib/features/question_bank/presentation/pages/question_bank_page.dart`

#### Changes Required:

**1. Import Changes:**
```dart
// ADD:
import '../bloc/question_bank_bloc.dart';
import '../bloc/question_bank_event.dart';
import '../bloc/question_bank_state.dart';

// Note: Keep QuestionPaperBloc import if it's used for other actions
```

**2. Update State Variables (Line ~69-70):**
```dart
// REPLACE:
ApprovedPapersPaginated? _cachedPaginatedState;

// WITH:
QuestionBankLoaded? _cachedQuestionBankState;
```

**3. Update _loadInitialData() method (Line ~129):**
```dart
// REPLACE the event dispatch at end of method:
context.read<QuestionPaperBloc>().add(LoadApprovedPapersPaginated(
  page: _currentPage,
  pageSize: _pageSize,
  searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
  subjectFilter: subjectFilter,
  gradeFilter: gradeFilter,
  isLoadMore: false,
));

// WITH:
context.read<QuestionBankBloc>().add(LoadQuestionBankPaginated(
  page: _currentPage,
  pageSize: _pageSize,
  searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
  subjectFilter: subjectFilter,
  gradeFilter: gradeFilter,
  isLoadMore: false,
));
```

**4. Update _loadMore() method (Line ~115):**
```dart
// REPLACE:
void _loadMore() {
  final state = context.read<QuestionPaperBloc>().state;
  if (state is ApprovedPapersPaginated && state.hasMore && !state.isLoadingMore) {
    context.read<QuestionPaperBloc>().add(LoadApprovedPapersPaginated(
      page: state.currentPage + 1,
      pageSize: _pageSize,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      subjectFilter: _selectedSubjectId,
      gradeFilter: _selectedGradeLevel?.toString(),
      isLoadMore: true,
    ));
  }
}

// WITH:
void _loadMore() {
  final state = context.read<QuestionBankBloc>().state;
  if (state is QuestionBankLoaded && state.hasMore && !state.isLoadingMore) {
    context.read<QuestionBankBloc>().add(LoadQuestionBankPaginated(
      page: state.currentPage + 1,
      pageSize: _pageSize,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      subjectFilter: _selectedSubjectId,
      gradeFilter: _selectedGradeLevel?.toString(),
      isLoadMore: true,
    ));
  }
}
```

**5. Update _onRefresh() method (Line ~206):**
```dart
// REPLACE:
Future<void> _onRefresh() async {
  if (_isRefreshing) return;
  setState(() => _isRefreshing = true);
  try {
    _loadInitialData();
    await Future.delayed(const Duration(milliseconds: 800));
  } finally {
    if (mounted) setState(() => _isRefreshing = false);
  }
}

// WITH:
Future<void> _onRefresh() async {
  if (_isRefreshing) return;
  setState(() => _isRefreshing = true);
  try {
    context.read<QuestionBankBloc>().add(RefreshQuestionBank(
      pageSize: _pageSize,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      subjectFilter: _selectedSubjectId,
      gradeFilter: _selectedGradeLevel?.toString(),
    ));
    await Future.delayed(const Duration(milliseconds: 800));
  } finally {
    if (mounted) setState(() => _isRefreshing = false);
  }
}
```

**6. Update didChangeDependencies() for auto-reload (Line ~87):**
```dart
// REPLACE:
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  // No automatic reload - data persists across navigation
  // User can pull-to-refresh if needed
}

// WITH:
@override
void didChangeDependencies() {
  super.didChangeDependencies();

  // Auto-reload if coming from another page with stale data
  final currentState = context.read<QuestionBankBloc>().state;
  if (currentState is! QuestionBankLoaded && currentState is! QuestionBankLoading) {
    _loadInitialData();
  }
}
```

**7. Update _buildContent() BlocBuilder (Line ~395):**
```dart
// REPLACE:
return BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
  builder: (context, state) {
    if (state is ApprovedPapersPaginated) {
      _cachedPaginatedState = state;
      // ... existing logic
    }

    if (state is QuestionPaperLoaded) {
      // ... existing logic
    }

    if (_cachedPaginatedState != null) {
      // ... existing logic
    }

    return // ... empty state
  },
);

// WITH:
return BlocBuilder<QuestionBankBloc, QuestionBankState>(
  builder: (context, state) {
    if (state is QuestionBankLoading) {
      // Show cached data during loading
      if (_cachedQuestionBankState != null) {
        return _buildPaginatedView(_cachedQuestionBankState!);
      }
      return _buildLoading();
    }

    if (state is QuestionBankLoaded) {
      _cachedQuestionBankState = state;
      return _buildPaginatedView(state);
    }

    if (state is QuestionBankError) {
      // Show cached data on error
      if (_cachedQuestionBankState != null) {
        return _buildPaginatedView(_cachedQuestionBankState!);
      }
      return _buildError(state.message);
    }

    // Fallback: cached or empty
    if (_cachedQuestionBankState != null) {
      return _buildPaginatedView(_cachedQuestionBankState!);
    }

    return _buildEmpty();
  },
);

// Helper method to extract:
Widget _buildPaginatedView(QuestionBankLoaded state) {
  return RefreshIndicator(
    onRefresh: _onRefresh,
    color: AppColors.primary,
    backgroundColor: AppColors.surface,
    child: TabBarView(
      controller: _tabController,
      children: [
        _buildPaginatedPapersForPeriod(state, 'current'),
        _buildPaginatedPapersForPeriod(state, 'previous'),
        _buildPaginatedArchiveView(state),
      ],
    ),
  );
}
```

**8. Update _buildPaginatedPapersForPeriod() signature:**
```dart
// Change parameter type from ApprovedPapersPaginated to QuestionBankLoaded
Widget _buildPaginatedPapersForPeriod(QuestionBankLoaded state, String period) {
  // ... rest of method stays same
}
```

---

### Phase 6: Register BLoCs in Dependency Injection

**File:** `lib/core/infrastructure/di/injection_container.dart`

**Add these registrations:**
```dart
// Find where QuestionPaperBloc is registered and ADD nearby:

// Home BLoC
sl.registerFactory(() => HomeBloc(
  getDraftsUseCase: sl(),
  getSubmissionsUseCase: sl(),
  getPapersForReviewUseCase: sl(),
  getAllPapersForAdminUseCase: sl(),
));

// Question Bank BLoC
sl.registerFactory(() => QuestionBankBloc(
  getApprovedPapersPaginatedUseCase: sl(),
));
```

---

### Phase 7: Update BlocProviders

**Check these files for BlocProvider usage:**
1. `lib/core/presentation/routes/app_routes.dart` (or router config)
2. `lib/main.dart`
3. Any place where HomePage or QuestionBankPage is wrapped with BlocProvider

**Add providers:**
```dart
MultiBlocProvider(
  providers: [
    BlocProvider(create: (context) => sl<HomeBloc>()),
    BlocProvider(create: (context) => sl<QuestionBankBloc>()),
    // ... existing providers
  ],
  child: YourApp(),
)
```

---

## 🧪 Testing Checklist

After implementation:
- [ ] Home page loads correctly for admin
- [ ] Home page loads correctly for teacher
- [ ] Question bank loads correctly
- [ ] Navigate Home → Question Bank → Home (data persists)
- [ ] Navigate Question Bank → Home → Question Bank (data persists)
- [ ] Pull-to-refresh works on both pages
- [ ] Pagination works in question bank
- [ ] Search/filters work in question bank
- [ ] No empty pages when navigating back and forth
- [ ] Loading states show correctly
- [ ] Error states show correctly

---

## 📝 Summary of Changes

**Files Created:** 6 new BLoC files
**Files Modified:** 3 (home_page.dart, question_bank_page.dart, injection_container.dart)
**Lines Changed:** ~200 lines total

**Result:** Complete isolation between Home and Question Bank - no more state conflicts!
