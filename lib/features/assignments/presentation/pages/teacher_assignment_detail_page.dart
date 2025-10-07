// features/assignments/presentation/pages/teacher_assignment_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../bloc/teacher_assignment_bloc.dart';

class TeacherAssignmentDetailPage extends StatefulWidget {
  final String teacherId;

  const TeacherAssignmentDetailPage({
    super.key,
    required this.teacherId,
  });

  @override
  State<TeacherAssignmentDetailPage> createState() =>
      _TeacherAssignmentDetailPageState();
}

class _TeacherAssignmentDetailPageState
    extends State<TeacherAssignmentDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TeacherAssignmentBloc, TeacherAssignmentState>(
      listener: _handleStateChanges,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: BlocBuilder<TeacherAssignmentBloc, TeacherAssignmentState>(
          builder: (context, state) {
            if (state is TeacherAssignmentLoading) {
              return _buildLoadingState(state.message);
            }

            if (state is TeacherAssignmentError) {
              return _buildErrorState(state.message);
            }

            if (state is TeacherAssignmentLoaded) {
              return _buildContent(state);
            }

            return _buildLoadingState(null);
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: BlocBuilder<TeacherAssignmentBloc, TeacherAssignmentState>(
        builder: (context, state) {
          if (state is TeacherAssignmentLoaded) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.teacher.fullName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Manage assignments',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          }
          return const Text('Teacher Assignments');
        },
      ),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        tabs: const [
          Tab(text: 'Grades'),
          Tab(text: 'Subjects'),
        ],
      ),
    );
  }

  Widget _buildContent(TeacherAssignmentLoaded state) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildGradesTab(state),
        _buildSubjectsTab(state),
      ],
    );
  }

  Widget _buildGradesTab(TeacherAssignmentLoaded state) {
    return RefreshIndicator(
      onRefresh: () async => _reloadData(state.teacher),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(UIConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAssignedSection(
              title: 'Assigned Grades',
              emptyMessage: 'No grades assigned yet',
              items: state.assignedGrades,
              onRemove: (grade) => _removeGrade(grade.id),
              itemBuilder: (grade) => _buildGradeChip(grade, isAssigned: true),
            ),
            SizedBox(height: UIConstants.spacing24),
            _buildAvailableSection(
              title: 'Available Grades',
              emptyMessage: 'All grades are assigned',
              items: _getUnassignedGrades(
                state.availableGrades,
                state.assignedGrades,
              ),
              onAdd: (grade) => _assignGrade(grade.id),
              itemBuilder: (grade) => _buildGradeChip(grade, isAssigned: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectsTab(TeacherAssignmentLoaded state) {
    return RefreshIndicator(
      onRefresh: () async => _reloadData(state.teacher),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(UIConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAssignedSection(
              title: 'Assigned Subjects',
              emptyMessage: 'No subjects assigned yet',
              items: state.assignedSubjects,
              onRemove: (subject) => _removeSubject(subject.id),
              itemBuilder: (subject) => _buildSubjectChip(subject, isAssigned: true),
            ),
            SizedBox(height: UIConstants.spacing24),
            _buildAvailableSection(
              title: 'Available Subjects',
              emptyMessage: 'All subjects are assigned',
              items: _getUnassignedSubjects(
                state.availableSubjects,
                state.assignedSubjects,
              ),
              onAdd: (subject) => _assignSubject(subject.id),
              itemBuilder: (subject) => _buildSubjectChip(subject, isAssigned: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedSection<T>({
    required String title,
    required String emptyMessage,
    required List<T> items,
    required Function(T) onRemove,
    required Widget Function(T) itemBuilder,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
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
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: UIConstants.iconMedium,
                ),
                SizedBox(width: UIConstants.spacing8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeXLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: UIConstants.spacing12,
                    vertical: UIConstants.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                UIConstants.paddingMedium,
                0,
                UIConstants.paddingMedium,
                UIConstants.paddingMedium,
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(UIConstants.paddingLarge),
                  child: Text(
                    emptyMessage,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: UIConstants.fontSizeMedium,
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(
                UIConstants.paddingMedium,
                0,
                UIConstants.paddingMedium,
                UIConstants.paddingMedium,
              ),
              child: Wrap(
                spacing: UIConstants.spacing8,
                runSpacing: UIConstants.spacing8,
                children: items.map((item) {
                  return GestureDetector(
                    onTap: () => _showRemoveConfirmation(
                      onConfirm: () => onRemove(item),
                    ),
                    child: itemBuilder(item),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvailableSection<T>({
    required String title,
    required String emptyMessage,
    required List<T> items,
    required Function(T) onAdd,
    required Widget Function(T) itemBuilder,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
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
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: AppColors.primary,
                  size: UIConstants.iconMedium,
                ),
                SizedBox(width: UIConstants.spacing8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeXLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: UIConstants.spacing12,
                    vertical: UIConstants.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                UIConstants.paddingMedium,
                0,
                UIConstants.paddingMedium,
                UIConstants.paddingMedium,
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(UIConstants.paddingLarge),
                  child: Text(
                    emptyMessage,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: UIConstants.fontSizeMedium,
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.fromLTRB(
                UIConstants.paddingMedium,
                0,
                UIConstants.paddingMedium,
                UIConstants.paddingMedium,
              ),
              child: Wrap(
                spacing: UIConstants.spacing8,
                runSpacing: UIConstants.spacing8,
                children: items.map((item) {
                  return GestureDetector(
                    onTap: () => onAdd(item),
                    child: itemBuilder(item),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGradeChip(GradeEntity grade, {required bool isAssigned}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: UIConstants.spacing12,
        vertical: UIConstants.spacing8,
      ),
      decoration: BoxDecoration(
        color: isAssigned
            ? AppColors.success.withOpacity(0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(
          color: isAssigned
              ? AppColors.success.withOpacity(0.3)
              : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAssigned ? Icons.school : Icons.add,
            size: 16,
            color: isAssigned ? AppColors.success : AppColors.primary,
          ),
          SizedBox(width: UIConstants.spacing4),
          Text(
            'Grade ${grade.gradeNumber}', // CHANGED from grade.displayName
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isAssigned ? AppColors.success : AppColors.textPrimary,
              fontSize: UIConstants.fontSizeMedium,
            ),
          ),
          if (isAssigned) ...[
            SizedBox(width: UIConstants.spacing4),
            Icon(
              Icons.close,
              size: 14,
              color: AppColors.error,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubjectChip(SubjectEntity subject, {required bool isAssigned}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: UIConstants.spacing12,
        vertical: UIConstants.spacing8,
      ),
      decoration: BoxDecoration(
        color: isAssigned
            ? AppColors.success.withOpacity(0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(
          color: isAssigned
              ? AppColors.success.withOpacity(0.3)
              : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAssigned ? Icons.book : Icons.add,
            size: 16,
            color: isAssigned ? AppColors.success : AppColors.primary,
          ),
          SizedBox(width: UIConstants.spacing4),
          Text(
            subject.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isAssigned ? AppColors.success : AppColors.textPrimary,
              fontSize: UIConstants.fontSizeMedium,
            ),
          ),
          if (isAssigned) ...[
            SizedBox(width: UIConstants.spacing4),
            Icon(
              Icons.close,
              size: 14,
              color: AppColors.error,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState(String? message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          if (message != null) ...[
            SizedBox(height: UIConstants.spacing16),
            Text(
              message,
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

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(UIConstants.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: UIConstants.iconHuge,
              color: AppColors.error,
            ),
            SizedBox(height: UIConstants.spacing16),
            Text(
              'Error Loading Assignments',
              style: TextStyle(
                fontSize: UIConstants.fontSizeXXLarge,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UIConstants.spacing8),
            Text(
              message,
              style: TextStyle(
                fontSize: UIConstants.fontSizeMedium,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: UIConstants.spacing24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: UIConstants.spacing24,
                  vertical: UIConstants.spacing12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<GradeEntity> _getUnassignedGrades(
      List<GradeEntity> available,
      List<GradeEntity> assigned,
      ) {
    final assignedIds = assigned.map((g) => g.id).toSet();
    return available.where((g) => !assignedIds.contains(g.id)).toList();
  }

  List<SubjectEntity> _getUnassignedSubjects(
      List<SubjectEntity> available,
      List<SubjectEntity> assigned,
      ) {
    final assignedIds = assigned.map((s) => s.id).toSet();
    return available.where((s) => !assignedIds.contains(s.id)).toList();
  }

  void _assignGrade(String gradeId) {
    context.read<TeacherAssignmentBloc>().add(
      AssignGrade(widget.teacherId, gradeId),
    );
  }

  void _removeGrade(String gradeId) {
    context.read<TeacherAssignmentBloc>().add(
      RemoveGrade(widget.teacherId, gradeId),
    );
  }

  void _assignSubject(String subjectId) {
    context.read<TeacherAssignmentBloc>().add(
      AssignSubject(widget.teacherId, subjectId),
    );
  }

  void _removeSubject(String subjectId) {
    context.read<TeacherAssignmentBloc>().add(
      RemoveSubject(widget.teacherId, subjectId),
    );
  }

  void _reloadData(UserEntity teacher) {
    context.read<TeacherAssignmentBloc>().add(
      LoadTeacherAssignments(teacher),
    );
  }

  void _handleStateChanges(BuildContext context, TeacherAssignmentState state) {
    if (state is AssignmentSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: UIConstants.spacing8),
              Expanded(child: Text(state.message)),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Reload the assignments after successful operation
      final bloc = context.read<TeacherAssignmentBloc>();
      if (bloc.state is TeacherAssignmentLoaded) {
        final loadedState = bloc.state as TeacherAssignmentLoaded;
        bloc.add(LoadTeacherAssignments(loadedState.teacher));
      }
    }

    if (state is TeacherAssignmentError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: UIConstants.spacing8),
              Expanded(child: Text(state.message)),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          ),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  void _showRemoveConfirmation({
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            SizedBox(width: UIConstants.spacing12),
            const Text('Remove Assignment'),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove this assignment?',
        ),
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
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}