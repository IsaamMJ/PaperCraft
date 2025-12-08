import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/presentation/utils/ui_helpers.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/domain/entities/paper_status.dart';
import '../../../paper_workflow/presentation/bloc/question_paper_bloc.dart';
import '../../../paper_workflow/presentation/widgets/paper_status_badge.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _isRefreshing = false;
  final Map<String, bool> _expandedDates = {}; // Track expanded state per date (dateString -> isExpanded)
  final Map<String, bool> _expandedExams = {}; // Track expanded state per exam (dateString::examName -> isExpanded)
  final Map<String, bool> _expandedSubjects = {}; // Track expanded subjects per exam (dateString::examName::subject -> isExpanded)

  @override
  void initState() {
    super.initState();
    _checkAdminAndLoad();
  }

  void _checkAdminAndLoad() {
    final userStateService = sl<UserStateService>();
    final isAdminOrReviewer = userStateService.isAdminOrReviewer;

    debugPrint('[DEBUG ADMIN DASHBOARD] Checking access - isAdmin: ${userStateService.isAdmin}, isReviewer: ${userStateService.isReviewer}');

    if (!isAdminOrReviewer) {
      debugPrint('[DEBUG ADMIN DASHBOARD] Access denied - not admin or reviewer');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/home');
          UiHelpers.showErrorMessage(context, 'Admin access required');
        }
      });
    } else {
      debugPrint('[DEBUG ADMIN DASHBOARD] Access granted - loading papers');
      _loadInitialData();
    }
  }

  void _loadInitialData() {
    debugPrint('[DEBUG ADMIN DASHBOARD] Loading all papers for admin/reviewer');
    context.read<QuestionPaperBloc>().add(const LoadAllPapersForAdmin());
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });

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
    context.go(AppRoutes.questionPaperViewWithId(paperId));
  }

  bool _isExamDatePassed(DateTime? examDate) {
    if (examDate == null) return false;
    return DateTime.now().isAfter(examDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        backgroundColor: AppColors.surface,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildHeader(),
            _buildContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(UIConstants.paddingMedium),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary08,
              AppColors.secondary08,
            ],
          ),
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        child: Text(
          sl<UserStateService>().currentTenantName,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: BlocListener<QuestionPaperBloc, QuestionPaperState>(
        listener: (context, state) {
          if (state is QuestionPaperSuccess) {
            UiHelpers.showSuccessMessage(context, state.message);
            _loadInitialData();
          } else if (state is QuestionPaperError) {
            UiHelpers.showErrorMessage(context, state.message);
          }
        },
        child: BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
          builder: (context, state) {
            debugPrint('[DEBUG ADMIN DASHBOARD] Current state: ${state.runtimeType}');

            if (state is QuestionPaperLoading && !_isRefreshing) {
              debugPrint('[DEBUG ADMIN DASHBOARD] State: Loading');
              return _buildLoading();
            }
            if (state is QuestionPaperError) {
              debugPrint('[DEBUG ADMIN DASHBOARD] State: Error - ${state.message}');
              return _buildError(state.message);
            }
            if (state is QuestionPaperLoaded) {
              final papers = state.allPapersForAdmin;
              debugPrint('[DEBUG ADMIN DASHBOARD] State: Loaded - ${papers.length} papers');
              if (papers.isEmpty) {
                return _buildEmptyState();
              }
              return _buildPapersView(papers);
            }
            debugPrint('[DEBUG ADMIN DASHBOARD] State: Default (empty state)');
            return _buildEmptyState();
          },
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading papers...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text('Error loading papers', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No question papers', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Papers will appear once teachers submit them',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPapersView(List<QuestionPaperEntity> allPapers) {
    // Filter: Only upcoming exams, papers must have exam name
    final upcomingPapers = allPapers
        .where((paper) {
          if (paper.examName == null || paper.examName!.isEmpty) return false;
          final examDate = paper.examTimetableDate ?? paper.examDate;
          return examDate == null || !_isExamDatePassed(examDate);
        })
        .toList();

    if (upcomingPapers.isEmpty) {
      return _buildEmptyState();
    }

    // Group by date, then by exam, then by subject
    final papersByDateAndExam = <DateTime, Map<String, List<QuestionPaperEntity>>>{};

    for (final paper in upcomingPapers) {
      final examDate = paper.examTimetableDate ?? paper.examDate ?? DateTime(2999);
      final examName = paper.examName!;

      papersByDateAndExam.putIfAbsent(examDate, () => {});
      papersByDateAndExam[examDate]!.putIfAbsent(examName, () => []).add(paper);
    }

    // Sort dates in ascending order (earliest first)
    final sortedDates = papersByDateAndExam.keys.toList()..sort();

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Text(
              'UPCOMING EXAMS',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          ...sortedDates.map((date) {
            final examsOnDate = papersByDateAndExam[date]!;
            return _buildCollapsibleDateSection(date, examsOnDate);
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCollapsibleDateSection(DateTime date, Map<String, List<QuestionPaperEntity>> examsOnDate) {
    final dateKey = '${date.year}-${date.month}-${date.day}';
    final isDateExpanded = _expandedDates[dateKey] ?? true;
    final formattedDate = '${date.day} ${_getMonthName(date.month)} ${date.year}';

    // Sort exams by name
    final sortedExamNames = examsOnDate.keys.toList()..sort();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header (collapsible)
          GestureDetector(
            onTap: () {
              setState(() {
                _expandedDates[dateKey] = !isDateExpanded;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary10, AppColors.secondary10],
                ),
                borderRadius: isDateExpanded
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      )
                    : BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    isDateExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                  Text(
                    '${sortedExamNames.length} exam${sortedExamNames.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Exams on this date (shown only if date is expanded)
          if (isDateExpanded)
            ...sortedExamNames.map((examName) {
              final examPapers = examsOnDate[examName]!;
              return _buildExamSection(dateKey, examName, examPapers);
            }),
        ],
      ),
    );
  }

  Widget _buildExamSection(String dateKey, String examName, List<QuestionPaperEntity> papers) {
    final examKey = '$dateKey::$examName';
    final isExpanded = _expandedExams[examKey] ?? true;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exam header (collapsible)
          GestureDetector(
            onTap: () {
              setState(() {
                _expandedExams[examKey] = !isExpanded;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      examName,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                  Text(
                    '${papers.length} paper${papers.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Papers grouped by subject (shown only if exam is expanded)
          if (isExpanded) _buildExamPapersList(dateKey, examName, papers),
        ],
      ),
    );
  }

  Widget _buildExamPapersList(String dateKey, String examName, List<QuestionPaperEntity> papers) {
    // Group papers by subject
    final papersBySubject = <String, List<QuestionPaperEntity>>{};
    for (final paper in papers) {
      final subject = paper.subject ?? 'Unassigned Subject';
      papersBySubject.putIfAbsent(subject, () => []).add(paper);
    }

    // Pre-compute earliest dates for each subject (O(n) instead of O(n²))
    final subjectEarliestDates = <String, DateTime?>{};
    for (final subject in papersBySubject.keys) {
      subjectEarliestDates[subject] = papersBySubject[subject]!
          .map((p) => p.examTimetableDate ?? p.examDate)
          .whereType<DateTime>()
          .fold<DateTime?>(null, (prev, curr) => prev == null || curr.isBefore(prev) ? curr : prev);
    }

    // Sort subjects by earliest date, then alphabetically
    final sortedSubjects = papersBySubject.keys.toList()
      ..sort((subjectA, subjectB) {
        final dateA = subjectEarliestDates[subjectA];
        final dateB = subjectEarliestDates[subjectB];

        if (dateA != null && dateB != null) {
          return dateA.compareTo(dateB);
        } else if (dateA != null) {
          return -1;
        } else if (dateB != null) {
          return 1;
        }
        return subjectA.compareTo(subjectB);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...sortedSubjects.asMap().entries.map((entry) {
          final index = entry.key;
          final subject = entry.value;
          final subjectPapers = papersBySubject[subject]!;
          final isLastSubject = index == sortedSubjects.length - 1;

          // Create unique key for subject expand/collapse state
          final subjectKey = '$dateKey::$examName::$subject';
          final isExpanded = _expandedSubjects[subjectKey] ?? false;

          // Group papers by grade within this subject
          final papersByGrade = <String, List<QuestionPaperEntity>>{};
          for (final paper in subjectPapers) {
            final grade = paper.gradeNumber?.toString() ?? 'Unassigned Grade';
            papersByGrade.putIfAbsent(grade, () => []).add(paper);
          }

          // Sort grades naturally (numerically if possible)
          final sortedGrades = papersByGrade.keys.toList()..sort((a, b) {
            final aNum = int.tryParse(a);
            final bNum = int.tryParse(b);
            if (aNum != null && bNum != null) {
              return aNum.compareTo(bNum);
            }
            return a.compareTo(b);
          });

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject subheader - COLLAPSIBLE
              GestureDetector(
                onTap: () {
                  setState(() {
                    _expandedSubjects[subjectKey] = !isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(32, 12, 16, 12),
                  color: Colors.grey[50],
                  child: Row(
                    children: [
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          subject,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                        ),
                      ),
                      Text(
                        '(${subjectPapers.length})',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              // Group papers by grade - VISIBLE ONLY IF SUBJECT IS EXPANDED
              if (isExpanded)
                ...sortedGrades.asMap().entries.map((gradeEntry) {
                  final gradeIndex = gradeEntry.key;
                  final grade = gradeEntry.value;
                  final gradePapers = papersByGrade[grade]!;

                  // Sort papers by date once
                  gradePapers.sort((a, b) {
                    final dateA = a.examTimetableDate ?? a.examDate ?? DateTime(2999);
                    final dateB = b.examTimetableDate ?? b.examDate ?? DateTime(2999);
                    return dateA.compareTo(dateB);
                  });

                  final isLastGrade = gradeIndex == sortedGrades.length - 1;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Grade sub-header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(48, 8, 16, 6),
                        child: Text(
                          'Grade $grade',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                        ),
                      ),
                      // Papers for this grade (sorted by date)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: gradePapers.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1, color: Colors.grey[200], indent: 48, endIndent: 16),
                        itemBuilder: (context, idx) => _buildPaperCard(gradePapers[idx]),
                      ),
                      // Add divider between grades (except after last)
                      if (!isLastGrade)
                        Divider(height: 1, color: Colors.grey[100], indent: 16, endIndent: 16),
                    ],
                  );
                }),
              // Add divider between subjects (except after last)
              if (!isLastSubject)
                Divider(height: 1, color: Colors.grey[200], indent: 0, endIndent: 0),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildPaperCard(QuestionPaperEntity paper) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _handleViewDetails(paper.id);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 60,
                decoration: BoxDecoration(
                  color: _getStatusColor(paper.status),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(paper.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        PaperStatusBadge(status: paper.status),
                        const SizedBox(width: 12),
                        Text(
                          'By ${paper.createdByName ?? 'Unknown'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(PaperStatus status) {
    switch (status) {
      case PaperStatus.approved:
        return Colors.green;
      case PaperStatus.draft:
        return Colors.orange;
      case PaperStatus.rejected:
        return Colors.red;
      case PaperStatus.submitted:
        return Colors.blue;
      case PaperStatus.spare:
        return Colors.orange;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}