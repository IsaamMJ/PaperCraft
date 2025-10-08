import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../../core/presentation/widgets/common_state_widgets.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/domain/services/user_state_service.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../paper_workflow/presentation/bloc/user_management_bloc.dart';
import '../../domain/repositories/assignment_repository.dart';

/// Matrix view showing all teacher assignments in a grid
class TeacherAssignmentMatrixPage extends StatefulWidget {
  const TeacherAssignmentMatrixPage({super.key});

  @override
  State<TeacherAssignmentMatrixPage> createState() =>
      _TeacherAssignmentMatrixPageState();
}

/// Holds assignment data for a teacher
class _TeacherAssignmentData {
  final List<GradeEntity> grades;
  final List<SubjectEntity> subjects;

  _TeacherAssignmentData({
    this.grades = const [],
    this.subjects = const [],
  });

  bool get hasAssignments => grades.isNotEmpty || subjects.isNotEmpty;
}

class _TeacherAssignmentMatrixPageState
    extends State<TeacherAssignmentMatrixPage> {
  final Map<String, _TeacherAssignmentData> _assignmentData = {};
  bool _isLoadingAssignments = false;

  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }

  void _loadTeachers() {
    context.read<UserManagementBloc>().add(const LoadUsers());
  }

  Future<void> _loadTeacherAssignments(List<UserEntity> teachers) async {
    if (_isLoadingAssignments) return;
    setState(() => _isLoadingAssignments = true);

    final assignmentRepo = sl<AssignmentRepository>();
    final userStateService = sl<UserStateService>();
    final academicYear = userStateService.currentAcademicYear;

    for (final teacher in teachers) {
      // Load assignments in parallel for each teacher
      final gradeResult = await assignmentRepo.getTeacherAssignedGrades(teacher.id, academicYear);
      final subjectResult = await assignmentRepo.getTeacherAssignedSubjects(teacher.id, academicYear);

      final grades = gradeResult.fold(
        (_) => <GradeEntity>[],
        (g) => g as List<GradeEntity>,
      );

      final subjects = subjectResult.fold(
        (_) => <SubjectEntity>[],
        (s) => s as List<SubjectEntity>,
      );

      if (mounted) {
        setState(() {
          _assignmentData[teacher.id] = _TeacherAssignmentData(
            grades: grades,
            subjects: subjects,
          );
        });
      }
    }

    setState(() => _isLoadingAssignments = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assignment Matrix',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'All teacher assignments at a glance',
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
            icon: const Icon(Icons.download),
            tooltip: 'Export',
            onPressed: () {
              // TODO: Export functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export coming soon!')),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<UserManagementBloc, UserManagementState>(
        builder: (context, state) {
          if (state is UserManagementLoading) {
            return const LoadingWidget(message: 'Loading teachers...');
          }

          if (state is UserManagementError) {
            return ErrorStateWidget(
              message: state.message,
              onRetry: _loadTeachers,
            );
          }

          if (state is UserManagementLoaded) {
            final teachers =
                state.users.where((u) => u.isTeacher).toList();

            if (teachers.isEmpty) {
              return const EmptyMessageWidget(
                icon: Icons.people_outline,
                title: 'No Teachers Found',
                message: 'No teachers have been added to the system yet',
              );
            }

            // Load assignments if not already loaded
            if (_assignmentData.isEmpty && !_isLoadingAssignments) {
              _loadTeacherAssignments(teachers);
            }

            return _buildMatrixView(teachers);
          }

          return const EmptyMessageWidget(
            icon: Icons.grid_on,
            title: 'Assignment Matrix',
            message: 'Loading teacher assignments...',
          );
        },
      ),
    );
  }

  Widget _buildMatrixView(List<UserEntity> teachers) {
    return RefreshIndicator(
      onRefresh: () async => _loadTeachers(),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(UIConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCards(teachers),
            SizedBox(height: UIConstants.spacing24),
            _buildMatrixTable(teachers),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards(List<UserEntity> teachers) {
    // Calculate assigned/unassigned counts
    int assignedCount = 0;
    for (final teacher in teachers) {
      final data = _assignmentData[teacher.id];
      if (data != null && data.hasAssignments) {
        assignedCount++;
      }
    }
    final unassignedCount = teachers.length - assignedCount;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            title: 'Total Teachers',
            count: teachers.length,
            icon: Icons.people,
            color: AppColors.primary,
          ),
        ),
        SizedBox(width: UIConstants.spacing12),
        Expanded(
          child: _buildSummaryCard(
            title: 'Assigned',
            count: assignedCount,
            icon: Icons.check_circle,
            color: AppColors.success,
          ),
        ),
        SizedBox(width: UIConstants.spacing12),
        Expanded(
          child: _buildSummaryCard(
            title: 'Unassigned',
            count: unassignedCount,
            icon: Icons.warning,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: UIConstants.iconLarge),
          SizedBox(height: UIConstants.spacing8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: UIConstants.fontSizeXXLarge,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: UIConstants.spacing4),
          Text(
            title,
            style: TextStyle(
              fontSize: UIConstants.fontSizeSmall,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixTable(List<UserEntity> teachers) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient.scale(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(UIConstants.radiusLarge),
                topRight: Radius.circular(UIConstants.radiusLarge),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Teacher Name',
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeMedium,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Grades',
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeMedium,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Subjects',
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeMedium,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    'Status',
                    style: TextStyle(
                      fontSize: UIConstants.fontSizeSmall,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: teachers.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: AppColors.border,
            ),
            itemBuilder: (context, index) {
              return _buildTeacherRow(teachers[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherRow(UserEntity teacher) {
    final data = _assignmentData[teacher.id];
    final hasAssignments = data?.hasAssignments ?? false;

    // Format grades and subjects for display
    String gradesText = '—';
    String subjectsText = '—';

    if (data != null) {
      if (data.grades.isNotEmpty) {
        gradesText = data.grades.map((g) => g.displayName).join(', ');
      }
      if (data.subjects.isNotEmpty) {
        subjectsText = data.subjects.map((s) => s.name).join(', ');
      }
    }

    return InkWell(
      onTap: () {
        // Navigate to teacher assignment detail
        context.push(
          '${AppRoutes.teacherAssignments}/detail',
          extra: teacher,
        );
      },
      child: Container(
        padding: EdgeInsets.all(UIConstants.paddingMedium),
        child: Row(
          children: [
            // Name
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                    ),
                    child: Center(
                      child: Text(
                        teacher.fullName.isNotEmpty
                            ? teacher.fullName[0].toUpperCase()
                            : 'T',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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
                          teacher.fullName,
                          style: TextStyle(
                            fontSize: UIConstants.fontSizeMedium,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          teacher.email,
                          style: TextStyle(
                            fontSize: UIConstants.fontSizeSmall,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Grades
            Expanded(
              flex: 2,
              child: Text(
                gradesText,
                style: TextStyle(
                  fontSize: UIConstants.fontSizeSmall,
                  color: data != null && data.grades.isNotEmpty
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: data != null && data.grades.isNotEmpty
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Subjects
            Expanded(
              flex: 2,
              child: Text(
                subjectsText,
                style: TextStyle(
                  fontSize: UIConstants.fontSizeSmall,
                  color: data != null && data.subjects.isNotEmpty
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: data != null && data.subjects.isNotEmpty
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Status
            SizedBox(
              width: 40,
              child: Icon(
                hasAssignments ? Icons.check_circle : Icons.warning,
                color: hasAssignments ? AppColors.success : AppColors.warning,
                size: UIConstants.iconMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
