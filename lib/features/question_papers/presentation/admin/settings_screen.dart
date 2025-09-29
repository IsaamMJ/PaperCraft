// features/settings/presentation/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:papercraft/features/question_papers/presentation/admin/widgets/exam_type_management_widget.dart';
import 'package:papercraft/features/question_papers/presentation/admin/widgets/grade_management_widget.dart';
import 'package:papercraft/features/question_papers/presentation/admin/widgets/subject_management_widget.dart';
import 'package:papercraft/features/question_papers/presentation/admin/widgets/user_management_widget.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../../../question_papers/presentation/bloc/subject_bloc.dart';
import '../../../question_papers/presentation/bloc/grade_bloc.dart';
import '../../../question_papers/presentation/bloc/exam_type_bloc.dart';
import '../bloc/user_management_bloc.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late UserStateService _userStateService;

  @override
  void initState() {
    super.initState();
    _userStateService = sl<UserStateService>();
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

        // SECURITY: Only show settings to admin users
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
            automaticallyImplyLeading: false, // Remove back button since this is a main tab
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Section
                _buildProfileSection(user),
                const SizedBox(height: 24),

                // Management Sections
                _buildManagementSection(),
                const SizedBox(height: 24),

                // About Section (Simplified)
                _buildAboutSection(),
                const SizedBox(height: 24),

                // Danger Zone
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 64,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'Admin Access Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Only administrators can access settings',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
        const SizedBox(height: 8),
        _buildInfoTile(
          title: 'Email',
          subtitle: user.email ?? 'No email',
          icon: Icons.email_outlined,
        ),
        _buildInfoTile(
          title: 'Role',
          subtitle: _getRoleDisplayName(user.role),
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
          subtitle: _formatDate(user.createdAt),
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
        _buildActionTile(
          title: 'Manage Subjects',
          subtitle: 'Add, edit, or remove subjects',
          icon: Icons.subject_outlined,
          onTap: () => _showManagementDialog('Subjects', _createSubjectManagementWidget()),
        ),
        _buildActionTile(
          title: 'Manage Grades',
          subtitle: 'Configure grade levels and sections',
          icon: Icons.school_outlined,
          onTap: () => _showManagementDialog('Grades', _createGradeManagementWidget()),
        ),
        _buildActionTile(
          title: 'Manage Exam Types',
          subtitle: 'Configure exam formats and sections',
          icon: Icons.quiz_outlined,
          onTap: () => _showManagementDialog('Exam Types', _createExamTypeManagementWidget()),
        ),
        _buildActionTile(
          title: 'Manage Users',
          subtitle: 'Manage users in your tenant',
          icon: Icons.people_outline,
          onTap: () => _showManagementDialog('Users', _createUserManagementWidget()),
        ),
      ],
    );
  }

  // FIXED: Create properly provided widgets for each management type
  Widget _createSubjectManagementWidget() {
    return BlocProvider(
      create: (context) => sl<SubjectBloc>(),
      child: const SubjectManagementWidget(),
    );
  }

  Widget _createGradeManagementWidget() {
    return BlocProvider(
      create: (context) => sl<GradeBloc>(),
      child: const GradeManagementWidget(),
    );
  }

  Widget _createExamTypeManagementWidget() {
    return BlocProvider(
      create: (context) => sl<ExamTypeBloc>(),
      child: const ExamTypeManagementWidget(),
    );
  }

  Widget _createUserManagementWidget() {
    return BlocProvider(
      create: (context) => UserManagementBloc(),
      child: const UserManagementWidget(),
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
          onTap: () => _showSupportDialog(),
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: titleColor ?? AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
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
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _getRoleDisplayName(user.role),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
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
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: isAdminRole ? AppColors.accentGradient : null,
        color: isAdminRole ? null : AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: isAdminRole ? null : Border.all(
          color: AppColors.primary.withOpacity(0.2),
        ),
      ),
      child: Text(
        _getRoleDisplayName(role),
        style: TextStyle(
          color: isAdminRole ? Colors.white : AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }

  void _showManagementDialog(String title, Widget content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: content,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.support_agent, color: AppColors.primary),
              const SizedBox(width: 12),
              const Text('Help & Support'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('For support and assistance, please contact:'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.email, color: AppColors.primary),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'isaam.mj@gmail.com',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
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
        );
      },
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.logout, color: AppColors.error),
              const SizedBox(width: 12),
              const Text('Sign Out'),
            ],
          ),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<AuthBloc>().add(const AuthSignOut());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  String _getRoleDisplayName(UserRole role) {
    return role.displayName;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    return '${date.day}/${date.month}/${date.year}';
  }
}