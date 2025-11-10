import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../../core/infrastructure/di/injection_container.dart';

/// Exams Management Dashboard
///
/// Central hub for all exam-related management:
/// - Exam Calendars: Create and manage exam periods
/// - Grade Sections: Configure which sections take which exams
/// - Exam Timetables: Create detailed exam schedules
class ExamsDashboardPage extends StatefulWidget {
  final String tenantId;

  const ExamsDashboardPage({
    required this.tenantId,
    super.key,
  });

  @override
  State<ExamsDashboardPage> createState() => _ExamsDashboardPageState();
}

class _ExamsDashboardPageState extends State<ExamsDashboardPage> {
  late final UserStateService _userStateService;

  @override
  void initState() {
    super.initState();
    _userStateService = sl<UserStateService>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Exam Management'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(UIConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            SizedBox(height: UIConstants.spacing24),
            _buildExamFeatures(),
            SizedBox(height: UIConstants.spacing24),
            _buildWorkflowInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingLarge),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                color: Colors.white,
                size: UIConstants.iconXLarge,
              ),
              SizedBox(width: UIConstants.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exam Management System',
                      style: TextStyle(
                        fontSize: UIConstants.fontSizeXXLarge,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: UIConstants.spacing4),
                    Text(
                      'Create calendars, manage sections, and build timetables',
                      style: TextStyle(
                        fontSize: UIConstants.fontSizeMedium,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExamFeatures() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Management Features',
          style: TextStyle(
            fontSize: UIConstants.fontSizeXLarge,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing16),
        _buildFeatureCard(
          title: 'Exam Calendars',
          subtitle: 'Create and manage exam periods (e.g., Mid-term, Final)',
          icon: Icons.calendar_month,
          color: Colors.blue,
          actionText: 'Manage Calendars',
          onTap: () {
            final userStateService = sl<UserStateService>();
            final academicYear = userStateService.currentAcademicYear;
            print('[ExamsDashboardPage] Navigating to exam calendars with academic year: $academicYear');
            context.push('${AppRoutes.examCalendarList}?academicYear=$academicYear');
          },
          description: 'Define exam schedules that will be used as templates for timetables',
        ),
        SizedBox(height: UIConstants.spacing12),
        _buildFeatureCard(
          title: 'Grade Assignment',
          subtitle: 'Select which grades participate in each exam',
          icon: Icons.people,
          color: Colors.green,
          actionText: 'Assign Grades',
          onTap: () {
            print('[ExamsDashboardPage] Navigating to grade selection');
            context.push(AppRoutes.examGradeSelection);
          },
          description: 'Choose grades for the exam calendar',
        ),
        SizedBox(height: UIConstants.spacing12),
        _buildFeatureCard(
          title: 'Exam Timetables',
          subtitle: 'Create detailed exam schedules with dates, times, and venues',
          icon: Icons.schedule,
          color: Colors.orange,
          actionText: 'Manage Timetables',
          onTap: () {
            final userStateService = sl<UserStateService>();
            final academicYear = userStateService.currentAcademicYear;
            print('[ExamsDashboardPage] Navigating to exam timetables with academic year: $academicYear');
            context.push('${AppRoutes.examTimetableList}?academicYear=$academicYear');
          },
          description: 'Build comprehensive exam timetables based on calendars and sections',
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String actionText,
    required VoidCallback onTap,
    required String description,
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
          border: Border.all(
            color: AppColors.border,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(UIConstants.spacing12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
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
            SizedBox(height: UIConstants.spacing12),
            Text(
              description,
              style: TextStyle(
                fontSize: UIConstants.fontSizeSmall,
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkflowInfo() {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingLarge),
      decoration: BoxDecoration(
        color: AppColors.primary10,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(
          color: AppColors.primary30,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.primary,
                size: UIConstants.iconMedium,
              ),
              SizedBox(width: UIConstants.spacing12),
              Text(
                'Recommended Workflow',
                style: TextStyle(
                  fontSize: UIConstants.fontSizeLarge,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: UIConstants.spacing12),
          _buildWorkflowStep(1, 'Create Exam Calendars', 'Define exam periods (dates, types, submission deadlines)'),
          _buildWorkflowStep(2, 'Configure Grade Sections', 'Set up which sections participate in exams'),
          _buildWorkflowStep(3, 'Create Timetables', 'Build detailed exam schedules for each calendar'),
        ],
      ),
    );
  }

  Widget _buildWorkflowStep(int step, String title, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: UIConstants.spacing12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: UIConstants.fontSizeMedium,
                ),
              ),
            ),
          ),
          SizedBox(width: UIConstants.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeMedium,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: UIConstants.spacing4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeSmall,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
