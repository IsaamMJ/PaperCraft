// features/home/presentation/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/presentation/utils/date_formatter_helper.dart';
import '../../../../core/presentation/widgets/common_state_widgets.dart';
import '../../../../core/presentation/widgets/connectivity_indicator.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../../../paper_workflow/domain/entities/paper_status.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/presentation/widgets/paper_status_badge.dart';
import '../../../notifications/presentation/bloc/notification_bloc.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _isRefreshing = false;
  bool _hasLoadedInitialData = false;
  Timer? _notificationRefreshTimer;
  bool _isAppInForeground = true;

  // Cache the last valid HomeLoaded state to preserve data across navigation
  HomeLoaded? _cachedHomeState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load data immediately - no delay for instant skeleton display
    if (!_hasLoadedInitialData) {
      _loadInitialData();
      _hasLoadedInitialData = true;
      _startNotificationRefresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _isAppInForeground = state == AppLifecycleState.resumed;
  }

  void _startNotificationRefresh() {
    _notificationRefreshTimer?.cancel(); // Cancel existing timer first to prevent memory leaks
    _notificationRefreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      // Only refresh if app is in foreground
      if (mounted && _isAppInForeground) {
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated && authState.user.role != UserRole.admin) {
          context.read<NotificationBloc>().add(
            RefreshNotifications(authState.user.id),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationRefreshTimer?.cancel();
    _cachedHomeState = null; // Clear cached state to free memory
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Auto-reload if coming from another page with stale data
    final currentState = context.read<HomeBloc>().state;
    if (currentState is! HomeLoaded && currentState is! HomeLoading && currentState is! HomeError) {
      if (_hasLoadedInitialData) {
        _loadInitialData();
      }
    }
  }

  void _loadInitialData() {
    final authState = context.read<AuthBloc>().state;

    if (authState is! AuthAuthenticated) {
      return;
    }

    final isAdmin = authState.user.role == UserRole.admin;

    // Load home page data using HomeBloc
    context.read<HomeBloc>().add(LoadHomePapers(
      isAdmin: isAdmin,
      userId: isAdmin ? null : authState.user.id,
    ));

    // Enable realtime updates for instant paper changes
    context.read<HomeBloc>().add(EnableRealtimeUpdates(
      isAdmin: isAdmin,
      userId: isAdmin ? null : authState.user.id,
    ));

    // Load notifications and classes for teachers
    if (!isAdmin) {
      context.read<NotificationBloc>().add(LoadUnreadCount(authState.user.id));
      // Load teacher's assigned classes for the classes card section
      if (authState.user.tenantId != null) {
        context.read<HomeBloc>().add(
          LoadTeacherClasses(
            userId: authState.user.id,
            tenantId: authState.user.tenantId!,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final user = authState.user;
        final isAdmin = user.role == UserRole.admin;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: _handleRefresh,
            backgroundColor: AppColors.surface,
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildHeader(user, isAdmin),
                _buildContent(isAdmin),
              ],
            ),
          ),
          floatingActionButton: null,
        );
      },
    );
  }

  Widget _buildHeader(dynamic user, bool isAdmin) {
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
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: UIConstants.fontSizeMedium,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: UIConstants.spacing4),
                      Text(
                        user.fullName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Connectivity and notification for teachers
                if (!isAdmin) ...[
                  const ConnectivityIndicator(),
                  const SizedBox(width: 8),
                  _buildNotificationBell(),
                  const SizedBox(width: 12),
                ],
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary30,
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'T',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isAdmin) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          // Show loading skeleton immediately for Loading state
          if (state is HomeLoading) {
            // If we have cached data and it's a refresh, show data with loading indicator
            if (_cachedHomeState != null) {
              final papers = _getAllPapers(_cachedHomeState!, isAdmin);
              return _buildPapersListWithTabs(papers, isAdmin);
            }
            // Show skeleton for initial load
            return _buildLoading();
          }

          if (state is HomeError) {
            String errorMessage = state.message;
            if (errorMessage.toLowerCase().contains('admin') ||
                errorMessage.toLowerCase().contains('privilege')) {
              errorMessage = 'Permission issue detected. Please log out and log back in.';

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showAuthErrorDialog();
                }
              });
            }
            // If we have cached data, show it even on error
            if (_cachedHomeState != null) {
              final papers = _getAllPapers(_cachedHomeState!, isAdmin);
              return _buildPapersListWithTabs(papers, isAdmin);
            }
            return _buildError(errorMessage);
          }

          if (state is HomeLoaded) {
            // Cache this state for future use
            _cachedHomeState = state;
            final papers = _getAllPapers(state, isAdmin);
            return _buildPapersListWithTabs(papers, isAdmin);
          }

          // Fallback: show cached data or empty state
          if (_cachedHomeState != null) {
            final papers = _getAllPapers(_cachedHomeState!, isAdmin);
            return _buildPapersListWithTabs(papers, isAdmin);
          }

          return _buildEmpty(isAdmin);
        },
      ),
    );
  }

  void _showAuthErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Issue'),
        content: const Text(
          'There seems to be an issue with your authentication. Would you like to log out and log back in?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthBloc>().add(const AuthSignOut());
            },
            child: const Text('Log Out'),
          ),
        ],
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
              'Loading your papers...',
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
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 200,
        child: ErrorStateWidget(
          message: message,
          onRetry: _loadInitialData,
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isAdmin) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 250,
        child: EmptyMessageWidget(
          icon: Icons.description_outlined,
          title: isAdmin ? 'No papers to review' : 'No papers yet',
          message: isAdmin
              ? 'Papers submitted by teachers will appear here'
              : 'Create your first question paper to get started',
        ),
      ),
    );
  }

  Widget _buildPapersListWithTabs(List<QuestionPaperEntity> papers, bool isAdmin) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        // Separate auto-assigned and manual papers
        // Auto-assigned papers come from exam timetables (created by office staff)
        // Manual papers are created by teachers
        final autoAssignedPapers = papers.where((p) => p.isAutoAssigned).toList();
        final manualPapers = papers.where((p) => !p.isAutoAssigned).toList();

        // DEBUG: Print all papers and their classification
        for (final paper in papers) {
          print('[DEBUG PAPERS] Paper ID: ${paper.id}, Status: ${paper.status}, isAutoAssigned: ${paper.isAutoAssigned}');
        }

        // Build list items: Assigned section + Assigned papers (grouped by exam) + Manual section + Manual papers
        final listItems = <_PaperListItem>[];

        if (!isAdmin) {
          // Add assigned section header
          listItems.add(_AssignedSectionHeader());

          if (autoAssignedPapers.isEmpty) {
            listItems.add(_EmptyAssignedState());
          } else {
            // Sort auto-assigned papers by exam date (upcoming first)
            final sortedPapers = List<QuestionPaperEntity>.from(autoAssignedPapers);
            sortedPapers.sort((a, b) {
              final dateA = a.examTimetableDate ?? DateTime(2099);
              final dateB = b.examTimetableDate ?? DateTime(2099);
              return dateA.compareTo(dateB);
            });

            // Group auto-assigned papers by exam name (maintains sorted order)
            final papersByExam = <String, List<QuestionPaperEntity>>{};
            for (final paper in sortedPapers) {
              final examName = paper.examName ?? 'Unknown Exam';
              papersByExam.putIfAbsent(examName, () => []).add(paper);
            }

            // Add papers grouped by exam with subsection headers (in chronological order)
            for (final examName in papersByExam.keys) {
              listItems.add(_ExamSubsectionHeader(examName: examName));
              for (final paper in papersByExam[examName]!) {
                listItems.add(_AutoAssignedPaperItem(paper: paper));
              }
            }
          }

          // Add manual section header if there are any papers
          if (manualPapers.isNotEmpty || autoAssignedPapers.isNotEmpty) {
            listItems.add(_ManualSectionHeader());
          }

          if (manualPapers.isEmpty && autoAssignedPapers.isNotEmpty) {
            listItems.add(_EmptyManualState());
          } else {
            // Add manual papers
            for (final paper in manualPapers) {
              listItems.add(_ManualPaperItem(paper: paper));
            }
          }
        } else {
          // For admin, just show all papers
          for (final paper in papers) {
            listItems.add(_ManualPaperItem(paper: paper));
          }

          if (papers.isEmpty) {
            listItems.add(_EmptyAdminState());
          }
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= listItems.length) {
                return const SizedBox.shrink();
              }

              final item = listItems[index];
              if (item is _AssignedSectionHeader) {
                return _buildAssignedExamsHeader();
              } else if (item is _ExamSubsectionHeader) {
                return _buildExamSubsectionHeader(item.examName);
              } else if (item is _ManualSectionHeader) {
                return _buildMyPapersHeader();
              } else if (item is _AutoAssignedPaperItem) {
                return _buildAutoAssignedPaperCard(item.paper);
              } else if (item is _ManualPaperItem) {
                return _buildPaperCard(item.paper);
              } else if (item is _EmptyAssignedState) {
                return _buildEmptyAssignedState();
              } else if (item is _EmptyManualState) {
                return _buildEmptyManualState();
              } else if (item is _EmptyAdminState) {
                return _buildEmptyAdminState();
              }
              return const SizedBox.shrink();
            },
            childCount: listItems.length,
          ),
        );
      },
    );
  }

  Widget _buildExamSubsectionHeader(String examName) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
      child: Text(
        examName,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildAssignedExamsHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Text(
        'Assigned Exams (Upcoming)',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildMyPapersHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(
        'My Papers',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildEmptyAssignedState() {
    return SizedBox(
      height: 200,
      child: EmptyMessageWidget(
        icon: Icons.assignment_outlined,
        title: 'No assigned exams yet',
        message: 'Exams will appear here when your school publishes the timetable',
      ),
    );
  }

  Widget _buildEmptyManualState() {
    return SizedBox(
      height: 200,
      child: EmptyMessageWidget(
        icon: Icons.description_outlined,
        title: 'No papers created yet',
        message: 'Create your first question paper to get started',
      ),
    );
  }

  Widget _buildEmptyAdminState() {
    return SizedBox(
      height: 200,
      child: EmptyMessageWidget(
        icon: Icons.description_outlined,
        title: 'No papers to review',
        message: 'Papers submitted by teachers will appear here',
      ),
    );
  }

  Widget _buildAutoAssignedPaperCard(QuestionPaperEntity paper) {
    // Format the subtitle: "Grade 5 | English | Section A | 23 Dec 2025"
    final gradeText = paper.grade ?? 'Unknown Grade';
    final subjectText = paper.subject ?? 'Unknown Subject';
    final sectionText = paper.section ?? 'All Sections';

    // Use exam timetable date if available, otherwise fall back to paper exam date
    final dateText = paper.examTimetableDate != null
        ? '${paper.examTimetableDate!.day} ${_getMonthName(paper.examTimetableDate!.month)} ${paper.examTimetableDate!.year}'
        : (paper.examDate != null
            ? '${paper.examDate!.day} ${_getMonthName(paper.examDate!.month)} ${paper.examDate!.year}'
            : 'No date');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        border: Border.all(color: AppColors.primary20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black04,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Draft papers open CREATE page to add questions
            // Non-draft papers open VIEW page (read-only)
            if (paper.status == PaperStatus.draft) {
              final route = AppRoutes.questionPaperCreateWithDraftId(paper.id);
              print('[DEBUG] Auto-assigned draft paper tapped - Route: $route');
              context.push(route);
            } else {
              final route = AppRoutes.questionPaperViewWithId(paper.id);
              print('[DEBUG] Auto-assigned non-draft paper tapped - Route: $route');
              context.push(route);
            }
          },
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
          child: Padding(
            padding: const EdgeInsets.all(UIConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Grade | Subject | Section | Date (no exam name here, shown in section header)
                          Text(
                            '$gradeText | $subjectText | $sectionText | $dateText',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: UIConstants.spacing12),
                    PaperStatusBadge(status: paper.status, isCompact: true),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaperCard(QuestionPaperEntity paper) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: AppColors.black04,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Open create page for draft papers, view page for others
            // Draft papers are incomplete and need questions to be added
            print('[DEBUG] Paper Card Tap - Paper ID: ${paper.id}');
            print('[DEBUG] Paper Status: ${paper.status}');
            print('[DEBUG] Total Questions: ${paper.totalQuestions}');
            print('[DEBUG] Is Draft: ${paper.status == PaperStatus.draft}');
            print('[DEBUG] Has Zero Questions: ${(paper.totalQuestions ?? 0) == 0}');

            if (paper.status == PaperStatus.draft || (paper.totalQuestions ?? 0) == 0) {
              final route = AppRoutes.questionPaperCreateWithDraftId(paper.id);
              print('[DEBUG] Opening DRAFT route: $route');
              context.push(route);
            } else {
              final route = AppRoutes.questionPaperViewWithId(paper.id);
              print('[DEBUG] Opening VIEW route: $route');
              context.push(route);
            }
          },
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
          child: Padding(
            padding: const EdgeInsets.all(UIConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        paper.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    PaperStatusBadge(status: paper.status, isCompact: true),
                  ],
                ),
                SizedBox(height: UIConstants.spacing12),
                Row(
                  children: [
                    Icon(Icons.subject_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      paper.subject ?? 'Unknown Subject',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.quiz_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      '${paper.totalQuestions} questions',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: UIConstants.spacing8),
                Row(
                  children: [
                    Text(
                      DateFormatterHelper.formatRelative(paper.modifiedAt),
                      style: TextStyle(
                        fontSize: UIConstants.fontSizeSmall,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    _buildActionButton(paper),
                  ],
                ),
                if (paper.rejectionReason != null) ...[
                  SizedBox(height: UIConstants.spacing12),
                  _buildRejectionReason(paper.rejectionReason!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(QuestionPaperEntity paper) {
    // For draft papers, show Edit button
    print('[DEBUG] _buildActionButton called - Paper ID: ${paper.id}, Status: ${paper.status}');
    if (paper.status == PaperStatus.draft) {
      print('[DEBUG] Draft paper detected, showing Edit button');
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              final route = AppRoutes.questionPaperCreateWithDraftId(paper.id);
              print('[DEBUG] Edit button tapped - Route: $route');
              context.push(route);
            },
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary10,
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeSmall,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final (text, icon, color) = switch (paper.status) {
      PaperStatus.rejected => ('View Details', Icons.visibility_rounded, AppColors.accent),
      PaperStatus.approved => ('View', Icons.visibility_rounded, AppColors.success),
      _ => ('View Status', Icons.info_outline_rounded, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color == AppColors.success ? AppColors.success10 : color == AppColors.accent ? AppColors.primary10 : AppColors.primary10,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: UIConstants.fontSizeSmall,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionReason(String reason) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error05,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.error20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Feedback',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.error80,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return FloatingActionButton.extended(
      onPressed: () => context.go(AppRoutes.questionPaperCreate),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Create'),
      elevation: 4,
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  List<QuestionPaperEntity> _getAllPapers(HomeLoaded state, bool isAdmin) {
    if (isAdmin) {
      return [...state.papersForReview, ...state.allPapersForAdmin];
    }

    // Papers are already sorted in the BLoC - just combine them
    return [...state.drafts, ...state.submissions];
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    if (!mounted) return;

    try {
      setState(() => _isRefreshing = true);

      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated) {
        final isAdmin = authState.user.role == UserRole.admin;
        context.read<HomeBloc>().add(RefreshHomePapers(
          isAdmin: isAdmin,
          userId: isAdmin ? null : authState.user.id,
        ));
      }
      await Future.delayed(const Duration(milliseconds: 800));
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }


  Widget _buildNotificationBell() {
    return BlocBuilder<NotificationBloc, NotificationState>(
      builder: (context, state) {
        final int unreadCount = state is NotificationLoaded
            ? state.unreadCount
            : 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: () => context.push(AppRoutes.notifications),
              icon: Icon(
                Icons.notifications_rounded,
                color: AppColors.textPrimary,
                size: 26,
              ),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// Helper classes for list item types
abstract class _PaperListItem {}

class _AssignedSectionHeader extends _PaperListItem {}

class _ExamSubsectionHeader extends _PaperListItem {
  final String examName;
  _ExamSubsectionHeader({required this.examName});
}

class _ManualSectionHeader extends _PaperListItem {}

class _AutoAssignedPaperItem extends _PaperListItem {
  final QuestionPaperEntity paper;
  _AutoAssignedPaperItem({required this.paper});
}

class _ManualPaperItem extends _PaperListItem {
  final QuestionPaperEntity paper;
  _ManualPaperItem({required this.paper});
}

class _EmptyAssignedState extends _PaperListItem {}

class _EmptyManualState extends _PaperListItem {}

class _EmptyAdminState extends _PaperListItem {}