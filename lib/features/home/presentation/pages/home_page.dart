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
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../../../question_papers/domain/entities/question_paper_entity.dart';
import '../../../question_papers/domain/entities/paper_status.dart';
import '../../../question_papers/presentation/bloc/question_paper_bloc.dart';
import '../../../question_papers/presentation/bloc/shared_bloc_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with TickerProviderStateMixin, PerformanceOptimizationMixin, AutomaticKeepAliveClientMixin {

  // State variables
  String _selectedFilter = 'all';
  bool _isRefreshing = false;

  // Animation controllers
  late AnimationController _statsAnimationController;
  late AnimationController _refreshAnimationController;
  late Animation<double> _statsAnimation;
  late Animation<double> _refreshAnimation;

  // Performance optimization
  late ComputationCache<Map<String, int>> _statsCache;
  late ComputationCache<List<QuestionPaperEntity>> _filterCache;

  // User state subscription
  StreamSubscription<void>? _userStateSubscription;
  bool _isAdmin = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeCaches();
    _subscribeToUserStateChanges();
    _loadInitialData();
  }

  @override
  void dispose() {
    _statsAnimationController.dispose();
    _refreshAnimationController.dispose();
    _userStateSubscription?.cancel();
    _statsCache.invalidateAll();
    _filterCache.invalidateAll();
    super.dispose();
  }

  void _initializeAnimations() {
    _statsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _refreshAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _statsAnimation = CurvedAnimation(
      parent: _statsAnimationController,
      curve: Curves.easeOutCubic,
    );
    _refreshAnimation = CurvedAnimation(
      parent: _refreshAnimationController,
      curve: Curves.easeInOut,
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _statsAnimationController.forward();
    });
  }

  void _initializeCaches() {
    _statsCache = ComputationCache<Map<String, int>>();
    _filterCache = ComputationCache<List<QuestionPaperEntity>>();
  }

  void _subscribeToUserStateChanges() {
    final userStateService = sl<UserStateService>();
    _isAdmin = userStateService.isAdmin;

    _userStateSubscription = userStateService.addListener(() {
      if (mounted && _isAdmin != userStateService.isAdmin) {
        setState(() {
          _isAdmin = userStateService.isAdmin;
        });
        _loadInitialData();
      }
    }) as StreamSubscription<void>?;
  }

  void _loadInitialData() {
    final bloc = context.read<QuestionPaperBloc>();
    bloc.add(const LoadDrafts());
    bloc.add(const LoadUserSubmissions());
    if (_isAdmin) {
      bloc.add(const LoadPapersForReview());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, authState) {
        if (authState is AuthAuthenticated) {
          final newAdminStatus = authState.user.role == UserRole.admin ||
              authState.user.role == UserRole.teacher;
          if (_isAdmin != newAdminStatus) {
            setState(() => _isAdmin = newAdminStatus);
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
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 768;

              return RefreshIndicator(
                onRefresh: _handleRefresh,
                backgroundColor: AppColors.surface,
                color: AppColors.primary,
                displacement: 80,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildWelcomeHeader(context, user, isMobile),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        isMobile ? 16 : 24,
                        0,
                        isMobile ? 16 : 24,
                        isMobile ? 16 : 24,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildStatsCards(context, isMobile),
                          const SizedBox(height: 24),
                          _buildFilterSection(isMobile),
                          const SizedBox(height: 16),
                          _buildContent(context, isMobile),
                          const SizedBox(height: 80), // Space for FAB
                        ]),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: !_isAdmin ? _buildCreateFAB(context) : null,
        );
      },
    );
  }

  Widget _buildWelcomeHeader(BuildContext context, dynamic user, bool isMobile) {
    return SliverToBoxAdapter(
      child: Container(
        margin: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24,
          isMobile ? 16 : 24,
          isMobile ? 16 : 24,
          16,
        ),
        padding: EdgeInsets.all(isMobile ? 20 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.05),
              AppColors.secondary.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Welcome back,',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),

              ],
            ),
            const SizedBox(height: 4),
            Text(
              user.fullName,
              style: TextStyle(
                fontSize: isMobile ? 24 : 28,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(BuildContext context, bool isMobile) {
    return BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
      builder: (context, state) {
        if (state is QuestionPaperLoaded) {
          return AnimatedBuilder(
            animation: _statsAnimation,
            child: _buildStatsCardsContent(state, isMobile),
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - _statsAnimation.value)),
                child: Opacity(
                  opacity: _statsAnimation.value,
                  child: child,
                ),
              );
            },
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildStatsCardsContent(QuestionPaperLoaded state, bool isMobile) {
    final stats = _statsCache.getOrCompute('main_stats', () => _calculateStats(state));
    final cardHeight = isMobile ? 80.0 : 96.0;

    return SizedBox(
      height: cardHeight,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildStatCard(
            'Total Papers',
            stats['total'].toString(),
            Icons.description_outlined,
            AppColors.primary,
            isMobile,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Drafts',
            stats['drafts'].toString(),
            Icons.edit_outlined,
            AppColors.warning,
            isMobile,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Approved',
            stats['approved'].toString(),
            Icons.check_circle_outline,
            AppColors.success,
            isMobile,
          ),
          if (_isAdmin) ...[
            const SizedBox(width: 12),
            _buildStatCard(
              'Pending Review',
              stats['pending'].toString(),
              Icons.pending_outlined,
              AppColors.accent,
              isMobile,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      width: isMobile ? 120 : 140,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: isMobile ? 20 : 24),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(bool isMobile) {
    final filters = _isAdmin
        ? ['all', 'submitted', 'approved', 'rejected']
        : ['all', 'drafts', 'submitted', 'approved', 'rejected'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter Papers',
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = filters[index];
              final isSelected = _selectedFilter == filter;

              return GestureDetector(
                onTap: () {
                  if (!isSelected) {
                    setState(() => _selectedFilter = filter);
                    _filterCache.invalidateAll(); // Clear filter cache
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 14 : 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.primaryGradient : null,
                    color: isSelected ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: isSelected ? null : Border.all(
                      color: AppColors.border,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Text(
                    _getFilterLabel(filter),
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool isMobile) {
    return BlocBuilder<QuestionPaperBloc, QuestionPaperState>(
      builder: (context, state) {
        if (state is QuestionPaperLoading) {
          return _buildLoadingState(isMobile);
        }

        if (state is QuestionPaperError) {
          return _buildErrorState(state.message, isMobile);
        }

        if (state is QuestionPaperLoaded) {
          final cacheKey = '${_selectedFilter}_${state.hashCode}';
          final papers = _filterCache.getOrCompute(cacheKey, () => _getFilteredPapers(state));
          return _buildPapersList(papers, isMobile);
        }

        return _buildEmptyState(isMobile);
      },
    );
  }

  Widget _buildLoadingState(bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 24 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading your papers...',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPapersList(List<QuestionPaperEntity> papers, bool isMobile) {
    if (papers.isEmpty) {
      return _buildEmptyState(isMobile);
    }

    return Column(
      children: papers.map((paper) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildPaperCard(paper, isMobile),
      )).toList(),
    );
  }

  Widget _buildPaperCard(QuestionPaperEntity paper, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
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
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        paper.title,
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _buildStatusChip(paper.status, isMobile),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPaperInfo(paper, isMobile),
                if (paper.rejectionReason != null) ...[
                  const SizedBox(height: 12),
                  _buildRejectionReason(paper.rejectionReason!, isMobile),
                ],
                if (_isAdmin && paper.status.isSubmitted) ...[
                  const SizedBox(height: 16),
                  _buildAdminActions(paper.id, isMobile),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaperInfo(QuestionPaperEntity paper, bool isMobile) {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.subject_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                paper.subject,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            Icon(Icons.quiz_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                paper.examType,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 15,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.help_outline_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              '${paper.totalQuestions} questions',
              style: TextStyle(
                fontSize: isMobile ? 14 : 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 16),
            Icon(Icons.access_time_rounded, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              paper.examTypeEntity.formattedDuration,
              style: TextStyle(
                fontSize: isMobile ? 14 : 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              _formatDate(paper.modifiedAt),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(PaperStatus status, bool isMobile) {
    Color color;
    switch (status) {
      case PaperStatus.draft:
        color = AppColors.warning;
        break;
      case PaperStatus.submitted:
        color = AppColors.primary;
        break;
      case PaperStatus.approved:
        color = AppColors.success;
        break;
      case PaperStatus.rejected:
        color = AppColors.error;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 10 : 12,
        vertical: isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.displayName.toUpperCase(),
        style: TextStyle(
          fontSize: isMobile ? 10 : 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildRejectionReason(String reason, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rejection Reason',
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
                    fontSize: isMobile ? 13 : 14,
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

  Widget _buildAdminActions(String paperId, bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _approvePaper(paperId),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _rejectPaper(paperId),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Reject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(String message, bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 24 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isMobile ? 64 : 80,
              height: isMobile ? 64 : 80,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: isMobile ? 32 : 40,
                color: AppColors.error,
              ),
            ),
            SizedBox(height: isMobile ? 16 : 20),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 24 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isMobile ? 80 : 100,
              height: isMobile ? 80 : 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.secondary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(isMobile ? 20 : 25),
              ),
              child: Icon(
                Icons.description_outlined,
                size: isMobile ? 40 : 50,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: isMobile ? 20 : 24),
            Text(
              _getEmptyStateTitle(),
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _getEmptyStateSubtitle(),
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (!_isAdmin) ...[
              SizedBox(height: isMobile ? 24 : 32),
              ElevatedButton.icon(
                onPressed: () => context.go(AppRoutes.questionPaperCreate),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Question Paper'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 24,
                    vertical: isMobile ? 14 : 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreateFAB(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => context.go(AppRoutes.questionPaperCreate),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Create'),
      elevation: 4,
      extendedPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  // Event handlers
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);
    _refreshAnimationController.repeat();

    // Clear caches
    _statsCache.invalidateAll();
    _filterCache.invalidateAll();

    // Debounced refresh to prevent multiple rapid calls
    debounce('refresh_${hashCode}', () {
      final bloc = context.read<QuestionPaperBloc>();
      bloc.add(const RefreshAll());
    });

    // Simulate minimum refresh time for better UX
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() => _isRefreshing = false);
      _refreshAnimationController.stop();
      _refreshAnimationController.reset();
    }
  }

  void _navigateToPaper(QuestionPaperEntity paper) {
    try {
      // Always go to detail page first, regardless of status
      context.go(AppRoutes.questionPaperViewWithId(paper.id));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open paper: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _approvePaper(String paperId) {
    context.read<QuestionPaperBloc>().add(ApprovePaper(paperId));
    _statsCache.invalidateAll();
    _filterCache.invalidateAll();
  }

  Future<void> _rejectPaper(String paperId) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectPaperDialog(),
    );

    if (reason != null && reason.isNotEmpty) {
      context.read<QuestionPaperBloc>().add(RejectPaper(paperId, reason));
      _statsCache.invalidateAll();
      _filterCache.invalidateAll();
    }
  }

  // Helper methods
  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.teacher:
        return 'TEACHER';
      default:
        return 'USER';
    }
  }

  Map<String, int> _calculateStats(QuestionPaperLoaded state) {
    final total = state.drafts.length + state.submissions.length;
    final approved = state.submissions.where((p) => p.status.isApproved).length;
    final pending = _isAdmin ? state.papersForReview.length : 0;

    return {
      'total': total,
      'drafts': state.drafts.length,
      'approved': approved,
      'pending': pending,
    };
  }

  List<QuestionPaperEntity> _getFilteredPapers(QuestionPaperLoaded state) {
    if (_isAdmin) {
      switch (_selectedFilter) {
        case 'submitted':
          return state.papersForReview;
        case 'approved':
          return [...state.submissions, ...state.papersForReview]
              .where((p) => p.status.isApproved).toList();
        case 'rejected':
          return [...state.submissions, ...state.papersForReview]
              .where((p) => p.status.isRejected).toList();
        default:
          return [...state.submissions, ...state.papersForReview];
      }
    } else {
      switch (_selectedFilter) {
        case 'drafts':
          return state.drafts;
        case 'submitted':
          return state.submissions.where((p) => p.status.isSubmitted).toList();
        case 'approved':
          return state.submissions.where((p) => p.status.isApproved).toList();
        case 'rejected':
          return state.submissions.where((p) => p.status.isRejected).toList();
        default:
          return [...state.drafts, ...state.submissions];
      }
    }
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'all': return 'All';
      case 'drafts': return 'Drafts';
      case 'submitted': return 'Submitted';
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      default: return filter.toUpperCase();
    }
  }

  String _getEmptyStateTitle() {
    if (_isAdmin) {
      return _selectedFilter == 'submitted'
          ? 'No papers to review'
          : 'No papers found';
    } else {
      return _selectedFilter == 'drafts'
          ? 'No drafts yet'
          : 'No papers found';
    }
  }

  String _getEmptyStateSubtitle() {
    if (_isAdmin) {
      return 'All submitted papers have been reviewed';
    } else {
      return _selectedFilter == 'drafts'
          ? 'Create your first question paper to get started'
          : 'You haven\'t created any question papers yet';
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
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _RejectPaperDialog extends StatefulWidget {
  @override
  _RejectPaperDialogState createState() => _RejectPaperDialogState();
}

class _RejectPaperDialogState extends State<_RejectPaperDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Reject Question Paper',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for rejection:',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'Enter feedback for the teacher',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
              maxLines: 3,
              autofocus: true,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide a rejection reason';
                }
                if (value.trim().length < 10) {
                  return 'Please provide a more detailed reason (min 10 characters)';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}