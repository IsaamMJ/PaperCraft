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
  bool _isRefreshing = false;

  // Cache today's date at midnight to avoid repeated calculations
  late final DateTime _cachedTodayDate = _initializeTodayDate();

  // Track collapsed dates: Map<dateString, isCollapsed>
  final Map<String, bool> _collapsedDates = {};

  // Cache for formatted dates: Map<dateString, formatted>
  final Map<String, String> _formattedDateCache = {};

  DateTime _initializeTodayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Get days until exam from today
  int _getDaysUntilExam(DateTime? examDate) {
    if (examDate == null) return -1;
    final examDateOnly = DateTime(examDate.year, examDate.month, examDate.day);
    return examDateOnly.difference(_cachedTodayDate).inDays;
  }

  /// Normalize date to midnight for consistent comparisons
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  @override
  void didUpdateWidget(covariant OfficeStaffDashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload papers if they appear to be empty (came back from navigation)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<QuestionPaperBloc>().state;
      if (state is QuestionPaperLoaded && state.approvedPapers.isEmpty && mounted) {
        _loadInitialData();
      }
    });
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

  /// Check if an exam is still upcoming (today or in the future, comparing by date only)
  bool _isUpcomingExam(DateTime? examDate) {
    if (examDate == null) return false;
    return _getDaysUntilExam(examDate) >= 0;
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
    // Navigate directly to PDF preview page (skipping paper details)
    // This provides a faster, more streamlined experience for office staff
    context.push(AppRoutes.officeStaffPdfPreviewWithId(paperId));
  }


  /// Group papers by exam date, sorted chronologically (O(n) operation)
  Map<DateTime, List<QuestionPaperEntity>> _groupPapersByExamDate(
    List<QuestionPaperEntity> papers,
  ) {
    final grouped = <DateTime, List<QuestionPaperEntity>>{};

    for (final paper in papers) {
      if (paper.examDate == null) continue;

      final examDateOnly = _normalizeDate(paper.examDate!);
      grouped.putIfAbsent(examDateOnly, () => []).add(paper);
    }

    // Return sorted map entries (avoids creating duplicate map)
    return Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  /// Get urgency colors (foreground and background) for a given date - combined to avoid redundant calculations
  Map<String, Color> _getDateUrgencyColors(DateTime examDate) {
    final daysUntil = _getDaysUntilExam(examDate);

    Color fgColor;
    Color bgColor;

    if (daysUntil == 1) {
      fgColor = AppColors.error;      // Tomorrow - Red
      bgColor = AppColors.error10;
    } else if (daysUntil <= 3) {
      fgColor = AppColors.warning;    // Next 2-3 days - Orange
      bgColor = AppColors.warning10;
    } else {
      fgColor = AppColors.primary;    // Rest - Blue
      bgColor = AppColors.primary10;
    }

    return {'fg': fgColor, 'bg': bgColor};
  }

  /// Format date with day label (e.g., "Tomorrow, Nov 26" or "Wednesday, Nov 27") - with caching
  String _formatDateWithLabel(DateTime date) {
    final dateKey = date.toString().split(' ')[0]; // YYYY-MM-DD format

    // Return cached formatted date if available
    if (_formattedDateCache.containsKey(dateKey)) {
      return _formattedDateCache[dateKey]!;
    }

    final daysUntil = _getDaysUntilExam(date);
    final dateStr = AppDateUtils.formatShortDate(date);

    final formatted = daysUntil == 0
        ? 'Today, $dateStr'
        : daysUntil == 1
            ? 'Tomorrow, $dateStr'
            : '${_getDayName(_normalizeDate(date))}, $dateStr';

    // Cache the formatted date
    _formattedDateCache[dateKey] = formatted;
    return formatted;
  }

  String _getDayName(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
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
            Expanded(child: _buildPapersList()),
          ],
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
          // Filter out papers with exam dates in the past (before today)
          final upcomingPapers = state.papers
              .where((paper) => _isUpcomingExam(paper.examDate))
              .toList();

          final groupedPapers = _groupPapersByExamDate(upcomingPapers);

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: upcomingPapers.isEmpty
                ? _buildEmptyState()
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildStatsHeader('Upcoming Exams', upcomingPapers.length),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UIConstants.paddingMedium,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final dates = groupedPapers.keys.toList();
                              final date = dates[index];
                              final papers = groupedPapers[date]!;

                              return _buildDateSection(date, papers);
                            },
                            childCount: groupedPapers.length,
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

  /// Build a date section with papers for that date
  Widget _buildDateSection(DateTime date, List<QuestionPaperEntity> papers) {
    final dateKey = date.toString().split(' ')[0]; // YYYY-MM-DD format

    // Check if this is tomorrow - default: open for tomorrow, closed for others
    final daysUntil = _getDaysUntilExam(date);
    final isTomorrow = daysUntil == 1;

    final isCollapsed = _collapsedDates[dateKey] ?? !isTomorrow;
    final colors = _getDateUrgencyColors(date);
    final urgencyColor = colors['fg']!;
    final urgencyBgColor = colors['bg']!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header with collapse/expand button
        GestureDetector(
          onTap: () {
            setState(() {
              _collapsedDates[dateKey] = !isCollapsed;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: UIConstants.spacing8, top: UIConstants.spacing8),
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.paddingMedium,
              vertical: UIConstants.spacing12,
            ),
            decoration: BoxDecoration(
              color: urgencyBgColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
              border: Border.all(color: urgencyColor.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: isCollapsed ? 0 : 0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    color: urgencyColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: UIConstants.spacing12),
                Container(
                  padding: const EdgeInsets.all(UIConstants.spacing8),
                  decoration: BoxDecoration(
                    color: urgencyBgColor,
                    borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                  ),
                  child: Icon(
                    Icons.event,
                    size: 16,
                    color: urgencyColor,
                  ),
                ),
                const SizedBox(width: UIConstants.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDateWithLabel(date),
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeMedium,
                          fontWeight: FontWeight.w600,
                          color: urgencyColor,
                        ),
                      ),
                      Text(
                        '${papers.length} ${papers.length == 1 ? 'paper' : 'papers'}',
                        style: const TextStyle(
                          fontSize: UIConstants.fontSizeSmall,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: UIConstants.spacing8,
                    vertical: UIConstants.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: urgencyBgColor,
                    borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                  ),
                  child: Text(
                    papers.length.toString(),
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeSmall,
                      fontWeight: FontWeight.w700,
                      color: urgencyColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Papers list (collapsed/expanded)
        if (!isCollapsed)
          Column(
            children: [
              ...papers.map((paper) => _buildPaperCard(paper)),
            ],
          ),
      ],
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
    final daysUntilExam = _getDaysUntilExam(paper.examDate);

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
                      if (daysUntilExam >= 0)
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

  /// Get background color for tag based on foreground color
  Color _getTagBgColor(Color fgColor) {
    if (fgColor == AppColors.primary) return AppColors.primary10;
    if (fgColor == AppColors.success) return AppColors.success10;
    if (fgColor == AppColors.warning) return AppColors.warning10;
    return AppColors.error10;
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.spacing8,
        vertical: UIConstants.spacing4,
      ),
      decoration: BoxDecoration(
        color: _getTagBgColor(color),
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
        child: const EmptyMessageWidget(
          icon: Icons.event_busy,
          title: 'No Upcoming Exams',
          message: 'No exams scheduled in the next 7 days\nPull down to refresh',
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
