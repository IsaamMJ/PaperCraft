// features/home/presentation/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isRefreshing = false;
  bool _hasLoadedInitialData = false;
  Timer? _notificationRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Load data only once when page is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasLoadedInitialData) {
        _loadInitialData();
        _hasLoadedInitialData = true;
        _startNotificationRefresh();
      }
    });
  }

  void _startNotificationRefresh() {
    _notificationRefreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      if (mounted) {
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
    _notificationRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only reload data if we're returning from another page
    // Check if we already loaded initial data to avoid redundant loads
    if (_hasLoadedInitialData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refreshData();
        }
      });
    }
  }

  void _refreshData() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;

    final isAdmin = authState.user.role == UserRole.admin;
    if (!isAdmin) {
      // Only refresh unread count for teachers (lightweight operation)
      context.read<NotificationBloc>().add(LoadUnreadCount(authState.user.id));
    }
  }

  void _loadInitialData() {
    final authState = context.read<AuthBloc>().state;

    if (authState is! AuthAuthenticated) {
      return;
    }

    final bloc = context.read<QuestionPaperBloc>();
    final isAdmin = authState.user.role == UserRole.admin;

    if (isAdmin) {
      bloc.add(const LoadPapersForReview());
    } else {
      bloc.add(const LoadDrafts());
      bloc.add(const LoadUserSubmissions());

      // Load notifications for teachers
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
            if (!isAdmin) ...[
              SizedBox(height: UIConstants.spacing16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.questionPaperCreate),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Create Question Paper'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isAdmin) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
        builder: (context, state) {
          if (state is QuestionPaperLoading) {
            return _buildLoading();
          }

          if (state is QuestionPaperError) {
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
            return _buildError(errorMessage);
          }

          if (state is QuestionPaperLoaded) {
            final papers = _getAllPapers(state, isAdmin);
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
                      _formatDate(paper.modifiedAt),
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
    final (text, icon, color) = switch (paper.status) {
      PaperStatus.draft => ('View Draft', Icons.visibility_rounded, AppColors.primary),
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

  List<QuestionPaperEntity> _getAllPapers(QuestionPaperLoaded state, bool isAdmin) {
    if (isAdmin) {
      return state.papersForReview;
    }

    final allPapers = [...state.drafts, ...state.submissions];
    allPapers.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return allPapers;
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      _loadInitialData();
      await Future.delayed(const Duration(milliseconds: 800));
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final compareDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(compareDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
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