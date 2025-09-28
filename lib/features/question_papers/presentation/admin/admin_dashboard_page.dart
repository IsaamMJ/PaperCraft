// features/question_papers/presentation/admin/admin_dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../bloc/question_paper_bloc.dart';
import '../widgets/shared/paper_list_tile.dart';
import '../widgets/shared/admin_action_buttons.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  String _searchQuery = '';
  String _selectedSubject = '';
  bool _isAdmin = false;

  final _subjects = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'History', 'Geography'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _animController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _checkAdminStatus();
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _checkAdminStatus() async {
    final isAdmin = sl<UserStateService>().isAdmin;
    if (mounted) {
      setState(() => _isAdmin = isAdmin);

      if (!isAdmin) {
        // Redirect non-admin users
        context.go('/home');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Admin access required'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  void _loadInitialData() {
    context.read<QuestionPaperBloc>().add(const LoadAllPapersForAdmin());
  }

  Future<void> _onRefresh() async {
    _loadInitialData();
    // Wait for the bloc to complete loading
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _handleApprove(String paperId) async {
    final confirm = await _showModernConfirmDialog(
      title: 'Approve Paper',
      content: 'Are you sure you want to approve this paper?',
      confirmText: 'Approve',
      confirmColor: AppColors.success,
      icon: Icons.check_circle_outline,
    );

    if (confirm == true && mounted) {
      context.read<QuestionPaperBloc>().add(ApprovePaper(paperId));
    }
  }

  void _handleReject(String paperId, String paperTitle) async {
    showDialog(
      context: context,
      builder: (context) => ModernRejectPaperDialog(
        paperTitle: paperTitle,
        onReject: (reason) {
          context.read<QuestionPaperBloc>().add(RejectPaper(paperId, reason));
        },
      ),
    );
  }

  void _handleViewDetails(String paperId) {
    context.go(AppRoutes.questionPaperViewWithId(paperId));
  }

  Future<bool?> _showModernConfirmDialog({
    required String title,
    required String content,
    required String confirmText,
    required Color confirmColor,
    required IconData icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: confirmColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: confirmColor, size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          content,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  List<QuestionPaperEntity> _filterPapers(List<QuestionPaperEntity> papers) {
    return papers.where((paper) {
      final matchesSearch = _searchQuery.isEmpty ||
          paper.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          paper.createdBy.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesSubject = _selectedSubject.isEmpty ||
          paper.subject == _selectedSubject;

      return matchesSearch && matchesSubject;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: BlocListener<QuestionPaperBloc, QuestionPaperState>(
          listener: (context, state) {
            if (state is QuestionPaperSuccess) {
              _showMessage(state.message, AppColors.success);
              _loadInitialData();
            } else if (state is QuestionPaperError) {
              _showMessage(state.message, AppColors.error);
            }
          },
          child: Column(
            children: [
              _buildSearchAndFilters(),
              _buildModernTabs(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPendingReviewTab(),
                    _buildAllPapersTab(),
                    _buildAnalyticsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.questionPaperCreate),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Paper'),
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
              decoration: InputDecoration(
                hintText: 'Search papers by title or creator...',
                hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  onPressed: () => setState(() => _searchQuery = ''),
                  icon: Icon(Icons.clear, color: AppColors.textSecondary),
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
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
                      _buildModernFilterChip('Subject', _selectedSubject, _subjects, (v) => setState(() => _selectedSubject = v ?? '')),
                      if (_hasFilters()) ...[
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

  Widget _buildModernFilterChip(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    final isSelected = value.isNotEmpty;
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border.withOpacity(0.5),
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
          selectedItemBuilder: (context) => options.map((option) =>
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  option.length > 12 ? '${option.substring(0, 12)}...' : option,
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
              child: Text('All ${label}s', style: const TextStyle(fontSize: 14)),
            ),
            ...options.map((option) => DropdownMenuItem(
              value: option,
              child: Text(option, style: const TextStyle(fontSize: 14)),
            )),
          ],
          onChanged: onChanged,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 20),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildClearButton() {
    return GestureDetector(
      onTap: () => setState(() => _selectedSubject = ''),
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
          Tab(text: 'Pending Review'),
          Tab(text: 'All Papers'),
          Tab(text: 'Analytics'),
        ],
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicator: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorPadding: const EdgeInsets.all(4),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        dividerColor: Colors.transparent,
      ),
    );
  }

  Widget _buildPendingReviewTab() {
    return BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
      builder: (context, state) {
        if (state is QuestionPaperLoading) {
          return _buildModernLoading();
        }

        if (state is QuestionPaperLoaded) {
          final pendingPapers = _filterPapers(state.papersForReview);

          if (pendingPapers.isEmpty) {
            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: _buildModernEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No Pending Reviews',
                    subtitle: _searchQuery.isNotEmpty || _selectedSubject.isNotEmpty
                        ? 'No papers match your current filters'
                        : 'All papers have been reviewed\nPull down to refresh',
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildStatsHeader('Pending Review', pendingPapers.length)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildModernPaperCard(pendingPapers[index]),
                      childCount: pendingPapers.length,
                    ),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          );
        }

        if (state is QuestionPaperError) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: _buildErrorState(state.message),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildModernEmptyState(
                icon: Icons.description_outlined,
                title: 'No Data',
                subtitle: 'Pull down to refresh',
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllPapersTab() {
    return BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
      builder: (context, state) {
        if (state is QuestionPaperLoading) {
          return _buildModernLoading();
        }

        if (state is QuestionPaperLoaded) {
          final allPapers = state.allPapersForAdmin;
          final filteredPapers = _filterPapers(allPapers);

          if (filteredPapers.isEmpty) {
            return RefreshIndicator(
              onRefresh: _onRefresh,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: _buildModernEmptyState(
                    icon: Icons.description_outlined,
                    title: 'No Papers Found',
                    subtitle: _searchQuery.isNotEmpty || _selectedSubject.isNotEmpty
                        ? 'No papers match your current filters'
                        : 'No papers have been submitted yet\nPull down to refresh',
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildStatsHeader('All Papers', filteredPapers.length)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildModernPaperCard(filteredPapers[index]),
                      childCount: filteredPapers.length,
                    ),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          );
        }

        if (state is QuestionPaperError) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: _buildErrorState(state.message),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildModernEmptyState(
                icon: Icons.description_outlined,
                title: 'No Data',
                subtitle: 'Pull down to refresh',
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsHeader(String title, int count) {
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
            child: Icon(Icons.assignment, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Papers in $title',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Manage and review submissions',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_hasFilters())
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

  Widget _buildModernPaperCard(QuestionPaperEntity paper) {
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
                                _buildTag(paper.subject, AppColors.primary),
                                const SizedBox(width: 8),
                                _buildStatusTag(paper),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Created by ${paper.createdBy}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatDate(paper.createdAt),
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
                      _buildMetric(Icons.quiz_rounded, '${paper.totalQuestions}', 'Questions'),
                      const SizedBox(width: 16),
                      _buildMetric(Icons.grade_rounded, '${paper.totalMarks}', 'Marks'),
                      const SizedBox(width: 16),
                      _buildMetric(Icons.access_time_rounded, paper.examTypeEntity.formattedDuration, 'Duration'),
                      const Spacer(),
                      _buildAdminActions(paper),
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

  Widget _buildTag(String text, Color color) {
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

  Widget _buildStatusTag(QuestionPaperEntity paper) {
    Color color;
    String text;

    if (paper.status.isApproved) {
      color = AppColors.success;
      text = 'APPROVED';
    } else if (paper.status.isRejected) {
      color = AppColors.error;
      text = 'REJECTED';
    } else {
      color = AppColors.warning;
      text = 'PENDING';
    }

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

  Widget _buildMetric(IconData icon, String value, String label) {
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

  Widget _buildAdminActions(QuestionPaperEntity paper) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: Icons.visibility_outlined,
          color: AppColors.primary,
          onPressed: () => _handleViewDetails(paper.id),
        ),
        if (paper.status.isSubmitted) ...[
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.check_rounded,
            color: AppColors.success,
            onPressed: () => _handleApprove(paper.id),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.close_rounded,
            color: AppColors.error,
            onPressed: () => _handleReject(paper.id, paper.title),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
      builder: (context, state) {
        if (state is QuestionPaperLoaded) {
          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: _buildAnalyticsContent(state),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildModernEmptyState(
                icon: Icons.analytics_outlined,
                title: 'Analytics',
                subtitle: 'Statistics will be displayed here\nPull down to refresh',
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsContent(QuestionPaperLoaded state) {
    final papers = state.papersForReview;
    final totalPapers = papers.length;
    final pendingCount = papers.where((p) => p.status.isSubmitted).length;
    final approvedCount = papers.where((p) => p.status.isApproved).length;
    final rejectedCount = papers.where((p) => p.status.isRejected).length;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paper Statistics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Statistics Cards
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Papers', totalPapers, AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Pending', pendingCount, AppColors.warning)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Approved', approvedCount, AppColors.success)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Rejected', rejectedCount, AppColors.error)),
            ],
          ),

          if (totalPapers > 0) ...[
            const SizedBox(height: 32),
            Text(
              'Subject Distribution',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildSubjectDistribution(papers),

            const SizedBox(height: 32),
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildRecentActivity(papers),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectDistribution(List<QuestionPaperEntity> papers) {
    final subjectCounts = <String, int>{};
    for (final paper in papers) {
      subjectCounts[paper.subject] = (subjectCounts[paper.subject] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: subjectCounts.entries.map((entry) {
          final percentage = (entry.value / papers.length * 100).round();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.border.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: entry.value / papers.length,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${entry.value} ($percentage%)',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecentActivity(List<QuestionPaperEntity> papers) {
    final recentPapers = papers.where((p) =>
    p.submittedAt != null || p.reviewedAt != null).toList();
    recentPapers.sort((a, b) {
      final aDate = a.reviewedAt ?? a.submittedAt ?? a.createdAt;
      final bDate = b.reviewedAt ?? b.submittedAt ?? b.createdAt;
      return bDate.compareTo(aDate);
    });

    return Container(
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
      child: Column(
        children: recentPapers.take(5).map((paper) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: paper.status.isApproved ? AppColors.success.withOpacity(0.1) :
                    paper.status.isRejected ? AppColors.error.withOpacity(0.1) :
                    AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    paper.status.isApproved ? Icons.check_circle :
                    paper.status.isRejected ? Icons.cancel :
                    Icons.pending,
                    color: paper.status.isApproved ? AppColors.success :
                    paper.status.isRejected ? AppColors.error :
                    AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        paper.title,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${paper.subject} â€¢ ${paper.createdBy}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _getActivityDate(paper),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getActivityDate(QuestionPaperEntity paper) {
    final date = paper.reviewedAt ?? paper.submittedAt ?? paper.createdAt;
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
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
            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 30),
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
            'Loading admin data...',
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

  Widget _buildModernEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
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
              icon,
              size: 50,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(Icons.error_outline, size: 40, color: AppColors.error),
          ),
          const SizedBox(height: 24),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadInitialData,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  bool _hasFilters() => _selectedSubject.isNotEmpty || _searchQuery.isNotEmpty;

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

// Modern Reject Paper Dialog
class ModernRejectPaperDialog extends StatefulWidget {
  final String paperTitle;
  final Function(String reason) onReject;

  const ModernRejectPaperDialog({
    super.key,
    required this.paperTitle,
    required this.onReject,
  });

  @override
  State<ModernRejectPaperDialog> createState() => _ModernRejectPaperDialogState();
}

class _ModernRejectPaperDialogState extends State<ModernRejectPaperDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.cancel_outlined, color: AppColors.error, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            'Reject Paper',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Paper: ${widget.paperTitle}',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Please provide a reason for rejection:',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              maxLines: 3,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_reasonController.text.trim().isNotEmpty) {
              widget.onReject(_reasonController.text.trim());
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}