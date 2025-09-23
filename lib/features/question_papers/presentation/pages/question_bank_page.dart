import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:papercraft/features/question_papers/presentation/pages/pdf_preview_page.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/services/pdf_generation_service.dart';
import '../bloc/question_paper_bloc.dart';

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

  String _searchQuery = '';
  String _selectedClass = '';
  String _selectedSubject = '';
  String _selectedTimePeriod = 'current'; // current, previous, all
  bool _isGeneratingPdf = false;
  String? _generatingPdfFor;
  bool _showArchivedSections = false;

  final _classes = ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10'];
  final _subjects = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'History', 'Geography'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _tabController = TabController(length: 3, vsync: this);
    _animController.forward();
    context.read<QuestionPaperBloc>().add(const LoadApprovedPapers());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildQuickFilters()),
            SliverToBoxAdapter(child: _buildTimePeriodTabs()),
          ],
          body: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(gradient: AppColors.successGradient, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.library_books, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Text('Question Bank', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
      actions: [
        if (_hasFilters())
          IconButton(
            onPressed: _clearAllFilters,
            icon: Icon(Icons.filter_alt_off, color: AppColors.error),
            tooltip: 'Clear Filters',
          ),
        IconButton(
          onPressed: () => context.read<QuestionPaperBloc>().add(const LoadApprovedPapers()),
          icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
          tooltip: 'Refresh',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by title, subject, or creator...',
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(onPressed: _clearSearch, icon: const Icon(Icons.clear))
                  : null,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2)
              ),
            ),
            onChanged: (query) => setState(() => _searchQuery = query),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildQuickFilterChip('Class', _selectedClass, _classes, (v) => setState(() => _selectedClass = v ?? '')),
            const SizedBox(width: 8),
            _buildQuickFilterChip('Subject', _selectedSubject, _subjects, (v) => setState(() => _selectedSubject = v ?? '')),
            const SizedBox(width: 8),
            if (_hasQuickFilters())
              TextButton.icon(
                onPressed: _clearQuickFilters,
                icon: Icon(Icons.clear_rounded, size: 16, color: AppColors.error),
                label: Text('Clear', style: TextStyle(color: AppColors.error)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilterChip(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    final isSelected = value.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          selectedItemBuilder: (context) => options.map((option) =>
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                    option.length > 10 ? '${option.substring(0, 10)}...' : option,
                    style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)
                ),
              )
          ).toList(),
          items: [
            DropdownMenuItem(
                value: '',
                child: Text('All ${label}s', style: const TextStyle(fontSize: 13))
            ),
            ...options.map((option) => DropdownMenuItem(
                value: option,
                child: Text(option, style: const TextStyle(fontSize: 13))
            )),
          ],
          onChanged: onChanged,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          icon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary, size: 20),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildTimePeriodTabs() {
    return Container(
      color: AppColors.surface,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'This Month'),
          Tab(text: 'Previous Month'),
          Tab(text: 'Archive'),
        ],
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    );
  }

  Widget _buildContent() {
    return BlocConsumer<QuestionPaperBloc, QuestionPaperState>(
      listener: (context, state) {
        if (state is QuestionPaperError) _showMessage(state.message, AppColors.error);
      },
      builder: (context, state) {
        if (state is QuestionPaperLoading) return _buildLoading();
        if (state is QuestionPaperLoaded) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildPapersForPeriod(state.approvedPapers, 'current'),
              _buildPapersForPeriod(state.approvedPapers, 'previous'),
              _buildArchiveView(state.approvedPapers),
            ],
          );
        }
        return _buildEmpty();
      },
    );
  }

  Widget _buildPapersForPeriod(List<QuestionPaperEntity> allPapers, String period) {
    final papers = _filterPapersByPeriod(allPapers, period);
    final groupedPapers = _groupPapersByClass(papers);

    if (papers.isEmpty) {
      return _buildEmptyForPeriod(period);
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.assessment, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                    '${papers.length} papers available',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500
                    )
                ),
                const Spacer(),
                if (_hasQuickFilters())
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Filtered',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ...groupedPapers.entries.map((entry) => _buildClassSection(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildClassSection(String className, List<QuestionPaperEntity> papers) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Text(
                  className,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${papers.length}',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600
                    ),
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
                  (context, index) => _buildCompactPaperCard(papers[index]),
              childCount: papers.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArchiveView(List<QuestionPaperEntity> allPapers) {
    final archivedPapers = _filterPapersByPeriod(allPapers, 'archive');
    final groupedByMonth = _groupPapersByMonth(archivedPapers);

    if (archivedPapers.isEmpty) {
      return _buildEmptyForPeriod('archive');
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '${archivedPapers.length} archived papers',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ),
        ...groupedByMonth.entries.map((entry) => _buildMonthSection(entry.key, entry.value)),
      ],
    );
  }

  Widget _buildMonthSection(String monthYear, List<QuestionPaperEntity> papers) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  monthYear,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary
                  ),
                ),
                const Spacer(),
                Text(
                  '${papers.length}',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500
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
                  (context, index) => _buildCompactPaperCard(papers[index]),
              childCount: papers.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactPaperCard(QuestionPaperEntity paper) {
    final isGenerating = _isGeneratingPdf && _generatingPdfFor == paper.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 1))],
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      paper.title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            paper.subject,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          paper.examType,
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  _buildStatusBadge(),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(paper.reviewedAt ?? paper.createdAt),
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildCompactMetric(Icons.quiz_rounded, '${paper.totalQuestions}Q'),
              const SizedBox(width: 12),
              _buildCompactMetric(Icons.grade_rounded, '${paper.totalMarks}M'),
              const SizedBox(width: 12),
              _buildCompactMetric(Icons.access_time_rounded, paper.examTypeEntity.formattedDuration),
              const Spacer(),
              _buildQuickActions(paper, isGenerating),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactMetric(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildQuickActions(QuestionPaperEntity paper, bool isGenerating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () => _showPreviewOptions(paper),
          icon: Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(32, 32),
          ),
          tooltip: 'Preview',
        ),
        const SizedBox(width: 4),
        IconButton(
          onPressed: isGenerating ? null : () => _showDownloadOptions(paper),
          icon: isGenerating
              ? SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.success)
              )
          )
              : Icon(Icons.download_rounded, size: 18, color: AppColors.success),
          style: IconButton.styleFrom(
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(32, 32),
          ),
          tooltip: 'Download PDF',
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary)
              )
          ),
          const SizedBox(height: 16),
          Text('Loading papers...', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20)
            ),
            child: Icon(Icons.library_books_outlined, size: 40, color: AppColors.success),
          ),
          const SizedBox(height: 16),
          Text(
              'No Papers Available',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary
              )
          ),
          const SizedBox(height: 8),
          Text(
            'Approved papers will appear here',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
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
          Icon(icon, size: 48, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(description, style: TextStyle(fontSize: 14, color: AppColors.textSecondary.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.success.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        'APPROVED',
        style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: AppColors.success
        ),
      ),
    );
  }

  // Data processing methods
  List<QuestionPaperEntity> _filterPapersByPeriod(List<QuestionPaperEntity> papers, String period) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final previousMonth = DateTime(now.year, now.month - 1);

    return papers.where((paper) {
      if (!paper.status.isApproved) return false;

      // Apply search and filter criteria
      final matchesSearch = _searchQuery.isEmpty ||
          paper.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          paper.subject.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          paper.createdBy.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesClass = _selectedClass.isEmpty || paper.gradeDisplayName == _selectedClass;
      final matchesSubject = _selectedSubject.isEmpty || paper.subject == _selectedSubject;

      if (!matchesSearch || !matchesClass || !matchesSubject) return false;

      // Apply time period filter
      final paperDate = paper.reviewedAt ?? paper.createdAt;
      final paperMonth = DateTime(paperDate.year, paperDate.month);

      switch (period) {
        case 'current':
          return paperMonth.isAtSameMomentAs(currentMonth);
        case 'previous':
          return paperMonth.isAtSameMomentAs(previousMonth);
        case 'archive':
          return paperMonth.isBefore(previousMonth);
        default:
          return true;
      }
    }).toList();
  }

  Map<String, List<QuestionPaperEntity>> _groupPapersByClass(List<QuestionPaperEntity> papers) {
    final grouped = <String, List<QuestionPaperEntity>>{};

    for (final paper in papers) {
      final className = paper.gradeDisplayName;
      grouped.putIfAbsent(className, () => []).add(paper);
    }

    // Sort by grade level (if available), then by name
    final sortedKeys = grouped.keys.toList()..sort((a, b) {
      // Extract grade numbers for proper sorting
      final aGrade = _extractGradeNumber(a);
      final bGrade = _extractGradeNumber(b);

      if (aGrade != null && bGrade != null) {
        return aGrade.compareTo(bGrade);
      }
      return a.compareTo(b);
    });

    final sortedGrouped = <String, List<QuestionPaperEntity>>{};

    for (final key in sortedKeys) {
      // Sort papers within each class by date (newest first)
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

    // Sort by date (newest first)
    final sortedGrouped = <String, List<QuestionPaperEntity>>{};
    final sortedKeys = grouped.keys.toList()..sort((a, b) {
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
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }

  // Filter helper methods
  bool _hasQuickFilters() => _selectedClass.isNotEmpty || _selectedSubject.isNotEmpty;

  bool _hasFilters() => _hasQuickFilters() || _searchQuery.isNotEmpty;

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _clearQuickFilters() {
    setState(() {
      _selectedClass = '';
      _selectedSubject = '';
    });
  }

  void _clearAllFilters() {
    _clearSearch();
    _clearQuickFilters();
  }

  // NEW: Preview options dialog
  void _showPreviewOptions(QuestionPaperEntity paper) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('Preview PDF', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(paper.title, style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _buildPreviewOption(
              'Single Page Layout',
              'Preview one question paper per page',
              Icons.description_rounded,
              AppColors.primary,
                  () => _previewPdf(paper, 'single'),
            ),
            const SizedBox(height: 12),
            _buildPreviewOption(
              'Dual Layout',
              'Preview two identical papers per page',
              Icons.content_copy_rounded,
              AppColors.accent,
                  () => _previewPdf(paper, 'dual'),
            ),
            const SizedBox(height: 16),
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
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          onTap();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
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
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Generate PDF bytes
      final pdfService = SimplePdfService();
      final pdfBytes = layoutType == 'single'
          ? await pdfService.generateStudentPdf(paper: paper, schoolName: 'Your School Name')
          : await pdfService.generateDualLayoutPdf(paper: paper, schoolName: 'Your School Name');

      // Hide loading
      Navigator.of(context).pop();

      // Navigate to preview
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PdfPreviewPage(
            pdfBytes: pdfBytes,
            paperTitle: paper.title,
            onDownload: () => _generatePdf(paper, layoutType),
            onGenerateDual: layoutType == 'single' ? () => _generatePdf(paper, 'dual') : () => _generatePdf(paper, 'single'),
          ),
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Hide loading
      _showMessage('Failed to generate preview: $e', AppColors.error);
    }
  }

  // Download options dialog (separated from preview)
  void _showDownloadOptions(QuestionPaperEntity paper) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Text('Download PDF', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(paper.title, style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _buildDownloadOption(
              'Single Page Layout',
              'One question paper per page',
              Icons.description_rounded,
              AppColors.primary,
                  () => _generatePdf(paper, 'single'),
            ),
            const SizedBox(height: 12),
            _buildDownloadOption(
              'Dual Layout',
              'Two identical papers per page (horizontal split)',
              Icons.content_copy_rounded,
              AppColors.accent,
                  () => _generatePdf(paper, 'dual'),
            ),
            const SizedBox(height: 16),
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
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          onTap();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
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
      final pdfBytes = layoutType == 'single'
          ? await pdfService.generateStudentPdf(paper: paper, schoolName: 'Your School Name')
          : await pdfService.generateDualLayoutPdf(paper: paper, schoolName: 'Your School Name');

      Directory? directory;
      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        final downloadsPath = '/storage/emulated/0/Download';
        final downloadsDir = Directory(downloadsPath);
        if (await downloadsDir.exists()) directory = downloadsDir;
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }

      if (directory == null) throw Exception('Could not access storage directory');

      final layoutSuffix = layoutType == 'single' ? 'Single' : 'Dual';
      final fileName = '${paper.title}_${layoutSuffix}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      if (mounted) {
        _showMessage('PDF saved: $fileName', AppColors.success);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved: $fileName'),
            backgroundColor: AppColors.success,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () async {
                try {
                  await OpenFile.open(file.path);
                } catch (e) {
                  if (mounted) _showMessage('Could not open PDF: $e', AppColors.warning);
                }
              },
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

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}