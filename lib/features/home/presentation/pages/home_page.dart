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
import '../../../../core/presentation/widgets/skeleton_loader.dart';
import '../../../../core/presentation/widgets/connectivity_indicator.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../../../paper_workflow/domain/entities/paper_status.dart';
import '../../../paper_workflow/domain/entities/question_paper_entity.dart';
import '../../../paper_workflow/presentation/bloc/question_paper_bloc.dart';
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
    // Load data only once when page is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasLoadedInitialData) {
        _loadInitialData();
        _hasLoadedInitialData = true;
        _startNotificationRefresh();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _isAppInForeground = state == AppLifecycleState.resumed;
  }

  void _startNotificationRefresh() {
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
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Auto-reload if coming from another page with stale data
    final currentState = context.read<HomeBloc>().state;
    if (currentState is! HomeLoaded && currentState is! HomeLoading) {
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

    // Load notifications for teachers
    if (!isAdmin) {
      context.read<NotificationBloc>().add(LoadUnreadCount(authState.user.id));
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
          floatingActionButton: !isAdmin ? _buildCreateButton() : null,
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
              AppColors.primary.withValues(alpha: 0.08),
              AppColors.secondary.withValues(alpha: 0.08),
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
                        color: AppColors.primary.withValues(alpha: 0.3),
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
          // Show loading for both Initial and Loading states
          if (state is HomeInitial || state is HomeLoading) {
            // If we have cached data, show it during loading
            if (_cachedHomeState != null) {
              final papers = _getAllPapers(_cachedHomeState!, isAdmin);
              return _buildPapersList(papers, isAdmin);
            }
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
              return _buildPapersList(papers, isAdmin);
            }
            return _buildError(errorMessage);
          }

          if (state is HomeLoaded) {
            // Cache this state for future use
            _cachedHomeState = state;
            final papers = _getAllPapers(state, isAdmin);
            return _buildPapersList(papers, isAdmin);
          }

          // Fallback: show cached data or empty state
          if (_cachedHomeState != null) {
            final papers = _getAllPapers(_cachedHomeState!, isAdmin);
            return _buildPapersList(papers, isAdmin);
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
    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: PaperListSkeleton(itemCount: 5),
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

  Widget _buildPapersList(List<QuestionPaperEntity> papers, bool isAdmin) {
    if (papers.isEmpty) {
      return _buildEmpty(isAdmin);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    isAdmin ? 'Papers for Review' : 'Your Question Papers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _buildPaperCard(papers[index]),
              ],
            );
          }
          return _buildPaperCard(papers[index]);
        },
        childCount: papers.length,
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
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(AppRoutes.questionPaperViewWithId(paper.id)),
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
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
                      onSelected: (value) {
                        if (value == 'duplicate') {
                          _duplicatePaper(paper);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Row(
                            children: [
                              Icon(Icons.content_copy_rounded, size: 18, color: AppColors.textPrimary),
                              const SizedBox(width: 12),
                              const Text('Duplicate'),
                            ],
                          ),
                        ),
                      ],
                    ),
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
    if (paper.status == PaperStatus.draft) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => context.push(AppRoutes.questionPaperEditWithId(paper.id)),
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
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
        color: color.withValues(alpha: 0.1),
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
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
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
                    color: AppColors.error.withValues(alpha: 0.8),
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

  List<QuestionPaperEntity> _getAllPapers(HomeLoaded state, bool isAdmin) {
    if (isAdmin) {
      return [...state.papersForReview, ...state.allPapersForAdmin];
    }

    final allPapers = [...state.drafts, ...state.submissions];
    allPapers.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return allPapers;
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    if (!mounted) return;
    setState(() => _isRefreshing = true);

    try {
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

  Future<void> _duplicatePaper(QuestionPaperEntity paper) async {
    final TextEditingController titleController = TextEditingController(
      text: '${paper.title} (Copy)',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Question Paper'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a title for the new paper:'),
            const SizedBox(height: 12),
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                ),
                filled: true,
                fillColor: AppColors.backgroundSecondary,
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.content_copy_rounded, size: 18),
            label: const Text('Duplicate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final newTitle = titleController.text.trim();
      if (newTitle.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Title cannot be empty'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Create duplicate with new title
      final duplicatedPaper = paper.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: newTitle,
        status: PaperStatus.draft,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        submittedAt: null,
        reviewedAt: null,
        rejectionReason: null,
      );

      // Add to bloc
      context.read<QuestionPaperBloc>().add(SaveDraft(duplicatedPaper));

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Paper duplicated successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'EDIT',
            textColor: Colors.white,
            onPressed: () {
              context.push(AppRoutes.questionPaperEditWithId(duplicatedPaper.id));
            },
          ),
        ),
      );
    }

    titleController.dispose();
  }

  Widget _buildNotificationBell() {
    return BlocBuilder<NotificationBloc, NotificationState>(
      builder: (context, state) {
        int unreadCount = 0;

        if (state is NotificationLoaded) {
          unreadCount = state.unreadCount;
        }

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