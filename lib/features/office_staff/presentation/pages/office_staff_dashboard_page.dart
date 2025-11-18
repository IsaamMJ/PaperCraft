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

  // Track collapsed subjects: Map<subject, isCollapsed>
  final Map<String, bool> _collapsedSubjects = {};

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


  // Group papers by subject only, with papers sorted by grade within each subject
  Map<String, List<QuestionPaperEntity>> _groupPapersBySubject(
    List<QuestionPaperEntity> papers,
  ) {
    final grouped = <String, List<QuestionPaperEntity>>{};

    for (final paper in papers) {
      final subject = paper.subject ?? 'Unknown';
      grouped.putIfAbsent(subject, () => []);
      grouped[subject]!.add(paper);
    }

    // Sort subjects alphabetically
    final sortedGroups = <String, List<QuestionPaperEntity>>{};
    final sortedSubjects = grouped.keys.toList()..sort();
    for (final subject in sortedSubjects) {
      // Sort papers within each subject by grade in ascending order
      final papersList = grouped[subject]!;
      papersList.sort((a, b) {
        final gradeA = a.grade ?? '';
        final gradeB = b.grade ?? '';

        // Extract numeric part from grade string (e.g., "Grade 5" -> 5)
        final gradeANum = int.tryParse(gradeA.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final gradeBNum = int.tryParse(gradeB.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

        return gradeANum.compareTo(gradeBNum);
      });
      sortedGroups[subject] = papersList;
    }

    return sortedGroups;
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
          final groupedPapers = _groupPapersBySubject(state.papers);

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: state.papers.isEmpty
                ? _buildEmptyState()
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: _buildStatsHeader('Upcoming Exams', state.papers.length),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UIConstants.paddingMedium,
                        ),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final subjects = groupedPapers.keys.toList();
                              final subject = subjects[index];
                              final papers = groupedPapers[subject]!;

                              return _buildSubjectSection(subject, papers);
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

  // Build a subject section with collapsible papers
  Widget _buildSubjectSection(String subject, List<QuestionPaperEntity> papers) {
    final isCollapsed = _collapsedSubjects[subject] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subject header with collapse/expand button
        GestureDetector(
          onTap: () {
            setState(() {
              _collapsedSubjects[subject] = !isCollapsed;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: UIConstants.spacing8, top: UIConstants.spacing8),
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.paddingMedium,
              vertical: UIConstants.spacing12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: isCollapsed ? 0 : 0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: UIConstants.spacing12),
                Container(
                  padding: const EdgeInsets.all(UIConstants.spacing8),
                  decoration: BoxDecoration(
                    color: AppColors.primary10,
                    borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.library_books,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: UIConstants.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        subject,
                        style: const TextStyle(
                          fontSize: UIConstants.fontSizeMedium,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
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
                    color: AppColors.primary10,
                    borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                  ),
                  child: Text(
                    papers.length.toString(),
                    style: const TextStyle(
                      fontSize: UIConstants.fontSizeSmall,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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
    final daysUntilExam = paper.examDate?.difference(DateTime.now()).inDays;

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
