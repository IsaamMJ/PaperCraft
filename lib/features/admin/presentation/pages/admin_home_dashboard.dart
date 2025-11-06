import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../catalog/domain/repositories/grade_repository.dart';
import '../../../catalog/domain/repositories/subject_repository.dart';
import '../../../paper_workflow/presentation/bloc/user_management_bloc.dart';

/// Admin home dashboard showing setup progress and quick actions
class AdminHomeDashboard extends StatefulWidget {
  const AdminHomeDashboard({super.key});

  @override
  State<AdminHomeDashboard> createState() => _AdminHomeDashboardState();
}

class _AdminHomeDashboardState extends State<AdminHomeDashboard> {
  late final UserStateService _userStateService;

  int? _subjectCount;
  int? _gradeCount;
  int? _examTypeCount;
  int? _teacherCount;
  int? _assignedTeacherCount;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _userStateService = sl<UserStateService>();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        sl<SubjectRepository>().getSubjects(),
        sl<GradeRepository>().getGrades(),
      ]);

      if (mounted) {
        setState(() {
          _subjectCount = results[0].fold((_) => 0, (list) => list.length);
          _gradeCount = results[1].fold((_) => 0, (list) => list.length);
          _examTypeCount = 0; // Exam types removed - using dynamic sections
          _isLoading = false;
        });

        // Load teacher count
        context.read<UserManagementBloc>().add(const LoadUsers());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _calculateProgress() {
    int total = 0;
    int completed = 0;

    // Check subjects (25 points)
    total += 25;
    if (_subjectCount != null && _subjectCount! > 0) completed += 25;

    // Check grades (25 points)
    total += 25;
    if (_gradeCount != null && _gradeCount! > 0) completed += 25;

    // Check exam types (25 points)
    total += 25;
    if (_examTypeCount != null && _examTypeCount! > 0) completed += 25;

    // Check teachers (25 points)
    total += 25;
    if (_teacherCount != null && _teacherCount! > 0) completed += 25;

    return total > 0 ? ((completed / total) * 100).round() : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _userStateService.currentTenantName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(UIConstants.paddingMedium),
          child: BlocListener<UserManagementBloc, UserManagementState>(
            listener: (context, state) {
              if (state is UserManagementLoaded) {
                final teachers = state.users.where((u) => u.isTeacher).toList();
                setState(() {
                  _teacherCount = teachers.length;
                  // TODO: Calculate assigned teachers from assignments
                  _assignedTeacherCount = teachers.length; // Placeholder
                });
              }
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSetupProgress(),
                SizedBox(height: UIConstants.spacing24),
                _buildStatsGrid(),
                SizedBox(height: UIConstants.spacing24),
                _buildQuickActions(),
                SizedBox(height: UIConstants.spacing24),
                _buildRecentActivity(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupProgress() {
    final progress = _calculateProgress();
    final isComplete = progress >= 100;

    return Container(
      padding: EdgeInsets.all(UIConstants.paddingLarge),
      decoration: BoxDecoration(
        gradient: isComplete
            ? AppColors.primaryGradient
            : LinearGradient(
                colors: [
                  AppColors.primary10,
                  AppColors.secondary10,
                ],
              ),
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        border: Border.all(
          color: isComplete
              ? Colors.transparent
              : AppColors.primary30,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle : Icons.school,
                color: isComplete ? Colors.white : AppColors.primary,
                size: UIConstants.iconLarge,
              ),
              SizedBox(width: UIConstants.spacing12),
              Expanded(
                child: Text(
                  isComplete ? 'School Setup Complete!' : 'School Setup Progress',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeXXLarge,
                    fontWeight: FontWeight.w700,
                    color: isComplete ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$progress%',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeXXLarge,
                  fontWeight: FontWeight.w700,
                  color: isComplete ? Colors.white : AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: UIConstants.spacing16),
          ClipRRect(
            borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: isComplete
                  ? AppColors.white30
                  : AppColors.border,
              valueColor: AlwaysStoppedAnimation(
                isComplete ? Colors.white : AppColors.primary,
              ),
              minHeight: 8,
            ),
          ),
          if (!isComplete) ...[
            SizedBox(height: UIConstants.spacing12),
            Text(
              'Complete the setup to start creating question papers',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: UIConstants.fontSizeMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configuration Status',
          style: TextStyle(
            fontSize: UIConstants.fontSizeXLarge,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing16),
        GridView.count(
          shrinkWrap: false,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: UIConstants.spacing12,
          crossAxisSpacing: UIConstants.spacing12,
          childAspectRatio: 1.5,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          cacheExtent: 100,
          children: [
            _buildStatCard(
              title: 'Subjects',
              count: _subjectCount,
              icon: Icons.subject_outlined,
              route: AppRoutes.settingsSubjects,
              isConfigured: _subjectCount != null && _subjectCount! > 0,
            ),
            _buildStatCard(
              title: 'Grades',
              count: _gradeCount,
              icon: Icons.school_outlined,
              route: AppRoutes.settingsGrades,
              isConfigured: _gradeCount != null && _gradeCount! > 0,
            ),
            _buildStatCard(
              title: 'Teachers',
              count: _teacherCount,
              icon: Icons.people_outline,
              route: AppRoutes.teacherAssignments,
              isConfigured: _teacherCount != null && _teacherCount! > 0,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required int? count,
    required IconData icon,
    required String route,
    required bool isConfigured,
  }) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      child: Container(
        padding: EdgeInsets.all(UIConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          border: Border.all(
            color: isConfigured
                ? AppColors.success10
                : AppColors.border,
            width: isConfigured ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: isConfigured ? AppColors.success : AppColors.textSecondary,
                  size: UIConstants.iconLarge,
                ),
                if (isConfigured)
                  Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: UIConstants.iconMedium,
                  ),
              ],
            ),
            SizedBox(height: UIConstants.spacing8),
            Text(
              count?.toString() ?? '—',
              style: TextStyle(
                fontSize: UIConstants.fontSizeXXLarge,
                fontWeight: FontWeight.w700,
                color: isConfigured ? AppColors.success : AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing4),
            Text(
              title,
              style: TextStyle(
                fontSize: UIConstants.fontSizeMedium,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: UIConstants.fontSizeXLarge,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing16),
        _buildActionCard(
          title: 'Assign Teachers',
          subtitle: 'Configure grades and subjects for teachers',
          icon: Icons.assignment_ind,
          color: AppColors.primary,
          onTap: () => context.push(AppRoutes.teacherAssignments),
        ),
        SizedBox(height: UIConstants.spacing12),
        _buildActionCard(
          title: 'Review Papers',
          subtitle: 'Approve or reject submitted question papers',
          icon: Icons.rate_review,
          color: AppColors.accent,
          onTap: () => context.push(AppRoutes.adminDashboard),
        ),
        SizedBox(height: UIConstants.spacing12),
        _buildActionCard(
          title: 'Assignment Matrix',
          subtitle: 'View all teacher assignments at a glance',
          icon: Icons.grid_on,
          color: AppColors.secondary,
          onTap: () => context.push(AppRoutes.assignmentMatrix),
        ),
        SizedBox(height: UIConstants.spacing12),
        _buildActionCard(
          title: 'Assignments Dashboard',
          subtitle: 'View grade-section-subject assignments',
          icon: Icons.assessment,
          color: Colors.deepPurple,
          onTap: () => context.push(AppRoutes.adminAssignmentsDashboard),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      child: Container(
        padding: EdgeInsets.all(UIConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppColors.black04,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(UIConstants.spacing12),
              decoration: BoxDecoration(
                color: AppColors.primary10,
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
              child: Icon(icon, color: color, size: UIConstants.iconLarge),
            ),
            SizedBox(width: UIConstants.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeLarge,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: UIConstants.spacing4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeMedium,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: UIConstants.fontSizeXLarge,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.adminDashboard),
              child: const Text('View All'),
            ),
          ],
        ),
        SizedBox(height: UIConstants.spacing12),
        Container(
          padding: EdgeInsets.all(UIConstants.paddingLarge),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          ),
          child: Center(
            child: Text(
              'No recent activity',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: UIConstants.fontSizeMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
