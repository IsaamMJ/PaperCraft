// features/question_papers/presentation/admin/admin_dashboard_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/services/user_info_service.dart';
import '../bloc/question_paper_bloc.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late final UserInfoService _userInfoService;
  final Map<String, String> _userNames = {};

  String _searchQuery = '';
  String _selectedSubject = '';
  bool _isAdmin = false;
  bool _isRefreshing = false;

  final _subjects = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'History', 'Geography'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    _checkAdminStatus();

    _userInfoService = sl<UserInfoService>();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _checkAdminStatus() async {
    final isAdmin = sl<UserStateService>().isAdmin;
    if (mounted) {
      setState(() => _isAdmin = isAdmin);
      if (!isAdmin) {
        context.go('/home');
        _showMessage('Admin access required', AppColors.error);
      } else {
        _loadInitialData();
      }
    }
  }

  void _loadInitialData() {
    context.read<QuestionPaperBloc>().add(const LoadAllPapersForAdmin());
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    final completer = Completer<void>();
    late StreamSubscription subscription;

    subscription = context.read<QuestionPaperBloc>().stream.listen((state) {
      if (state is! QuestionPaperLoading) {
        subscription.cancel();
        if (mounted) {
          setState(() => _isRefreshing = false);
          completer.complete();
        }
      }
    });

    _loadInitialData();
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      if (mounted) setState(() => _isRefreshing = false);
    });
  }

  void _handleApprove(String paperId) async {
    final confirm = await _showConfirmDialog(
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
    final reason = await _showRejectDialog(paperTitle);
    if (reason != null && reason.isNotEmpty && mounted) {
      context.read<QuestionPaperBloc>().add(RejectPaper(paperId, reason));
    }
  }

  void _handleViewDetails(String paperId) {
    context.go(AppRoutes.questionPaperViewWithId(paperId));
  }

  Future<bool?> _showConfirmDialog({
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
              child: Icon(icon, color: confirmColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(content, style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
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

  Future<String> _getUserName(String userId) async {
    if (_userNames.containsKey(userId)) {
      return _userNames[userId]!;
    }

    try {
      final name = await _userInfoService.getUserFullName(userId);
      _userNames[userId] = name;
      return name;
    } catch (e) {
      return 'User $userId';
    }
  }

  Future<String?> _showRejectDialog(String paperTitle) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Reject Paper', style: TextStyle(fontSize: 16))),
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
              child: Text('Paper: $paperTitle',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 16),
            const Text('Rejection reason:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Enter reason...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
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
      final matchesSubject = _selectedSubject.isEmpty || paper.subject == _selectedSubject;
      return matchesSearch && matchesSubject;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'All Papers',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                child: _buildPapersTab(false),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.questionPaperCreate),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Create Paper'),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 16),
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
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withOpacity(0.3)),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search papers...',
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  onPressed: () => setState(() => _searchQuery = ''),
                  icon: Icon(Icons.clear, size: 18),
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterChip('Subject', _selectedSubject, _subjects,
                        (v) => setState(() => _selectedSubject = v ?? '')),
              ),
              if (_selectedSubject.isNotEmpty || _searchQuery.isNotEmpty) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedSubject = '';
                    _searchQuery = '';
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.clear, size: 16, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text('Clear', style: TextStyle(color: AppColors.error, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: value.isNotEmpty ? AppColors.primary.withOpacity(0.1) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value.isNotEmpty ? AppColors.primary : AppColors.border.withOpacity(0.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          items: [
            DropdownMenuItem(value: '', child: Text('All ${label}s')),
            ...options.map((option) => DropdownMenuItem(value: option, child: Text(option))),
          ],
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
          isExpanded: true,
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
      ),
    );
  }

  Widget _buildPapersTab(bool pendingOnly) {
    return BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
      builder: (context, state) {
        if (state is QuestionPaperLoading && !_isRefreshing) {
          return _buildLoading();
        }

        if (state is QuestionPaperLoaded) {
          final papers = pendingOnly ? state.papersForReview : state.allPapersForAdmin;
          final filteredPapers = _filterPapers(papers);

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: filteredPapers.isEmpty
                ? _buildEmptyState(pendingOnly)
                : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildStatsHeader(
                    pendingOnly ? 'Pending Review' : 'All Papers',
                    filteredPapers.length,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildPaperCard(filteredPapers[index]),
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
            child: _buildErrorState(state.message),
          );
        }

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: _buildEmptyState(pendingOnly),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Manage and review submissions',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperCard(QuestionPaperEntity paper) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      ),
      child: Padding(
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
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildTag(paper.subject, AppColors.primary),
                          _buildStatusTag(paper),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<String>(
                        future: _getUserName(paper.createdBy),
                        builder: (context, snapshot) {
                          final displayName = snapshot.data ?? 'Loading...';
                          return Text(
                            'Created by $displayName',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(paper.createdAt),
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!isSmallScreen) ...[
                  _buildMetric(Icons.quiz, '${paper.totalQuestions}', 'Questions'),
                  const SizedBox(width: 16),
                  _buildMetric(Icons.grade, '${paper.totalMarks}', 'Marks'),
                  const SizedBox(width: 16),
                  _buildMetric(Icons.timer, paper.examTypeEntity.formattedDuration, 'Duration'),
                ] else
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _buildMetric(Icons.quiz, '${paper.totalQuestions}', 'Q'),
                        _buildMetric(Icons.grade, '${paper.totalMarks}', 'M'),
                        _buildMetric(Icons.timer, paper.examTypeEntity.formattedDuration, 'T'),
                      ],
                    ),
                  ),
                const Spacer(),
                _buildActions(paper),
              ],
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
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
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
    return _buildTag(text, color);
  }

  Widget _buildMetric(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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

  Widget _buildActions(QuestionPaperEntity paper) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(Icons.visibility, AppColors.primary, () => _handleViewDetails(paper.id)),
        if (paper.status.isSubmitted) ...[
          const SizedBox(width: 8),
          _buildActionButton(Icons.check, AppColors.success, () => _handleApprove(paper.id)),
          const SizedBox(width: 8),
          _buildActionButton(Icons.close, AppColors.error, () => _handleReject(paper.id, paper.title)),
        ],
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed) {
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
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)),
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isPending) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  isPending ? Icons.inbox_outlined : Icons.description_outlined,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isPending ? 'No Pending Reviews' : 'No Papers Found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                (_searchQuery.isNotEmpty || _selectedSubject.isNotEmpty)
                    ? 'No papers match your current filters'
                    : isPending
                    ? 'All papers have been reviewed\nPull down to refresh'
                    : 'No papers have been submitted yet\nPull down to refresh',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
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
        ),
      ),
    );
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