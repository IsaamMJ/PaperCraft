import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:papercraft/features/question_papers/presentation/pages/pdf_preview_page.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/presentation/constants/app_colors.dart';
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
  bool _isGeneratingPdf = false;
  String? _generatingPdfFor;

  final _classes = [
    'Grade 1',
    'Grade 2',
    'Grade 3',
    'Grade 4',
    'Grade 5',
    'Grade 6',
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10'
  ];
  final _subjects = [
    'Mathematics',
    'Physics',
    'Chemistry',
    'Biology',
    'English',
    'History',
    'Geography'
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _tabController = TabController(length: 3, vsync: this);
    _animController.forward();
    _loadPapers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _loadPapers() {
    context.read<QuestionPaperBloc>().add(const LoadApprovedPapers());
  }

  Future<void> _onRefresh() async {
    _loadPapers();
    // Wait for the bloc to complete loading
    await Future.delayed(const Duration(milliseconds: 500));
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
      padding: const EdgeInsets.all(16),
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
          // Search bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search papers, subjects, creators...',
                hintStyle: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.7)),
                prefixIcon: Icon(
                    Icons.search_rounded, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  onPressed: _clearSearch,
                  icon: Icon(Icons.clear, color: AppColors.textSecondary),
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
              ),
              onChanged: (query) => setState(() => _searchQuery = query),
            ),
          ),

          const SizedBox(height: 12),

          // Filter chips
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildModernFilterChip(
                          'Class', _selectedClass, _classes, (v) =>
                          setState(() => _selectedClass = v ?? '')),
                      const SizedBox(width: 8),
                      _buildModernFilterChip(
                          'Subject', _selectedSubject, _subjects, (v) =>
                          setState(() => _selectedSubject = v ?? '')),
                      if (_hasQuickFilters()) ...[
                        const SizedBox(width: 8),
                        _buildClearButton(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernFilterChip(String label, String value,
      List<String> options, ValueChanged<String?> onChanged) {
    final isSelected = value.isNotEmpty;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors
            .background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border.withOpacity(
              0.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          selectedItemBuilder: (context) =>
              options.map((option) =>
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      option.length > 12
                          ? '${option.substring(0, 12)}...'
                          : option,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
              ).toList(),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(
                  'All ${label}s', style: const TextStyle(fontSize: 14)),
            ),
            ...options.map((option) =>
                DropdownMenuItem(
                  value: option,
                  child: Text(option, style: const TextStyle(fontSize: 14)),
                )),
          ],
          onChanged: onChanged,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary,
              size: 20),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildClearButton() {
    return GestureDetector(
      onTap: _clearQuickFilters,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.clear_rounded, size: 16, color: AppColors.error),
            const SizedBox(width: 4),
            Text(
              'Clear',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
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
          Tab(text: 'Previous Month'),
          Tab(text: 'Archive'),
        ],
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500, fontSize: 14),
        dividerColor: Colors.transparent,
      ),
    );
  }

  Widget _buildContent() {
    return BlocConsumer<QuestionPaperBloc, QuestionPaperState>(
      listener: (context, state) {
        if (state is QuestionPaperError) _showMessage(
            state.message, AppColors.error);
      },
      builder: (context, state) {
        if (state is QuestionPaperLoading) return _buildModernLoading();
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
              height: MediaQuery
                  .of(context)
                  .size
                  .height * 0.7,
              child: _buildModernEmpty(),
            ),
          ),
        );
      },
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
            height: MediaQuery
                .of(context)
                .size
                .height * 0.7,
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
          ...groupedByMonth.entries.map((entry) =>
              _buildMonthSection(entry.key, entry.value)),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _buildMonthSection(String monthYear,
      List<QuestionPaperEntity> papers) {
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
                  child: const Icon(
                      Icons.calendar_month, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    monthYear,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${papers.length}',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
                  (context, index) => _buildModernPaperCard(papers[index]),
              childCount: papers.length,
            ),
          ),
        ),
      ],
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
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(icon, size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Pull down to refresh',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'APPROVED',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.success,
        ),
      ),
    );
  }

  // Data processing methods
  List<QuestionPaperEntity> _filterPapersByPeriod(
      List<QuestionPaperEntity> papers, String period) {
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

      final matchesClass = _selectedClass.isEmpty ||
          paper.gradeDisplayName == _selectedClass;
      final matchesSubject = _selectedSubject.isEmpty ||
          paper.subject == _selectedSubject;

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

  Map<String, List<QuestionPaperEntity>> _groupPapersByClass(
      List<QuestionPaperEntity> papers) {
    final grouped = <String, List<QuestionPaperEntity>>{};

    for (final paper in papers) {
      final className = paper.gradeDisplayName;
      grouped.putIfAbsent(className, () => []).add(paper);
    }

    // Sort by grade level (if available), then by name
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
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
      grouped[key]!.sort((a, b) =>
          (b.reviewedAt ?? b.createdAt).compareTo(a.reviewedAt ?? a.createdAt));
      sortedGrouped[key] = grouped[key]!;
    }

    return sortedGrouped;
  }

  int? _extractGradeNumber(String gradeDisplay) {
    final match = RegExp(r'Grade (\d+)').firstMatch(gradeDisplay);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  Map<String, List<QuestionPaperEntity>> _groupPapersByMonth(
      List<QuestionPaperEntity> papers) {
    final grouped = <String, List<QuestionPaperEntity>>{};

    for (final paper in papers) {
      final date = paper.reviewedAt ?? paper.createdAt;
      final monthYear = '${_getMonthName(date.month)} ${date.year}';
      grouped.putIfAbsent(monthYear, () => []).add(paper);
    }

    // Sort by date (newest first)
    final sortedGrouped = <String, List<QuestionPaperEntity>>{};
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final aDate = grouped[a]!.first.reviewedAt ??
            grouped[a]!.first.createdAt;
        final bDate = grouped[b]!.first.reviewedAt ??
            grouped[b]!.first.createdAt;
        return bDate.compareTo(aDate);
      });

    for (final key in sortedKeys) {
      grouped[key]!.sort((a, b) =>
          (b.reviewedAt ?? b.createdAt).compareTo(a.reviewedAt ?? a.createdAt));
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
  bool _hasQuickFilters() =>
      _selectedClass.isNotEmpty || _selectedSubject.isNotEmpty;

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
      builder: (context) =>
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.surface,
                borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Text('Preview PDF', style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(paper.title,
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
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
                  child: Text('Cancel',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildPreviewOption(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(
                      fontSize: 12, color: Colors.white.withOpacity(0.8))),
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
        builder: (context) =>
        const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Generate PDF bytes
      final pdfService = SimplePdfService();
      final pdfBytes = layoutType == 'single'
          ? await pdfService.generateStudentPdf(paper: paper,
          schoolName: 'Pearl Matriculation Higher Secondary School, Nagercoil')
          : await pdfService.generateDualLayoutPdf(paper: paper,
          schoolName: 'Pearl Matriculation Higher Secondary School, Nagercoil');

      // Hide loading
      Navigator.of(context).pop();

      // Navigate to preview
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              PdfPreviewPage(
                pdfBytes: pdfBytes,
                paperTitle: paper.title,
                onDownload: () => _generatePdf(paper, layoutType),
                onGenerateDual: layoutType == 'single' ? () =>
                    _generatePdf(paper, 'dual') : () =>
                    _generatePdf(paper, 'single'),
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
      builder: (context) =>
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.surface,
                borderRadius: BorderRadius.circular(20)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                Text('Download PDF', style: TextStyle(fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(paper.title,
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center),
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
                Container(
                  width: double.infinity,
                  height: 1,
                  color: AppColors.border,
                ),
                const SizedBox(height: 16),
                Text('Alternative (Recommended)',
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                _buildDownloadOption(
                  'Share PDF',
                  'Share with other apps - works on all devices',
                  Icons.share_rounded,
                  AppColors.success,
                      () => _generateAndSharePdf(paper, 'single'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildDownloadOption(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: TextStyle(
                      fontSize: 12, color: Colors.white.withOpacity(0.8))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdf(QuestionPaperEntity paper,
      String layoutType) async {
    setState(() {
      _isGeneratingPdf = true;
      _generatingPdfFor = paper.id;
    });

    try {
      final pdfService = SimplePdfService();
      final pdfBytes = layoutType == 'single'
          ? await pdfService.generateStudentPdf(paper: paper,
          schoolName: 'Pearl Matriculation Higher Secondary School, Nagercoil')
          : await pdfService.generateDualLayoutPdf(paper: paper,
          schoolName: 'Pearl Matriculation Higher Secondary School, Nagercoil');

      final layoutSuffix = layoutType == 'single' ? 'Single' : 'Dual';
      final fileName = '${paper.title.replaceAll(
          RegExp(r'[^\w\s-]'), '')}_${layoutSuffix}_${DateTime
          .now()
          .millisecondsSinceEpoch}.pdf';

      // Try multiple storage approaches
      File? savedFile;

      if (Platform.isAndroid) {
        // Method 1: Try public Downloads directory first
        try {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            savedFile = File('${downloadsDir.path}/$fileName');
            await savedFile.writeAsBytes(pdfBytes);
            print('DEBUG: Saved to public Downloads: ${savedFile.path}');
          }
        } catch (e) {
          print('DEBUG: Failed to save to public Downloads: $e');
          savedFile = null;
        }

        // Method 2: Fallback to external storage directory
        if (savedFile == null) {
          try {
            final directory = await getExternalStorageDirectory();
            if (directory != null) {
              savedFile = File('${directory.path}/$fileName');
              await savedFile.writeAsBytes(pdfBytes);
              print('DEBUG: Saved to external storage: ${savedFile.path}');
            }
          } catch (e) {
            print('DEBUG: Failed to save to external storage: $e');
          }
        }
      } else {
        // For other platforms
        final directory = await getApplicationDocumentsDirectory();
        savedFile = File('${directory.path}/$fileName');
        await savedFile.writeAsBytes(pdfBytes);
      }

      if (savedFile == null) {
        throw Exception('Could not save file to any location');
      }

      if (mounted) {
        _showMessage('PDF saved: $fileName', AppColors.success);

        // Show different options based on platform
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved successfully'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 5),
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
      print('DEBUG: Attempting to open file: ${file.path}');

      // For Android, try a more reliable approach
      if (Platform.isAndroid) {
        // Method 1: Try opening with explicit intent
        final result = await OpenFile.open(
          file.path,
          type: 'application/pdf',
          linuxDesktopName: 'pdf',
          linuxByProcess: false,
        );

        print('DEBUG: OpenFile result: ${result.type} - ${result.message}');

        // If direct opening doesn't work well, immediately fallback to share
        if (result.type != ResultType.done) {
          print('DEBUG: Direct open failed, using share');
          await _shareInsteadOfOpen(file);
          return;
        }
      } else {
        // For other platforms
        await OpenFile.open(file.path, type: 'application/pdf');
      }
    } catch (e) {
      print('DEBUG: Exception: $e');
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
        _showMessage(
            'PDF shared - select your PDF viewer', AppColors.primaryLight);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Cannot open PDF. Please install a PDF viewer app.',
            AppColors.warning);
      }
    }
  }


  Future<void> _generateAndSharePdf(QuestionPaperEntity paper,
      String layoutType) async {
    setState(() {
      _isGeneratingPdf = true;
      _generatingPdfFor = paper.id;
    });

    try {
      final pdfService = SimplePdfService();
      final pdfBytes = layoutType == 'single'
          ? await pdfService.generateStudentPdf(paper: paper,
          schoolName: 'Pearl Matriculation Higher Secondary School, Nagercoil')
          : await pdfService.generateDualLayoutPdf(paper: paper,
          schoolName: 'Pearl Matriculation Higher Secondary School, Nagercoil');

      // Save to app directory
      final directory = await getApplicationDocumentsDirectory();
      final layoutSuffix = layoutType == 'single' ? 'Single' : 'Dual';
      final fileName = '${paper.title.replaceAll(
          RegExp(r'[^\w\s-]'), '')}_${layoutSuffix}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      // ALTERNATIVE: Use share instead of direct file opening
      if (mounted) {
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          text: 'Question Paper: ${paper.title}',
          subject: paper.title,
        );
        _showMessage('PDF ready to share/save', AppColors.success);
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


  Widget _buildPapersForPeriod(List<QuestionPaperEntity> allPapers,
      String period) {
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
            height: MediaQuery
                .of(context)
                .size
                .height * 0.7,
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
          ...groupedPapers.entries.map((entry) =>
              _buildModernClassSection(entry.key, entry.value)),
          const SliverPadding(padding: EdgeInsets.only(bottom: 16)),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(int paperCount) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient.scale(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.assessment, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$paperCount Papers Available',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Ready for download and preview',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_hasQuickFilters())
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Filtered',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModernClassSection(String className,
      List<QuestionPaperEntity> papers) {
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
                  child: const Icon(
                      Icons.school, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    className,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${papers.length}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.border.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
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
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildModernTag(
                                    paper.subject, AppColors.primary),
                                const SizedBox(width: 8),
                                _buildModernTag(
                                    paper.examType, AppColors.accent),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildStatusBadge(),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(paper.reviewedAt ?? paper.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildModernMetric(
                          Icons.quiz_rounded, '${paper.totalQuestions}',
                          'Questions'),
                      const SizedBox(width: 16),
                      _buildModernMetric(
                          Icons.grade_rounded, '${paper.totalMarks}', 'Marks'),
                      const SizedBox(width: 16),
                      _buildModernMetric(Icons.access_time_rounded,
                          paper.examTypeEntity.formattedDuration, 'Duration'),
                      const Spacer(),
                      _buildModernActions(paper, isGenerating),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildModernMetric(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
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
        const SizedBox(width: 8),
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: isLoading
                ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
                : Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildModernLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
                Icons.library_books, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading papers...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
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
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.library_books_outlined,
              size: 50,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Papers Available',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Approved papers will appear here',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Pull down to refresh',
            style: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}