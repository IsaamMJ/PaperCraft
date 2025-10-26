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
import '../../../paper_workflow/presentation/bloc/question_paper_bloc.dart';

class OfficeStaffDashboardPage extends StatefulWidget {
  const OfficeStaffDashboardPage({super.key});

  @override
  State<OfficeStaffDashboardPage> createState() => _OfficeStaffDashboardPageState();
}

class _OfficeStaffDashboardPageState extends State<OfficeStaffDashboardPage> {
  String _searchQuery = '';
  String _selectedGrade = '';
  String _selectedSubject = '';
  bool _isRefreshing = false;

  final _grades = ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5',
                   'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10'];
  final _subjects = ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'English',
                     'History', 'Geography'];

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  void _checkAccessAndLoad() {
    final userStateService = sl<UserStateService>();
    final isOfficeStaff = userStateService.currentRole.value == 'office_staff';
    final isAdmin = userStateService.isAdmin;

    if (!isOfficeStaff && !isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/home');
          UiHelpers.showErrorMessage(context, 'Office staff or admin access required');
        }
      });
    } else {
      _loadInitialData();
    }
  }

  void _loadInitialData() {
    // Calculate date range: today to 7 days from now
    final today = DateTime.now();
    final sevenDaysLater = today.add(const Duration(days: 7));

    context.read<QuestionPaperBloc>().add(LoadApprovedPapersByExamDateRange(
      fromDate: today,
      toDate: sevenDaysLater,
    ));
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

  void _handleViewDetails(String paperId) {
    context.push(AppRoutes.questionPaperViewWithId(paperId));
  }

  List<QuestionPaperEntity> _filterPapers(List<QuestionPaperEntity> papers) {
    if (_searchQuery.isEmpty && _selectedGrade.isEmpty && _selectedSubject.isEmpty) {
      return papers;
    }

    final searchLower = _searchQuery.toLowerCase();

    return papers.where((paper) {
      // Check grade filter
      if (_selectedGrade.isNotEmpty && paper.grade != _selectedGrade) {
        return false;
      }

      // Check subject filter
      if (_selectedSubject.isNotEmpty && paper.subject != _selectedSubject) {
        return false;
      }

      // Early return if no search query
      if (_searchQuery.isEmpty) return true;

      // Search in title
      return paper.title.toLowerCase().contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocListener<QuestionPaperBloc, QuestionPaperState>(
        listener: (context, state) {
          if (state is QuestionPaperError) {
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
                'Upcoming Exams (Next 7 Days)',
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
            color: AppColors.black04,
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
              border: Border.all(color: AppColors.border),
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
                  'Grade',
                  _selectedGrade,
                  _grades,
                  (v) => setState(() => _selectedGrade = v ?? ''),
                ),
              ),
              const SizedBox(width: UIConstants.spacing8),
              Expanded(
                child: _buildFilterChip(
                  'Subject',
                  _selectedSubject,
                  _subjects,
                  (v) => setState(() => _selectedSubject = v ?? ''),
                ),
              ),
              if (_selectedGrade.isNotEmpty || _selectedSubject.isNotEmpty || _searchQuery.isNotEmpty) ...[
                const SizedBox(width: UIConstants.spacing8),
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedGrade = '';
                    _selectedSubject = '';
                    _searchQuery = '';
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UIConstants.spacing12,
                      vertical: UIConstants.spacing8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error10,
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
        color: value.isNotEmpty ? AppColors.primary10 : AppColors.background,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(
          color: value.isNotEmpty ? AppColors.primary : AppColors.border,
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

        if (state is ApprovedPapersByExamDateLoaded) {
          final filteredPapers = _filterPapers(state.papers);

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: filteredPapers.isEmpty
                ? _buildEmptyState()
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildStatsHeader('Upcoming Exams', filteredPapers.length),
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
        border: Border.all(color: AppColors.primary10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(UIConstants.paddingSmall),
            decoration: BoxDecoration(
              color: AppColors.primary10,
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            ),
            child: const Icon(
              Icons.event_note,
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
                  'Papers with exams scheduled in the next 7 days',
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

    // Calculate days until exam
    final daysUntilExam = paper.examDate != null
        ? paper.examDate!.difference(DateTime.now()).inDays
        : null;

    return Container(
      key: ValueKey(paper.id),
      margin: const EdgeInsets.only(bottom: UIConstants.spacing12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.black04,
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
                          _buildTag(paper.grade ?? 'Unknown Grade', AppColors.success),
                          if (paper.examType.displayName.isNotEmpty)
                            _buildTag(paper.examType.displayName, AppColors.warning),
                        ],
                      ),
                    ],
                  ),
                ),
                if (paper.examDate != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppDateUtils.formatShortDate(paper.examDate!),
                        style: const TextStyle(
                          fontSize: UIConstants.fontSizeSmall,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (daysUntilExam != null)
                        Container(
                          margin: const EdgeInsets.only(top: UIConstants.spacing4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: UIConstants.spacing8,
                            vertical: UIConstants.spacing4,
                          ),
                          decoration: BoxDecoration(
                            color: daysUntilExam <= 1 ? AppColors.error10 : AppColors.warning10,
                            borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                          ),
                          child: Text(
                            daysUntilExam == 0
                                ? 'Today'
                                : daysUntilExam == 1
                                    ? 'Tomorrow'
                                    : 'In $daysUntilExam days',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: daysUntilExam <= 1 ? AppColors.error : AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
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
                _buildViewButton(paper),
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
        color: color == AppColors.primary
            ? AppColors.primary10
            : color == AppColors.success
                ? AppColors.success10
                : color == AppColors.warning
                    ? AppColors.warning10
                    : AppColors.error10,
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

  Widget _buildViewButton(QuestionPaperEntity paper) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.primary10,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleViewDetails(paper.id),
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          child: const Icon(
            Icons.visibility,
            size: UIConstants.iconSmall,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const LoadingWidget(message: 'Loading upcoming exams...');
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: EmptyMessageWidget(
          icon: Icons.event_busy,
          title: 'No Upcoming Exams',
          message: (_searchQuery.isNotEmpty || _selectedGrade.isNotEmpty || _selectedSubject.isNotEmpty)
              ? 'No papers match your current filters'
              : 'No exams scheduled in the next 7 days\nPull down to refresh',
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
