import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:papercraft/features/pdf_generation/presentation/pages/pdf_preview_page.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/utils/ui_helpers.dart';
import '../../../assignments/presentation/bloc/teacher_preferences_bloc.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../catalog/presentation/bloc/grade_bloc.dart';
import '../../../catalog/presentation/bloc/subject_bloc.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../pdf_generation/domain/services/pdf_generation_service.dart';
import '../../../paper_workflow/domain/services/user_info_service.dart';
import '../bloc/question_bank_bloc.dart';
import '../bloc/question_bank_event.dart';
import '../bloc/question_bank_state.dart';
import '../widgets/paper_card/approved_paper_card.dart';
import '../widgets/filter_panel/filter_panel.dart';
import '../widgets/search_bar/paper_search_bar.dart';

class QuestionBankPage extends StatefulWidget {
  const QuestionBankPage({super.key});

  @override
  State<QuestionBankPage> createState() => _QuestionBankState();
}

class _QuestionBankState extends State<QuestionBankPage> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late TabController _tabController;

  // Search and filter state
  String _searchQuery = '';
  int? _selectedGradeLevel;
  String? _selectedSubjectId;
  bool _isGeneratingPdf = false;
  String? _generatingPdfFor;

  // Pagination state
  int _currentPage = 1;
  final int _pageSize = 20;
  final ScrollController _scrollController = ScrollController();

  // Search debounce
  Timer? _searchDebounce;

  // Dynamic data from BLoCs
  List<int> _availableGradeLevels = [];
  List<SubjectEntity> _availableSubjects = [];
  bool _isRefreshing = false;

  // User name cache
  final Map<String, String> _userNamesCache = {};
  final UserInfoService _userInfoService = sl<UserInfoService>();

  // Cache the last valid QuestionBankLoaded state to preserve data across navigation
  QuestionBankLoaded? _cachedQuestionBankState;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _tabController = TabController(length: 3, vsync: this);
    _animController.forward();

    // Load data in postFrameCallback to ensure BLoCs are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitialData();
      }
    });

    // Setup scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Auto-reload if coming from another page with stale data
    final currentState = context.read<QuestionBankBloc>().state;
    if (currentState is! QuestionBankLoaded && currentState is! QuestionBankLoading) {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    _tabController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    // Clear caches on disposal (e.g., logout)
    _userNamesCache.clear();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      // Load more when scrolled to 80% of the list
      _loadMore();
    }
  }

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

  Future<void> _loadInitialData() async {
    // Reset to first page
    _currentPage = 1;

    if (kDebugMode) {
      print('🔵 [QuestionBankPage] _loadInitialData called');
      print('   Current BLoC state: ${context.read<QuestionBankBloc>().state.runtimeType}');
      print('   Filters: grade=$_selectedGradeLevel, subject=$_selectedSubjectId, search=$_searchQuery');
    }

    // Dispatch BLoC event immediately (BLoC handles teacher assignment logic)
    context.read<QuestionBankBloc>().add(LoadQuestionBankPaginated(
      page: _currentPage,
      pageSize: _pageSize,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      subjectFilter: _selectedSubjectId,
      gradeFilter: _selectedGradeLevel?.toString(),
      isLoadMore: false,
    ));

    // Enable realtime updates for instant paper changes
    context.read<QuestionBankBloc>().add(const EnableQuestionBankRealtime());

    if (kDebugMode) {
      print('🔵 [QuestionBankPage] Event dispatched to QuestionBankBloc');
    }

    context.read<GradeBloc>().add(const LoadGradeLevels());
    context.read<SubjectBloc>().add(const LoadSubjects());
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;

    if (!mounted) return;
    setState(() => _isRefreshing = true);

    try {
      context.read<QuestionBankBloc>().add(RefreshQuestionBank(
        pageSize: _pageSize,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        subjectFilter: _selectedSubjectId,
        gradeFilter: _selectedGradeLevel?.toString(),
      ));
      // Reduced delay from 2s to 800ms for better UX
      await Future.delayed(const Duration(milliseconds: 800));
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // Listen to teacher preferences and auto-apply filters
        BlocListener<TeacherPreferencesBloc, TeacherPreferencesState>(
          listener: (context, state) {
            if (state is TeacherPreferencesLoaded) {
              // Only auto-apply if filters are available and user hasn't manually selected any
              if (state.hasFilters &&
                  _selectedGradeLevel == null &&
                  _selectedSubjectId == null) {
                if (!mounted) return;
                setState(() {
                  if (state.defaultGradeFilter != null) {
                    _selectedGradeLevel = int.tryParse(state.defaultGradeFilter!);
                  }
                  if (state.defaultSubjectFilter != null) {
                    _selectedSubjectId = state.defaultSubjectFilter;
                  }
                });
                // Reload data with teacher-specific filters
                _loadInitialData();
              }
            }
          },
        ),
        BlocListener<GradeBloc, GradeState>(
          listener: (context, state) {
            if (state is GradeLevelsLoaded) {
              if (!mounted) return;
              setState(() {
                _availableGradeLevels = state.gradeLevels;
                if (_selectedGradeLevel != null &&
                    !state.gradeLevels.contains(_selectedGradeLevel)) {
                  _selectedGradeLevel = null;
                }
              });
            }
          },
        ),
        BlocListener<SubjectBloc, SubjectState>(
          listener: (context, state) {
            if (state is SubjectsLoaded) {
              if (!mounted) return;
              setState(() {
                _availableSubjects = state.subjects;
                if (_selectedSubjectId != null &&
                    !state.subjects.any((s) => s.id == _selectedSubjectId)) {
                  _selectedSubjectId = null;
                }
              });
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            children: [
              _buildSearchAndFilters(),
              _buildModernTabs(),
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: UIConstants.spacing12),
          _buildFilterChips(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: PaperSearchBar(
            controller: _searchController,
            searchQuery: _searchQuery,
            onSearchChanged: (query) {
              if (!mounted) return;
              setState(() => _searchQuery = query);

              // Debounce search - wait 500ms before triggering search
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _loadInitialData();
                }
              });
            },
            onClearSearch: _clearSearch,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            Icons.refresh_rounded,
            color: _isRefreshing ? AppColors.primary : AppColors.textSecondary,
          ),
          onPressed: _isRefreshing ? null : _onRefresh,
          tooltip: 'Refresh',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.backgroundSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return FilterPanel(
      selectedGradeLevel: _selectedGradeLevel,
      selectedSubjectId: _selectedSubjectId,
      availableGradeLevels: _availableGradeLevels,
      availableSubjects: _availableSubjects,
      onGradeChanged: (value) {
        if (!mounted) return;
        setState(() {
          _selectedGradeLevel = value;
          _currentPage = 1; // Reset pagination
        });
        _loadInitialData();
      },
      onSubjectChanged: (value) {
        if (!mounted) return;
        setState(() {
          _selectedSubjectId = value;
          _currentPage = 1; // Reset pagination
        });
        _loadInitialData();
      },
      onClearFilters: _clearAllFilters,
      hasActiveFilters: _hasActiveFilters(),
    );
  }

  Widget _buildModernTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'This Month'),
          Tab(text: 'Previous'),
          Tab(text: 'Archive'),
        ],
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: UIConstants.fontSizeSmall),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: UIConstants.fontSizeSmall),
        dividerColor: Colors.transparent,
      ),
    );
  }

  Widget _buildContent() {
    return BlocConsumer<QuestionBankBloc, QuestionBankState>(
      listener: (context, state) {
        if (state is QuestionBankError) {
          UiHelpers.showErrorMessage(context, state.message);
        } else if (state is QuestionBankLoaded) {
          _loadUserNamesForPapers(state.papers);
        }
      },
      builder: (context, state) {
        if (kDebugMode) {
          print('🟢 [QuestionBankPage] Builder called with state: ${state.runtimeType}');
        }

        // Initial state - show loading
        if (state is QuestionBankInitial) {
          if (kDebugMode) print('🟡 [QuestionBankPage] Showing loading for Initial state');
          return _buildModernLoading();
        }

        if (state is QuestionBankLoading) {
          if (kDebugMode) print('🟡 [QuestionBankPage] Showing loading for Loading state');
          // Show cached data during loading if available
          if (_cachedQuestionBankState != null) {
            return _buildPaginatedView(_cachedQuestionBankState!);
          }
          return _buildModernLoading();
        }

        if (state is QuestionBankLoaded) {
          if (kDebugMode) print('🟢 [QuestionBankPage] Showing data for Loaded state (${state.papers.length} papers)');
          _cachedQuestionBankState = state;
          return _buildPaginatedView(state);
        }

        if (state is QuestionBankError) {
          if (kDebugMode) print('🔴 [QuestionBankPage] Showing error: ${state.message}');
          // Show cached data on error if available
          if (_cachedQuestionBankState != null) {
            return _buildPaginatedView(_cachedQuestionBankState!);
          }
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Center(
                child: Text(state.message),
              ),
            ),
          );
        }

        // Fallback: show cached or empty
        if (_cachedQuestionBankState != null) {
          return _buildPaginatedView(_cachedQuestionBankState!);
        }

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _buildModernEmpty(),
          ),
        );
      },
    );
  }

  Widget _buildPaginatedView(QuestionBankLoaded state) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildPaginatedPapersForPeriod(state, 'current'),
        _buildPaginatedPapersForPeriod(state, 'previous'),
        _buildPaginatedArchiveView(state),
      ],
    );
  }

  List<QuestionPaperEntity> _filterPapersByPeriod(List<QuestionPaperEntity> papers, String period) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final previousMonth = DateTime(now.year, now.month - 1);

    // Performance optimization: early return if no filters
    final hasSearchQuery = _searchQuery.isNotEmpty;
    final hasGradeFilter = _selectedGradeLevel != null;
    final hasSubjectFilter = _selectedSubjectId != null;
    final searchLower = hasSearchQuery ? _searchQuery.toLowerCase() : '';

    return papers.where((paper) {
      if (!paper.status.isApproved) return false;

      // Check filters first (faster checks)
      if (hasGradeFilter && paper.gradeLevel != _selectedGradeLevel) return false;

      if (hasSubjectFilter && !_availableSubjects.any(
              (subject) => subject.id == _selectedSubjectId && subject.name == paper.subject
      )) return false;

      // Search check (more expensive)
      if (hasSearchQuery) {
        final titleMatches = paper.title.toLowerCase().contains(searchLower);
        final subjectMatches = paper.subject?.toLowerCase().contains(searchLower) ?? false;
        final examTypeMatches = paper.examType.displayName.toLowerCase().contains(searchLower);
        final creatorMatches = paper.createdBy.toLowerCase().contains(searchLower);
        final userNameMatches = _userNamesCache[paper.createdBy]?.toLowerCase().contains(searchLower) ?? false;

        if (!titleMatches && !subjectMatches && !examTypeMatches && !creatorMatches && !userNameMatches) {
          return false;
        }
      }

      // Period check
      final paperDate = paper.reviewedAt ?? paper.createdAt;
      final paperMonth = DateTime(paperDate.year, paperDate.month);

      switch (period) {
        case 'current': return paperMonth.isAtSameMomentAs(currentMonth);
        case 'previous': return paperMonth.isAtSameMomentAs(previousMonth);
        case 'archive': return paperMonth.isBefore(previousMonth);
        default: return true;
      }
    }).toList();
  }

  Widget _buildPapersForPeriod(List<QuestionPaperEntity> allPapers, String period) {
    final papers = _filterPapersByPeriod(allPapers, period);
    final groupedPapers = _groupPapersByClass(papers);

    if (papers.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: _buildEmptyForPeriod(period),
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildStatsHeader(papers.length)),
        ...groupedPapers.entries.map((entry) => _buildModernClassSection(entry.key, entry.value)),
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }

  Widget _buildArchiveView(List<QuestionPaperEntity> allPapers) {
    final archivedPapers = _filterPapersByPeriod(allPapers, 'archive');
    final groupedByMonth = _groupPapersByMonth(archivedPapers);

    if (archivedPapers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _buildEmptyForPeriod('archive'),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildStatsHeader(archivedPapers.length)),
          ...groupedByMonth.entries.map((entry) => _buildMonthSection(entry.key, entry.value)),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _buildMonthSection(String monthYear, List<QuestionPaperEntity> papers) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(UIConstants.paddingSmall),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    monthYear,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
                  ),
                  child: Text(
                    '${papers.length}',
                    style: TextStyle(color: AppColors.accent, fontSize: UIConstants.fontSizeSmall, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildModernPaperCard(papers[index]),
              childCount: papers.length,
              addAutomaticKeepAlives: true,
              addRepaintBoundaries: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader(int paperCount) {
    return Container(
      margin: const EdgeInsets.all(UIConstants.paddingMedium),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient.scale(0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            ),
            child: Icon(Icons.assessment, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$paperCount Papers Available',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: UIConstants.fontSizeMedium, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Ready for download and preview',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (_hasActiveFilters())
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
              ),
              child: Text(
                'Filtered',
                style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernClassSection(String className, List<QuestionPaperEntity> papers) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(UIConstants.paddingSmall),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    className,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
                  ),
                  child: Text(
                    '${papers.length}',
                    style: TextStyle(color: AppColors.accent, fontSize: UIConstants.fontSizeSmall, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildModernPaperCard(papers[index]),
              childCount: papers.length,
              addAutomaticKeepAlives: true,
              addRepaintBoundaries: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernPaperCard(QuestionPaperEntity paper) {
    final isGenerating = _isGeneratingPdf && _generatingPdfFor == paper.id;
    final creatorName = _userNamesCache[paper.createdBy] ?? 'Loading...';

    return ApprovedPaperCard(
      paper: paper,
      creatorName: creatorName,
      isGeneratingPdf: isGenerating,
      onPreview: () => _showPreviewOptions(paper),
    );
  }

  // Removed: _buildModernTag, _buildStatusBadge, _buildModernMetric, _buildModernActions, _buildActionButton
  // These methods are now in the ApprovedPaperCard widget and its sub-components

  Widget _buildEmptyForPeriod(String period) {
    String title, description;
    IconData icon;

    switch (period) {
      case 'current':
        title = 'No Papers This Month';
        description = 'Papers approved this month will appear here';
        icon = Icons.calendar_today;
        break;
      case 'previous':
        title = 'No Papers Last Month';
        description = 'Papers from last month will appear here';
        icon = Icons.calendar_month;
        break;
      default:
        title = 'No Archived Papers';
        description = 'Older papers will appear here';
        icon = Icons.archive;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(UIConstants.radiusXXLarge),
            ),
            child: Icon(icon, size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: UIConstants.spacing20),
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: UIConstants.spacing6),
          Text(
            description,
            style: TextStyle(color: AppColors.textSecondary, fontSize: UIConstants.fontSizeSmall),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: UIConstants.spacing12),
          Text(
            'Pull down to refresh',
            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildModernLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
            ),
            child: const Icon(Icons.library_books, color: Colors.white, size: 24),
          ),
          const SizedBox(height: UIConstants.spacing20),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: UIConstants.spacing12),
          Text(
            'Loading papers...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: UIConstants.fontSizeMedium, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildModernEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.library_books_outlined, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: UIConstants.spacing20),
          Text(
            'No Papers Available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: UIConstants.spacing6),
          Text(
            'Approved papers will appear here',
            style: TextStyle(color: AppColors.textSecondary, fontSize: UIConstants.fontSizeMedium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: UIConstants.spacing12),
          Text(
            'Pull down to refresh',
            style: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7), fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Helper methods
  bool _hasActiveFilters() => _selectedGradeLevel != null || _selectedSubjectId != null;

  void _clearSearch() {
    _searchController.clear();
    if (!mounted) return;
    setState(() => _searchQuery = '');
  }

  void _clearAllFilters() {
    _clearSearch();
    if (!mounted) return;
    setState(() {
      _selectedGradeLevel = null;
      _selectedSubjectId = null;
    });
  }

  Map<String, List<QuestionPaperEntity>> _groupPapersByClass(List<QuestionPaperEntity> papers) {
    final grouped = <String, List<QuestionPaperEntity>>{};

    for (final paper in papers) {
      final className = paper.gradeDisplayName;
      grouped.putIfAbsent(className, () => []).add(paper);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final aGrade = _extractGradeNumber(a);
        final bGrade = _extractGradeNumber(b);
        if (aGrade != null && bGrade != null) {
          return aGrade.compareTo(bGrade);
        }
        return a.compareTo(b);
      });

    final sortedGrouped = <String, List<QuestionPaperEntity>>{};
    for (final key in sortedKeys) {
      grouped[key]!.sort((a, b) => (b.reviewedAt ?? b.createdAt).compareTo(a.reviewedAt ?? a.createdAt));
      sortedGrouped[key] = grouped[key]!;
    }

    return sortedGrouped;
  }

  int? _extractGradeNumber(String gradeDisplay) {
    final match = RegExp(r'Grade (\d+)').firstMatch(gradeDisplay);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  Map<String, List<QuestionPaperEntity>> _groupPapersByMonth(List<QuestionPaperEntity> papers) {
    final grouped = <String, List<QuestionPaperEntity>>{};

    for (final paper in papers) {
      final date = paper.reviewedAt ?? paper.createdAt;
      final monthYear = '${_getMonthName(date.month)} ${date.year}';
      grouped.putIfAbsent(monthYear, () => []).add(paper);
    }

    final sortedGrouped = <String, List<QuestionPaperEntity>>{};
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final aDate = grouped[a]!.first.reviewedAt ?? grouped[a]!.first.createdAt;
        final bDate = grouped[b]!.first.reviewedAt ?? grouped[b]!.first.createdAt;
        return bDate.compareTo(aDate);
      });

    for (final key in sortedKeys) {
      grouped[key]!.sort((a, b) => (b.reviewedAt ?? b.createdAt).compareTo(a.reviewedAt ?? a.createdAt));
      sortedGrouped[key] = grouped[key]!;
    }

    return sortedGrouped;
  }

  String _getMonthName(int month) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month];
  }

  Future<void> _loadUserNamesForPapers(List<QuestionPaperEntity> papers) async {
    final userIds = papers.map((paper) => paper.createdBy).toSet().toList();
    final uncachedIds = userIds.where((id) => !_userNamesCache.containsKey(id)).toList();

    if (uncachedIds.isNotEmpty) {
      try {
        final userNames = await _userInfoService.getUserFullNames(uncachedIds);

        if (mounted) {
          setState(() {
            _userNamesCache.addAll(userNames);
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            for (final id in uncachedIds) {
              _userNamesCache[id] = 'User ${id.substring(0, 8)}...';
            }
          });
        }
      }
    }
  }

  void _showPreviewOptions(QuestionPaperEntity paper) {
    // Generate single layout PDF and show preview
    _generateAndHandlePdf(paper, 'single', true);  // true = show preview
  }

  Future<void> _generateAndHandlePdf(
    QuestionPaperEntity paper,
    String layoutType,
    bool showPreview,
    {String dualMode = 'balanced'}
  ) async {
    try {
      bool cancelRequested = false;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: UIConstants.spacing16),
                Text(
                  'Generating PDF...',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeMedium,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: UIConstants.spacing8),
                Text(
                  layoutType == 'single'
                      ? 'Creating single page layout'
                      : dualMode == 'compressed'
                          ? 'Creating compressed side-by-side layout'
                          : 'Creating balanced side-by-side layout',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  cancelRequested = true;
                  Navigator.pop(context);
                },
                child: Text('Cancel', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ),
      );

      final pdfService = SimplePdfService();
      final userStateService = sl<UserStateService>();
      final schoolName = userStateService.schoolName;

      final pdfBytes = layoutType == 'single'
          ? await pdfService.generateStudentPdf(paper: paper, schoolName: schoolName)
          : await pdfService.generateDualLayoutPdf(
              paper: paper,
              schoolName: schoolName,
              mode: dualMode == 'compressed' ? DualLayoutMode.compressed : DualLayoutMode.balanced,
            );

      if (!mounted || cancelRequested) return;

      Navigator.of(context).pop();

      if (showPreview) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfPreviewPage(
              pdfBytes: pdfBytes,
              paperTitle: paper.title,
              layoutType: layoutType,
              onRegeneratePdf: layoutType == 'single'
                  ? (fontMultiplier, spacingMultiplier) async {
                      return await pdfService.generateStudentPdf(
                        paper: paper,
                        schoolName: schoolName,
                        fontSizeMultiplier: fontMultiplier,
                        spacingMultiplier: spacingMultiplier,
                      );
                    }
                  : null,
            ),
          ),
        );
      } else {
        await _downloadPdfFromBank(pdfBytes, paper.title, layoutType);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        _showMessage('Unable to generate PDF. Please try again.', AppColors.error);
      }
    }
  }

  Future<void> _downloadPdfFromBank(Uint8List pdfBytes, String paperTitle, String layoutType) async {
    try {
      final layoutSuffix = layoutType == 'single' ? 'Single' : 'Dual';
      final fileName = '${paperTitle.replaceAll(RegExp(r'[^\w\s-]'), '')}_${layoutSuffix}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      File? savedFile;

      if (Platform.isAndroid) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final downloadsPath = Directory('${directory.path}/Download');
          if (!await downloadsPath.exists()) {
            await downloadsPath.create(recursive: true);
          }
          savedFile = File('${downloadsPath.path}/$fileName');
        }
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        savedFile = File('${directory.path}/$fileName');
      }

      if (savedFile != null) {
        await savedFile.writeAsBytes(pdfBytes);
        await _shareInsteadOfOpen(savedFile);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Unable to save PDF. Please check storage permissions.', AppColors.error);
      }
    }
  }


  Future<void> _shareInsteadOfOpen(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: 'Open with PDF viewer',
        subject: 'Question Paper',
      );

      if (mounted) {
        _showMessage('PDF saved and shared - select your PDF viewer', AppColors.success);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Cannot open PDF. Please install a PDF viewer app.', AppColors.warning);
      }
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UIConstants.radiusMedium)),
      ),
    );
  }

  // ========== PAGINATED BUILDERS ==========

  Widget _buildPaginatedPapersForPeriod(QuestionBankLoaded state, String period) {
    final papers = _filterPapersByPeriod(state.papers, period);
    final groupedPapers = _groupPapersByClass(papers);

    if (papers.isEmpty && !state.isLoadingMore) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: _buildEmptyForPeriod(period),
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildStatsHeader(papers.length)),
        ...groupedPapers.entries.map((entry) => _buildModernClassSection(entry.key, entry.value)),
        if (state.isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),
        if (!state.hasMore && state.papers.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No more papers',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }

  Widget _buildPaginatedArchiveView(QuestionBankLoaded state) {
    final archivedPapers = _filterPapersByPeriod(state.papers, 'archive');
    final groupedByMonth = _groupPapersByMonth(archivedPapers);

    if (archivedPapers.isEmpty && !state.isLoadingMore) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: _buildEmptyForPeriod('archive'),
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildStatsHeader(archivedPapers.length)),
        ...groupedByMonth.entries.map((entry) => _buildMonthSection(entry.key, entry.value)),
        if (state.isLoadingMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          ),
        if (!state.hasMore && state.papers.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No more papers',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
      ],
    );
  }
}