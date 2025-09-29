import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:papercraft/features/question_papers/presentation/pages/pdf_preview_page.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/services/pdf_generation_service.dart';
import '../../domain/services/user_info_service.dart';
import '../bloc/question_paper_bloc.dart';
import '../bloc/grade_bloc.dart';
import '../bloc/subject_bloc.dart';

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

  // Dynamic data from BLoCs
  List<int> _availableGradeLevels = [];
  List<SubjectEntity> _availableSubjects = [];
  bool _isRefreshing = false;

  // User name cache
  final Map<String, String> _userNamesCache = {};
  final UserInfoService _userInfoService = sl<UserInfoService>();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _tabController = TabController(length: 3, vsync: this);
    _animController.forward();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    context.read<QuestionPaperBloc>().add(const LoadApprovedPapers());
    context.read<GradeBloc>().add(const LoadGradeLevels());
    context.read<SubjectBloc>().add(const LoadSubjects());
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      // Simplified refresh - just trigger all loads and wait
      _loadInitialData();

      // Wait a reasonable amount of time for the data to load
      await Future.delayed(const Duration(seconds: 2));

    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildFilterChips(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search papers, subjects...',
          hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            onPressed: _clearSearch,
            icon: Icon(Icons.clear, color: AppColors.textSecondary, size: 20),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: const TextStyle(fontSize: 14),
        onChanged: (query) => setState(() => _searchQuery = query),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildGradeFilter(),
          const SizedBox(width: 8),
          _buildSubjectFilter(),
          if (_hasActiveFilters()) ...[
            const SizedBox(width: 8),
            _buildClearButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildGradeFilter() {
    return BlocConsumer<GradeBloc, GradeState>(
      listener: (context, state) {
        if (state is GradeLevelsLoaded) {
          setState(() {
            _availableGradeLevels = state.gradeLevels;
            if (_selectedGradeLevel != null &&
                !state.gradeLevels.contains(_selectedGradeLevel)) {
              _selectedGradeLevel = null;
            }
          });
        }
      },
      builder: (context, state) {
        if (state is GradeLoading) return _buildLoadingChip('Grade');
        if (state is GradeError) return _buildErrorChip('Grade', () => context.read<GradeBloc>().add(const LoadGradeLevels()));

        return _buildFilterChip<int>(
          label: 'Grade',
          value: _selectedGradeLevel,
          options: _availableGradeLevels.map((level) =>
              DropdownMenuItem(value: level, child: Text('Grade $level', style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: (value) => setState(() => _selectedGradeLevel = value),
        );
      },
    );
  }

  Widget _buildSubjectFilter() {
    return BlocConsumer<SubjectBloc, SubjectState>(
      listener: (context, state) {
        if (state is SubjectsLoaded) {
          setState(() {
            _availableSubjects = state.subjects;
            if (_selectedSubjectId != null &&
                !state.subjects.any((s) => s.id == _selectedSubjectId)) {
              _selectedSubjectId = null;
            }
          });
        }
      },
      builder: (context, state) {
        if (state is SubjectLoading) return _buildLoadingChip('Subject');
        if (state is SubjectError) return _buildErrorChip('Subject', () => context.read<SubjectBloc>().add(const LoadSubjects()));

        return _buildFilterChip<String>(
          label: 'Subject',
          value: _selectedSubjectId,
          options: _availableSubjects.map((subject) =>
              DropdownMenuItem(value: subject.id, child: Text(subject.name, style: const TextStyle(fontSize: 14)))).toList(),
          onChanged: (value) => setState(() => _selectedSubjectId = value),
        );
      },
    );
  }

  Widget _buildFilterChip<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> options,
    required ValueChanged<T?> onChanged,
  }) {
    final isSelected = value != null;
    T? validatedValue = value;
    if (value != null && !options.any((item) => item.value == value)) {
      validatedValue = null;
    }

    return Container(
      height: 32, // Reduced height for mobile
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border.withOpacity(0.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: validatedValue,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          selectedItemBuilder: (context) => options.map((item) {
            final text = (item.child as Text).data!;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                text.length > 10 ? '${text.substring(0, 10)}...' : text,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
          items: [
            DropdownMenuItem<T>(
              value: null,
              child: Text('All ${label}s', style: const TextStyle(fontSize: 14)),
            ),
            ...options,
          ],
          onChanged: onChanged,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildLoadingChip(String label) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildErrorChip(String label, VoidCallback onRetry) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClearButton() {
    return GestureDetector(
      onTap: _clearAllFilters,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear_rounded, size: 14, color: AppColors.error),
            const SizedBox(width: 4),
            Text('Clear', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
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
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        dividerColor: Colors.transparent,
      ),
    );
  }

  Widget _buildContent() {
    return BlocConsumer<QuestionPaperBloc, QuestionPaperState>(
      listener: (context, state) {
        if (state is QuestionPaperError) {
          _showMessage(state.message, AppColors.error);
        } else if (state is QuestionPaperLoaded) {
          _loadUserNamesForPapers(state.approvedPapers);
        }
      },
      builder: (context, state) {
        if (state is QuestionPaperLoading && !_isRefreshing) {
          return _buildModernLoading();
        }

        if (state is QuestionPaperLoaded) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPapersForPeriod(state.approvedPapers, 'current'),
                _buildPapersForPeriod(state.approvedPapers, 'previous'),
                _buildArchiveView(state.approvedPapers),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: _buildModernEmpty(),
            ),
          ),
        );
      },
    );
  }

  List<QuestionPaperEntity> _filterPapersByPeriod(List<QuestionPaperEntity> papers, String period) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final previousMonth = DateTime(now.year, now.month - 1);

    return papers.where((paper) {
      if (!paper.status.isApproved) return false;

      final matchesSearch = _searchQuery.isEmpty ||
          paper.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          paper.subject.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          paper.createdBy.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (_userNamesCache[paper.createdBy]?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      final matchesGrade = _selectedGradeLevel == null || paper.gradeLevel == _selectedGradeLevel;
      final matchesSubject = _selectedSubjectId == null ||
          _availableSubjects.any((subject) => subject.id == _selectedSubjectId && subject.name == paper.subject);

      if (!matchesSearch || !matchesGrade || !matchesSubject) return false;

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
      return RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _buildEmptyForPeriod(period),
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
          SliverToBoxAdapter(child: _buildStatsHeader(papers.length)),
          ...groupedPapers.entries.map((entry) => _buildModernClassSection(entry.key, entry.value)),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
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
                  padding: const EdgeInsets.all(8),
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
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${papers.length}',
                    style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader(int paperCount) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient.scale(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
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
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
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
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
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
                  padding: const EdgeInsets.all(8),
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
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${papers.length}',
                    style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
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
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernPaperCard(QuestionPaperEntity paper) {
    final isGenerating = _isGeneratingPdf && _generatingPdfFor == paper.id;
    final screenWidth = MediaQuery.of(context).size.width;
    final creatorName = _userNamesCache[paper.createdBy] ?? 'Loading...';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.border.withOpacity(0.1)),
      ),
      child: Padding(
        padding: EdgeInsets.all(screenWidth * 0.035),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paper.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by $creatorName',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildModernTag(paper.subject, AppColors.primary),
                          _buildModernTag(paper.examType, AppColors.accent),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusBadge(),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(paper.reviewedAt ?? paper.createdAt),
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildModernMetric(Icons.quiz_rounded, '${paper.totalQuestions}', 'Questions'),
                      _buildModernMetric(Icons.grade_rounded, '${paper.totalMarks}', 'Marks'),
                      _buildModernMetric(Icons.access_time_rounded, paper.examTypeEntity.formattedDuration, 'Duration'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildModernActions(paper, isGenerating),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'APPROVED',
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: AppColors.success),
      ),
    );
  }

  Widget _buildModernMetric(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernActions(QuestionPaperEntity paper, bool isGenerating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: Icons.visibility_outlined,
          color: AppColors.primary,
          onPressed: () => _showPreviewOptions(paper),
        ),
        const SizedBox(width: 6),
        _buildActionButton(
          icon: isGenerating ? null : Icons.download_rounded,
          color: AppColors.success,
          isLoading: isGenerating,
          onPressed: isGenerating ? null : () => _showDownloadOptions(paper),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    IconData? icon,
    required Color color,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: isLoading
                ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
                : Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }

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
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Pull down to refresh',
            style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 10),
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.library_books, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading papers...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
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
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.library_books_outlined, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'No Papers Available',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Approved papers will appear here',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Pull down to refresh',
            style: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 10),
          ),
        ],
      ),
    );
  }

  // Helper methods
  bool _hasActiveFilters() => _selectedGradeLevel != null || _selectedSubjectId != null;

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _clearAllFilters() {
    _clearSearch();
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

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  // Load user names for all papers
  Future<void> _loadUserNamesForPapers(List<QuestionPaperEntity> papers) async {
    final userIds = papers.map((paper) => paper.createdBy).toSet().toList();
    final uncachedIds = userIds.where((id) => !_userNamesCache.containsKey(id)).toList();

    if (uncachedIds.isNotEmpty) {
      try {
        print('Loading user names for IDs: $uncachedIds'); // Debug
        final userNames = await _userInfoService.getUserFullNames(uncachedIds);
        print('Loaded user names: $userNames'); // Debug

        if (mounted) {
          setState(() {
            _userNamesCache.addAll(userNames);
          });
        }
      } catch (e) {
        print('Failed to load user names: $e'); // Debug

        // Fallback: set user IDs as display names
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

  // PDF Generation and Preview methods
  void _showPreviewOptions(QuestionPaperEntity paper) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Preview PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              paper.title,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            _buildPreviewOption(
              'Single Page Layout',
              'One question paper per page',
              Icons.description_rounded,
              AppColors.primary,
                  () => _previewPdf(paper, 'single'),
            ),
            const SizedBox(height: 10),
            _buildPreviewOption(
              'Dual Layout',
              'Two identical papers per page',
              Icons.content_copy_rounded,
              AppColors.accent,
                  () => _previewPdf(paper, 'dual'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewOption(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          onTap();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _previewPdf(QuestionPaperEntity paper, String layoutType) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final pdfService = SimplePdfService();
      final userStateService = sl<UserStateService>();
      final schoolName = userStateService.schoolName;

      final pdfBytes = layoutType == 'single'
          ? await pdfService.generateStudentPdf(paper: paper, schoolName: schoolName)
          : await pdfService.generateDualLayoutPdf(paper: paper, schoolName: schoolName);

      Navigator.of(context).pop();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PdfPreviewPage(
            pdfBytes: pdfBytes,
            paperTitle: paper.title,
            onDownload: () => _generatePdf(paper, layoutType),
            onGenerateDual: layoutType == 'single'
                ? () => _generatePdf(paper, 'dual')
                : () => _generatePdf(paper, 'single'),
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop();
      _showMessage('Failed to generate preview: $e', AppColors.error);
    }
  }

  void _showDownloadOptions(QuestionPaperEntity paper) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Download PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              paper.title,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            _buildDownloadOption(
              'Single Page Layout',
              'One question paper per page',
              Icons.description_rounded,
              AppColors.primary,
                  () => _generatePdf(paper, 'single'),
            ),
            const SizedBox(height: 10),
            _buildDownloadOption(
              'Dual Layout',
              'Two identical papers per page',
              Icons.content_copy_rounded,
              AppColors.accent,
                  () => _generatePdf(paper, 'dual'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadOption(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          onTap();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf(QuestionPaperEntity paper, String layoutType) async {
    setState(() {
      _isGeneratingPdf = true;
      _generatingPdfFor = paper.id;
    });

    try {
      final pdfService = SimplePdfService();
      final userStateService = sl<UserStateService>();
      final schoolName = userStateService.schoolName;

      final pdfBytes = layoutType == 'single'
          ? await pdfService.generateStudentPdf(paper: paper, schoolName: schoolName)
          : await pdfService.generateDualLayoutPdf(paper: paper, schoolName: schoolName);

      final layoutSuffix = layoutType == 'single' ? 'Single' : 'Dual';
      final fileName = '${paper.title.replaceAll(RegExp(r'[^\w\s-]'), '')}_${layoutSuffix}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      File? savedFile;

      if (Platform.isAndroid) {
        try {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            savedFile = File('${downloadsDir.path}/$fileName');
            await savedFile.writeAsBytes(pdfBytes);
          }
        } catch (e) {
          savedFile = null;
        }

        if (savedFile == null) {
          try {
            final directory = await getExternalStorageDirectory();
            if (directory != null) {
              savedFile = File('${directory.path}/$fileName');
              await savedFile.writeAsBytes(pdfBytes);
            }
          } catch (e) {
            // Handle error
          }
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        savedFile = File('${directory.path}/$fileName');
        await savedFile.writeAsBytes(pdfBytes);
      }

      if (savedFile == null) {
        throw Exception('Could not save file to any location');
      }

      if (mounted) {
        _showMessage('PDF saved: $fileName', AppColors.success);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF saved successfully'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => _tryOpenPdf(savedFile!),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showMessage('Failed to generate PDF: $e', AppColors.error);
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
          _generatingPdfFor = null;
        });
      }
    }
  }

  Future<void> _tryOpenPdf(File file) async {
    try {
      if (Platform.isAndroid) {
        final result = await OpenFile.open(
          file.path,
          type: 'application/pdf',
          linuxDesktopName: 'pdf',
          linuxByProcess: false,
        );

        if (result.type != ResultType.done) {
          await _shareInsteadOfOpen(file);
          return;
        }
      } else {
        await OpenFile.open(file.path, type: 'application/pdf');
      }
    } catch (e) {
      await _shareInsteadOfOpen(file);
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
        _showMessage('PDF shared - select your PDF viewer', AppColors.primaryLight);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}