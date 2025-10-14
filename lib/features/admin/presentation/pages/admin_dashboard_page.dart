import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/presentation/utils/date_utils.dart';
import '../../../../core/presentation/utils/ui_helpers.dart';
import '../../../../core/presentation/widgets/common_state_widgets.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/domain/services/user_info_service.dart';
import '../../../paper_workflow/presentation/bloc/question_paper_bloc.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final UserInfoService _userInfoService;
  final Map<String, String> _userNames = {};

  String _searchQuery = '';
  String _selectedSubject = '';
  bool _isRefreshing = false;

  final _subjects = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English', 'History', 'Geography'];

  @override
  void initState() {
    super.initState();
    _userInfoService = sl<UserInfoService>();
    _checkAdminAndLoad();
  }

  void _checkAdminAndLoad() {
    final isAdmin = sl<UserStateService>().isAdmin;
    if (!isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/home');
          UiHelpers.showErrorMessage(context, 'Admin access required');
        }
      });
    } else {
      _loadInitialData();
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
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        subscription.cancel();
        if (mounted) setState(() => _isRefreshing = false);
      },
    );
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(UIConstants.paddingSmall),
              decoration: BoxDecoration(
                color: confirmColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
              child: Icon(icon, color: confirmColor, size: 20),
            ),
            const SizedBox(width: UIConstants.spacing12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: UIConstants.fontSizeLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          content,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(UIConstants.paddingSmall),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
              child: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: UIConstants.spacing12),
            const Expanded(
              child: Text(
                'Reject Paper',
                style: TextStyle(fontSize: UIConstants.fontSizeLarge),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(UIConstants.spacing12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
              child: Text(
                'Paper: $paperTitle',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: UIConstants.spacing16),
            const Text(
              'Rejection reason:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: UIConstants.spacing8),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Enter reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                ),
                contentPadding: const EdgeInsets.all(UIConstants.spacing12),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  List<QuestionPaperEntity> _filterPapers(List<QuestionPaperEntity> papers) {
    // Performance optimization: early return if no filters applied
    if (_searchQuery.isEmpty && _selectedSubject.isEmpty) {
      return papers;
    }

    // Calculate lowercase once instead of for each paper
    final searchLower = _searchQuery.toLowerCase();

    return papers.where((paper) {
      // Check subject first (faster check)
      if (_selectedSubject.isNotEmpty && paper.subject != _selectedSubject) {
        return false;
      }

      // Early return if no search query
      if (_searchQuery.isEmpty) return true;

      // Only calculate lowercase once per paper
      return paper.title.toLowerCase().contains(searchLower) ||
          paper.createdBy.toLowerCase().contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocListener<QuestionPaperBloc, QuestionPaperState>(
        listener: (context, state) {
          if (state is QuestionPaperSuccess) {
            UiHelpers.showSuccessMessage(context, state.message);
            _loadInitialData();
          } else if (state is QuestionPaperError) {
            UiHelpers.showErrorMessage(context, state.message);
          }
        },
        child: Column(
          children: [
            _buildSearchAndFilters(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: UIConstants.paddingMedium,
                vertical: UIConstants.spacing12,
              ),
              child: const Text(
                'All Papers',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeXXLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(child: _buildPapersList()),
          ],
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
      padding: EdgeInsets.fromLTRB(
        UIConstants.paddingMedium,
        MediaQuery.of(context).padding.top + UIConstants.paddingMedium,
        UIConstants.paddingMedium,
        UIConstants.paddingMedium,
      ),
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
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search papers...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textSecondary,
                  size: UIConstants.iconMedium,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  onPressed: () => setState(() => _searchQuery = ''),
                  icon: const Icon(Icons.clear, size: UIConstants.iconSmall),
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: UIConstants.paddingMedium,
                  vertical: UIConstants.spacing12,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          const SizedBox(height: UIConstants.spacing12),
          Row(
            children: [
              Expanded(
                child: _buildFilterChip(
                  'Subject',
                  _selectedSubject,
                  _subjects,
                      (v) => setState(() => _selectedSubject = v ?? ''),
                ),
              ),
              if (_selectedSubject.isNotEmpty || _searchQuery.isNotEmpty) ...[
                const SizedBox(width: UIConstants.spacing8),
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedSubject = '';
                    _searchQuery = '';
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UIConstants.spacing12,
                      vertical: UIConstants.spacing8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.clear,
                          size: UIConstants.iconSmall,
                          color: AppColors.error,
                        ),
                        SizedBox(width: UIConstants.spacing4),
                        Text(
                          'Clear',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: UIConstants.fontSizeSmall,
                          ),
                        ),
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

  Widget _buildFilterChip(
      String label,
      String value,
      List<String> options,
      ValueChanged<String?> onChanged,
      ) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: value.isNotEmpty
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(
          color: value.isNotEmpty
              ? AppColors.primary
              : AppColors.border.withValues(alpha: 0.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: UIConstants.spacing12),
            child: Text(
              label,
              style: const TextStyle(fontSize: UIConstants.fontSizeMedium),
            ),
          ),
          items: [
            DropdownMenuItem(value: '', child: Text('All ${label}s')),
            ...options.map((option) =>
                DropdownMenuItem(value: option, child: Text(option))),
          ],
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down, size: UIConstants.iconSmall),
          isExpanded: true,
          style: const TextStyle(
            fontSize: UIConstants.fontSizeMedium,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildPapersList() {
    return BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
      builder: (context, state) {
        if (state is QuestionPaperLoading && !_isRefreshing) {
          return _buildLoading();
        }

        if (state is QuestionPaperLoaded) {
          final filteredPapers = _filterPapers(state.allPapersForAdmin);

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: filteredPapers.isEmpty
                ? _buildEmptyState()
                : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _buildStatsHeader('All Papers', filteredPapers.length),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConstants.paddingMedium,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildPaperCard(filteredPapers[index]),
                      childCount: filteredPapers.length,
                      addAutomaticKeepAlives: true,
                      addRepaintBoundaries: true,
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
          child: _buildEmptyState(),
        );
      },
    );
  }

  Widget _buildStatsHeader(String title, int count) {
    return Container(
      margin: const EdgeInsets.all(UIConstants.paddingMedium),
      padding: const EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient.scale(0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(UIConstants.paddingSmall),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            ),
            child: const Icon(
              Icons.assignment,
              size: UIConstants.iconMedium,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: UIConstants.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Papers in $title',
                  style: const TextStyle(
                    fontSize: UIConstants.fontSizeLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Text(
                  'Manage and review submissions',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    color: AppColors.textSecondary,
                  ),
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
      key: ValueKey(paper.id),
      margin: const EdgeInsets.only(bottom: UIConstants.spacing12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.paddingMedium),
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
                          fontSize: isSmallScreen
                              ? UIConstants.fontSizeMedium
                              : UIConstants.fontSizeLarge,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: UIConstants.spacing8),
                      Wrap(
                        spacing: UIConstants.spacing8,
                        runSpacing: UIConstants.spacing4,
                        children: [
                          _buildTag(paper.subject ?? 'Unknown Subject', AppColors.primary),
                          _buildStatusTag(paper),
                        ],
                      ),
                      const SizedBox(height: UIConstants.spacing8),
                      FutureBuilder<String>(
                        future: _getUserName(paper.createdBy),
                        builder: (context, snapshot) {
                          final displayName = snapshot.data ?? 'Loading...';
                          return Text(
                            'Created by $displayName',
                            style: const TextStyle(
                              fontSize: UIConstants.fontSizeSmall,
                              color: AppColors.textSecondary,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Text(
                  AppDateUtils.formatShortDate(paper.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                )
              ],
            ),
            const SizedBox(height: UIConstants.spacing12),
            Row(
              children: [
                if (!isSmallScreen) ...[
                  _buildMetric(Icons.quiz, '${paper.totalQuestions}', 'Questions'),
                  const SizedBox(width: UIConstants.spacing16),
                  _buildMetric(Icons.grade, '${paper.totalMarks}', 'Marks'),
                ] else
                  Expanded(
                    child: Wrap(
                      spacing: UIConstants.spacing12,
                      runSpacing: UIConstants.spacing8,
                      children: [
                        _buildMetric(Icons.quiz, '${paper.totalQuestions}', 'Q'),
                        _buildMetric(Icons.grade, '${paper.totalMarks}', 'M'),
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
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.spacing8,
        vertical: UIConstants.spacing4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
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
    return _buildTag(text, color);
  }

  Widget _buildMetric(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: UIConstants.spacing4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
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
        _buildActionButton(
          Icons.visibility,
          AppColors.primary,
              () => _handleViewDetails(paper.id),
        ),
        if (paper.status.isSubmitted) ...[
          const SizedBox(width: UIConstants.spacing8),
          _buildActionButton(
            Icons.check,
            AppColors.success,
                () => _handleApprove(paper.id),
          ),
          const SizedBox(width: UIConstants.spacing8),
          _buildActionButton(
            Icons.close,
            AppColors.error,
                () => _handleReject(paper.id, paper.title),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          child: Icon(icon, size: UIConstants.iconSmall, color: color),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const LoadingWidget(message: 'Loading papers...');
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: EmptyMessageWidget(
          icon: Icons.description_outlined,
          title: 'No Papers Found',
          message: (_searchQuery.isNotEmpty || _selectedSubject.isNotEmpty)
              ? 'No papers match your current filters'
              : 'No papers have been submitted yet\nPull down to refresh',
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: ErrorStateWidget(
          message: message,
          onRetry: _loadInitialData,
        ),
      ),
    );
  }
}