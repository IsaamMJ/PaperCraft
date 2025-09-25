import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../../../question_papers/domain/entities/question_paper_entity.dart';
import '../../../question_papers/domain/entities/paper_status.dart';
import '../../../question_papers/presentation/bloc/question_paper_bloc.dart';
import '../../../question_papers/presentation/widgets/shared/paper_status_badge.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  bool _isRefreshing = false;
  late UserStateService _userStateService;
  bool _isAdmin = false;
  bool _hasLoadedInitialData = false;
  Timer? _debounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _userStateService = sl<UserStateService>();
    _subscribeToUserStateChanges();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load data only once initially
    if (!_hasLoadedInitialData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadInitialData();
          _hasLoadedInitialData = true;
        }
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _userStateService.removeListener(_handleUserStateChange);
    super.dispose();
  }

  void _subscribeToUserStateChanges() {
    _isAdmin = _userStateService.isAdmin;
    _userStateService.addListener(_handleUserStateChange);
  }

  void _handleUserStateChange() {
    if (mounted && _isAdmin != _userStateService.isAdmin) {
      setState(() => _isAdmin = _userStateService.isAdmin);
      _debounceDataLoad();
    }
  }

  void _debounceDataLoad() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _loadInitialData();
      }
    });
  }

  void _loadInitialData() {
    try {
      // Ensure we have a valid authentication state
      final authState = context.read<AuthBloc>().state;

      if (authState is! AuthAuthenticated) {
        debugPrint('Cannot load data: User not authenticated');
        return;
      }

      // Double-check admin status from auth state
      final isCurrentlyAdmin = authState.user.role == UserRole.admin;

      final bloc = context.read<QuestionPaperBloc>();

      // Load data based on current role, not cached _isAdmin
      if (isCurrentlyAdmin) {
        bloc.add(const LoadPapersForReview());
      } else {
        bloc.add(const LoadDrafts());
        bloc.add(const LoadUserSubmissions());
      }

      // Update cached admin status
      if (_isAdmin != isCurrentlyAdmin) {
        setState(() => _isAdmin = isCurrentlyAdmin);
      }

    } catch (e) {
      debugPrint('Error loading initial data: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load data. Please try again.');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is AuthAuthenticated) {
          // Only admin role should be considered admin, not teachers
          final newAdminStatus = authState.user.role == UserRole.admin;
          if (_isAdmin != newAdminStatus) {
            setState(() => _isAdmin = newAdminStatus);
            _debounceDataLoad();
          }
        }
      },
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final user = authState.user;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: _handleRefresh,
            backgroundColor: AppColors.surface,
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildHeader(user),
                _buildContent(),
              ],
            ),
          ),
          floatingActionButton: !_isAdmin ? _buildCreateButton() : null,
        );
      },
    );
  }

  Widget _buildHeader(dynamic user) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.08),
              AppColors.secondary.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
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
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
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
            if (!_isAdmin) ...[
              const SizedBox(height: 16),
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
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildContent() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
        builder: (context, state) {
          try {
            if (state is QuestionPaperLoading) {
              return _buildLoading();
            }

            if (state is QuestionPaperError) {
              // Add more specific error handling
              String errorMessage = state.message;
              if (errorMessage.toLowerCase().contains('admin') ||
                  errorMessage.toLowerCase().contains('privilege')) {
                // This is likely an auth/permission issue
                errorMessage = 'Permission issue detected. Please log out and log back in.';

                // Optional: Automatically trigger re-authentication
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _handleAuthenticationError();
                  }
                });
              }
              return _buildError(errorMessage);
            }

            if (state is QuestionPaperLoaded) {
              final papers = _getAllPapers(state);
              return _buildPapersList(papers);
            }

            // Handle initial state
            if (state is QuestionPaperInitial) {
              // Trigger data loading if not already done
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _hasLoadedInitialData) {
                  _loadInitialData();
                }
              });
              return _buildLoading();
            }

            return _buildEmpty();
          } catch (e) {
            debugPrint('Error building content: $e');
            return _buildError('Failed to load papers: ${e.toString()}');
          }
        },
      ),
    );
  }

  void _handleAuthenticationError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Issue'),
        content: const Text('There seems to be an issue with your authentication. Would you like to log out and log back in?'),
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
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
                'Loading your papers...',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.secondary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.description_outlined,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isAdmin ? 'No papers to review' : 'No papers yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isAdmin
                  ? 'Papers submitted by teachers will appear here'
                  : 'Create your first question paper to get started',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPapersList(List<QuestionPaperEntity> papers) {
    if (papers.isEmpty) {
      return _buildEmpty();
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
                    _isAdmin ? 'Papers for Review' : 'Your Question Papers',
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToPaper(paper),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.subject_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      paper.subject,
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      _formatDate(paper.modifiedAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    _buildActionButton(paper),
                  ],
                ),
                if (paper.rejectionReason != null) ...[
                  const SizedBox(height: 12),
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
    String text;
    IconData icon;
    Color color;

    switch (paper.status) {
      case PaperStatus.draft:
        text = 'View Draft'; // Changed from 'Continue'
        icon = Icons.visibility_rounded; // Changed from edit icon
        color = AppColors.primary;
        break;
      case PaperStatus.rejected:
        text = 'View Details'; // Changed from 'Edit Again'
        icon = Icons.visibility_rounded; // Changed from refresh icon
        color = AppColors.accent;
        break;
      case PaperStatus.approved:
        text = 'View';
        icon = Icons.visibility_rounded;
        color = AppColors.success;
        break;
      default:
        text = 'View Status';
        icon = Icons.info_outline_rounded;
        color = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
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
        color: AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.error.withOpacity(0.8),
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

  // Helper methods
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  List<QuestionPaperEntity> _getAllPapers(QuestionPaperLoaded state) {
    if (_isAdmin) {
      return state.papersForReview;
    } else {
      final allPapers = [...state.drafts, ...state.submissions];
      allPapers.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      return allPapers;
    }
  }

  void _navigateToPaper(QuestionPaperEntity paper) {
    try {
      // Always go to detail view first, regardless of status
      context.go(AppRoutes.questionPaperViewWithId(paper.id));
    } catch (e) {
      debugPrint('Navigation error: $e');
      _showErrorSnackBar('Navigation failed. Please try again.');
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      // Wait for auth state to be ready before refreshing data
      final authState = context.read<AuthBloc>().state;

      if (authState is! AuthAuthenticated) {
        debugPrint('User not authenticated during refresh');
        if (mounted) {
          _showErrorSnackBar('Please log in again to continue.');
        }
        return;
      }

      // Update admin status from current auth state
      final currentAdminStatus = authState.user.role == UserRole.admin;
      if (_isAdmin != currentAdminStatus) {
        setState(() => _isAdmin = currentAdminStatus);
      }

      // Now safely load data based on current user role
      _loadInitialData();

      await Future.delayed(const Duration(milliseconds: 800));
    } catch (e) {
      debugPrint('Refresh error: $e');
      if (mounted) {
        _showErrorSnackBar('Refresh failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}