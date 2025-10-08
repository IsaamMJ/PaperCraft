import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/presentation/utils/date_utils.dart';
import '../../../../core/presentation/widgets/common_state_widgets.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../../../catalog/domain/repositories/exam_type_repository.dart';
import '../../../catalog/domain/repositories/grade_repository.dart';
import '../../../catalog/domain/repositories/subject_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final UserStateService _userStateService;

  // Count state
  int? _subjectCount;
  int? _gradeCount;
  int? _examTypeCount;

  @override
  void initState() {
    super.initState();
    _userStateService = sl<UserStateService>();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    if (!_userStateService.isAdmin) return;

    try {
      final results = await Future.wait([
        sl<SubjectRepository>().getSubjects(),
        sl<GradeRepository>().getGrades(),
        sl<ExamTypeRepository>().getExamTypes(),
      ]);

      if (mounted) {
        setState(() {
          _subjectCount = results[0].fold((_) => 0, (list) => list.length);
          _gradeCount = results[1].fold((_) => 0, (list) => list.length);
          _examTypeCount = results[2].fold((_) => 0, (list) => list.length);
        });
      }
    } catch (e) {
      // Silently fail - counts will remain null
    }
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        title: Row(
          children: [
            Icon(Icons.support_agent, color: AppColors.primary),
            SizedBox(width: UIConstants.spacing12),
            const Text('Help & Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('For support and assistance, please contact:'),
            SizedBox(height: UIConstants.spacing16),
            Container(
              padding: EdgeInsets.all(UIConstants.spacing12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(Icons.email, color: AppColors.primary),
                  SizedBox(width: UIConstants.spacing12),
                  Expanded(
                    child: Text(
                      'isaam.mj@gmail.com',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: UIConstants.fontSizeLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        title: Row(
          children: [
            Icon(Icons.logout, color: AppColors.error),
            SizedBox(width: UIConstants.spacing12),
            const Text('Sign Out'),
          ],
        ),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AuthBloc>().add(const AuthSignOut());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! AuthAuthenticated) {
          return _buildUnauthorizedView();
        }

        final user = authState.user;
        final isAdmin = _userStateService.isAdmin;

        if (!isAdmin) {
          return _buildUnauthorizedView();
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Settings'),
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDashboardLink(),
                SizedBox(height: UIConstants.spacing16),
                _buildProfileSection(user),
                SizedBox(height: UIConstants.spacing24),
                _buildManagementSection(),
                SizedBox(height: UIConstants.spacing24),
                _buildAboutSection(),
                SizedBox(height: UIConstants.spacing24),
                _buildDangerZone(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnauthorizedView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: EmptyMessageWidget(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Admin Access Required',
          message: 'Only administrators can access settings',
        ),
      ),
    );
  }

  Widget _buildProfileSection(dynamic user) {
    return _buildSection(
      title: 'Profile',
      icon: Icons.person_outline,
      children: [
        _buildProfileTile(user),
        SizedBox(height: UIConstants.spacing8),
        _buildInfoTile(
          title: 'Email',
          subtitle: user.email ?? 'No email',
          icon: Icons.email_outlined,
        ),
        _buildInfoTile(
          title: 'Role',
          subtitle: user.role.displayName,
          icon: Icons.admin_panel_settings_outlined,
          trailing: _buildRoleBadge(user.role),
        ),
        _buildInfoTile(
          title: 'Tenant',
          subtitle: _userStateService.currentTenantName,
          icon: Icons.business_outlined,
        ),
        _buildInfoTile(
          title: 'Joined',
          subtitle: AppDateUtils.formatShortDate(user.createdAt),
          icon: Icons.calendar_today_outlined,
        ),
      ],
    );
  }

  Widget _buildManagementSection() {
    return _buildSection(
      title: 'Management',
      icon: Icons.settings_outlined,
      children: [
        _buildNavigationTile(
          title: 'Manage Subjects',
          subtitle: 'Add, edit, or remove subjects',
          icon: Icons.subject_outlined,
          route: AppRoutes.settingsSubjects,
          count: _subjectCount,
        ),
        _buildNavigationTile(
          title: 'Manage Grades',
          subtitle: 'Configure grade levels and sections',
          icon: Icons.school_outlined,
          route: AppRoutes.settingsGrades,
          count: _gradeCount,
        ),
        _buildNavigationTile(
          title: 'Manage Exam Types',
          subtitle: 'Configure exam formats and sections',
          icon: Icons.quiz_outlined,
          route: AppRoutes.settingsExamTypes,
          count: _examTypeCount,
        ),
        _buildNavigationTile(
          title: 'Manage Users',
          subtitle: 'Manage users in your tenant',
          icon: Icons.people_outline,
          route: AppRoutes.settingsUsers,
          count: null,
        ),
        _buildNavigationTile(
          title: 'Teacher Assignments',
          subtitle: 'Assign grades and subjects to teachers',
          icon: Icons.assignment_ind_outlined,
          route: AppRoutes.teacherAssignments,
          count: null,
        ),

      ],
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required String route,
    int? count,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        UIConstants.spacing20,
        0,
        UIConstants.spacing20,
        UIConstants.spacing8,
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            if (count != null) ...[
              SizedBox(width: UIConstants.spacing8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: UIConstants.spacing8,
                  vertical: UIConstants.spacing4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.textTertiary,
        ),
        onTap: () => context.push(route),
        dense: true,
      ),
    );
  }

  Widget _buildAboutSection() {
    return _buildSection(
      title: 'About',
      icon: Icons.info_outline,
      children: [
        _buildActionTile(
          title: 'Help & Support',
          subtitle: 'Get help with using the app',
          icon: Icons.help_outline,
          onTap: _showSupportDialog,
        ),
      ],
    );
  }

  Widget _buildDangerZone() {
    return _buildSection(
      title: 'Danger Zone',
      icon: Icons.warning_outlined,
      titleColor: AppColors.error,
      children: [
        _buildActionTile(
          title: 'Sign Out',
          subtitle: 'Sign out of your account',
          icon: Icons.logout,
          onTap: _showSignOutDialog,
          textColor: AppColors.error,
          iconColor: AppColors.error,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? titleColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(UIConstants.spacing20),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: titleColor ?? AppColors.primary,
                  size: UIConstants.iconMedium,
                ),
                SizedBox(width: UIConstants.spacing12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeXLarge,
                    fontWeight: FontWeight.w600,
                    color: titleColor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileTile(dynamic user) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        UIConstants.spacing20,
        0,
        UIConstants.spacing20,
        UIConstants.spacing16,
      ),
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
            ),
            child: Center(
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: UIConstants.fontSizeXXLarge,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: UIConstants.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: UIConstants.fontSizeXLarge,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: UIConstants.spacing4),
                Text(
                  user.role.displayName,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: UIConstants.fontSizeMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        UIConstants.spacing20,
        0,
        UIConstants.spacing20,
        UIConstants.spacing8,
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.textSecondary),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        trailing: trailing,
        dense: true,
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        UIConstants.spacing20,
        0,
        UIConstants.spacing20,
        UIConstants.spacing8,
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: textColor ?? AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: AppColors.textTertiary,
        ),
        onTap: onTap,
        dense: true,
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    final isAdminRole = role == UserRole.admin;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: UIConstants.spacing8,
        vertical: UIConstants.spacing4,
      ),
      decoration: BoxDecoration(
        gradient: isAdminRole ? AppColors.accentGradient : null,
        color: isAdminRole ? null : AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: isAdminRole
            ? null
            : Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        role.displayName,
        style: TextStyle(
          color: isAdminRole ? Colors.white : AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildDashboardLink() {
    return InkWell(
      onTap: () => context.push(AppRoutes.adminHome),
      borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      child: Container(
        padding: EdgeInsets.all(UIConstants.paddingMedium),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.1),
              AppColors.secondary.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(UIConstants.spacing12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
              child: Icon(
                Icons.dashboard,
                color: AppColors.primary,
                size: UIConstants.iconLarge,
              ),
            ),
            SizedBox(width: UIConstants.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeLarge,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: UIConstants.spacing4),
                  Text(
                    'View setup progress and quick actions',
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeMedium,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}