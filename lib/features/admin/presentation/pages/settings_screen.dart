import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert' show utf8, base64Encode;
import 'dart:io' show File, Platform, Directory;
import 'package:path_provider/path_provider.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
// Conditional import for web download helper
// Uses web-specific version on Flutter web, stub on other platforms
import '../utils/web_download_helper_stub.dart' if (dart.library.html) '../utils/web_download_helper.dart';
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
import '../../../catalog/domain/repositories/grade_repository.dart';
import '../../../catalog/domain/repositories/grade_section_repository.dart';
import '../../../catalog/domain/repositories/grade_subject_repository.dart';
import '../../../catalog/domain/repositories/subject_repository.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/grade_section.dart';
import '../../../catalog/domain/entities/grade_subject.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../domain/services/report_generator_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with TickerProviderStateMixin {
  late final UserStateService _userStateService;
  late final TabController _managementTabController;

  // Count state
  int? _subjectCount;
  int? _gradeCount;
  int? _examTypeCount;

  // Tab state for Management section
  int _selectedManagementTab = 0;

  @override
  void initState() {
    super.initState();
    _userStateService = sl<UserStateService>();
    _managementTabController = TabController(length: 2, vsync: this);
    _loadCounts();
  }

  @override
  void dispose() {
    _managementTabController.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    if (!_userStateService.isAdmin) return;

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
                color: AppColors.primary10,
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
          body: SingleChildScrollView(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: UIConstants.paddingMedium),
          child: Row(
            children: [
              Icon(Icons.settings_outlined, color: AppColors.primary, size: 24),
              SizedBox(width: UIConstants.spacing8),
              Text(
                'Management',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: UIConstants.spacing12),

        // TabBar
        Container(
          color: AppColors.surface,
          child: TabBar(
            controller: _managementTabController,
            onTap: (index) {
              setState(() {
                _selectedManagementTab = index;
              });
            },
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Reports'),
            ],
          ),
        ),

        // Tab Content
        if (_selectedManagementTab == 0) ...[
          _buildManagementOverviewTab(),
        ] else if (_selectedManagementTab == 1) ...[
          _buildReportsTab(),
        ],
      ],
    );
  }

  Widget _buildManagementOverviewTab() {
    return Padding(
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      child: Column(
        children: [
          _buildNavigationTile(
            title: 'Manage Subjects',
            subtitle: 'Add, edit, or remove subjects',
            icon: Icons.subject_outlined,
            route: AppRoutes.settingsSubjects,
            count: _subjectCount,
          ),
          _buildNavigationTile(
            title: 'Academic Structure',
            subtitle: 'Configure grades, sections & subjects',
            icon: Icons.school_outlined,
            route: AppRoutes.settingsGrades,
            count: _gradeCount,
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
      ),
    );
  }

  Widget _buildReportsTab() {
    return Padding(
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Export Academic Structure',
            style: TextStyle(
              fontSize: UIConstants.fontSizeMedium,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UIConstants.spacing8),
          Text(
            'Download a CSV file containing all grades, sections, and subjects assigned in your tenant',
            style: TextStyle(
              fontSize: UIConstants.fontSizeSmall,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: UIConstants.spacing24),
          ElevatedButton.icon(
            onPressed: _downloadAcademicStructureReport,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download as CSV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: UIConstants.spacing24,
                vertical: UIConstants.spacing12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAcademicStructureReport() async {
    try {
      // Show loading indicator
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating report...')),
      );

      final tenantId = _userStateService.currentTenantId;
      if (tenantId == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenant not found')),
        );
        return;
      }

      // Fetch all required data
      final gradesResult = await sl<GradeRepository>().getGrades();
      final subjectsResult = await sl<SubjectRepository>().getSubjects();

      final grades = gradesResult.fold(
        (failure) => <GradeEntity>[],
        (list) => list,
      );
      final subjects = subjectsResult.fold(
        (failure) => <SubjectEntity>[],
        (list) => list,
      );

      if (grades.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No grades found')),
        );
        return;
      }

      // Build subjects map for quick lookup
      final subjectsMap = <String, SubjectEntity>{};
      for (final subject in subjects) {
        subjectsMap[subject.id] = subject;
      }

      // Fetch sections and subjects per section
      final sectionsPerGrade = <String, List<GradeSection>>{};
      final subjectsPerSection = <String, List<GradeSubject>>{};

      for (final grade in grades) {
        final sectionsResult = await sl<GradeSectionRepository>().getGradeSections(
          tenantId: tenantId,
          gradeId: grade.id,
          // Use activeOnly: true for reports - only show active sections
        );

        final sections = sectionsResult.fold(
          (failure) => <GradeSection>[],
          (list) => list,
        );
        sectionsPerGrade[grade.id] = sections;

        for (final section in sections) {
          final subjectsResult = await sl<GradeSubjectRepository>().getSubjectsForGradeSection(
            tenantId: tenantId,
            gradeId: grade.id,
            sectionId: section.sectionName,  // Pass section name (A, B, C), not UUID
          );

          final sectionSubjects = subjectsResult.fold(
            (failure) => <GradeSubject>[],
            (list) => list,
          );
          subjectsPerSection[section.id] = sectionSubjects;
        }
      }

      // Generate CSV
      final csv = ReportGeneratorService.generateAcademicStructureCSV(
        grades: grades,
        sectionsPerGrade: sectionsPerGrade,
        subjectsPerSection: subjectsPerSection,
        subjectsMap: subjectsMap,
      );

      // Generate filename
      final filename = ReportGeneratorService.getAcademicStructureReportFilename();

      // Download based on platform
      if (kIsWeb) {
        // Web platform: use browser download
        _downloadFileWeb(csv, filename);
      } else {
        // Mobile platform: save file and share
        await _downloadFileMobile(csv, filename);
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report downloaded: $filename')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    }
  }

  /// Download CSV file on web platform
  void _downloadFileWeb(String csvContent, String filename) {
    if (!kIsWeb) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV download is only supported on web platform')),
      );
      return;
    }

    try {
      // Directly execute web download with CSV content
      _executeWebDownload(csvContent, filename);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading file: $e')),
      );
      if (kDebugMode) {
        print('Web download error: $e');
      }
    }
  }

  /// Execute web download (this will work on Flutter web)
  void _executeWebDownload(String csvContent, String filename) {
    // Only execute on web platform
    if (!kIsWeb) return;

    try {
      // Use web download helper to trigger browser download
      WebDownloadHelper.downloadCsvFile(csvContent, filename);

      if (kDebugMode) {
        print('Download initiated for: $filename');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading file: $e')),
      );
      if (kDebugMode) {
        print('Web download execution error: $e');
      }
    }
  }

  /// Download CSV file on mobile platform
  /// Saves the file to the Downloads directory
  Future<void> _downloadFileMobile(String csvContent, String filename) async {
    try {
      late Directory targetDir;

      if (Platform.isAndroid) {
        // On Android, try to get the external storage directory (shared Downloads folder)
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navigate from app-specific directory to shared Downloads
          // Path pattern: /storage/emulated/0/Android/data/com.example.app/files
          // Target: /storage/emulated/0/Download
          final parts = externalDir.path.split('/');
          final emulatedIndex = parts.indexOf('emulated');

          if (emulatedIndex != -1) {
            // Reconstruct path to Downloads folder
            final downloadsPath = '${parts.sublist(0, emulatedIndex + 2).join('/')}/Download';
            targetDir = Directory(downloadsPath);

            // Create Downloads directory if it doesn't exist
            if (!await targetDir.exists()) {
              await targetDir.create(recursive: true);
            }
          } else {
            // Fallback: use getDownloadsDirectory
            final fallbackDir = await getDownloadsDirectory();
            if (fallbackDir == null) {
              throw Exception('Could not access downloads directory');
            }
            targetDir = fallbackDir;
          }
        } else {
          // If external storage is not available, use fallback
          final fallbackDir = await getDownloadsDirectory();
          if (fallbackDir == null) {
            throw Exception('Could not access downloads directory');
          }
          targetDir = fallbackDir;
        }
      } else if (Platform.isIOS) {
        // On iOS, use application documents directory
        final appDocsDir = await getApplicationDocumentsDirectory();
        targetDir = appDocsDir;
      } else {
        throw Exception('Platform not supported');
      }

      // Create the file path
      final filePath = '${targetDir.path}/$filename';
      final file = File(filePath);

      // Ensure parent directory exists
      await file.parent.create(recursive: true);

      // Write CSV content to file
      await file.writeAsString(csvContent);

      if (!context.mounted) return;

      // Show success message with file location
      String message;
      if (Platform.isAndroid) {
        message = 'Report saved to Downloads: $filename';
      } else if (Platform.isIOS) {
        message = 'Report saved to Documents: $filename\n(Access via Files app)';
      } else {
        message = 'Report saved: $filename';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ),
      );

      if (kDebugMode) {
        print('File saved to: $filePath');
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving file: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
      if (kDebugMode) {
        print('Mobile download error: $e');
      }
    }
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
                  color: AppColors.primary10,
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
            color: AppColors.black04,
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
              color: AppColors.white20,
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
                    color: Colors.white,
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
        color: isAdminRole ? null : AppColors.primary10,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: isAdminRole
            ? null
            : Border.all(color: AppColors.primary20),
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
}