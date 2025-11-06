// features/assignments/presentation/pages/teacher_assignment_detail_page_new.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../../core/presentation/widgets/common_state_widgets.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/grade_section.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../../catalog/presentation/bloc/grade_bloc.dart';
import '../../../catalog/presentation/bloc/grade_section_bloc.dart';
import '../../../catalog/presentation/bloc/grade_section_event.dart';
import '../../../catalog/presentation/bloc/grade_section_state.dart';
import '../../../catalog/presentation/bloc/subject_bloc.dart';
import '../../domain/entities/teacher_subject_assignment_entity.dart';
import '../bloc/teacher_assignment_bloc.dart';
import '../bloc/teacher_assignment_event.dart';
import '../bloc/teacher_assignment_state.dart';
import '../widgets/assignment_editor_modal.dart';

class TeacherAssignmentDetailPageNew extends StatefulWidget {
  final UserEntity teacher;

  const TeacherAssignmentDetailPageNew({
    super.key,
    required this.teacher,
  });

  @override
  State<TeacherAssignmentDetailPageNew> createState() =>
      _TeacherAssignmentDetailPageNewState();
}

class _TeacherAssignmentDetailPageNewState
    extends State<TeacherAssignmentDetailPageNew> {
  List<GradeEntity> _grades = [];
  List<GradeSection> _sections = [];
  Map<int, List<String>> _subjectsPerGrade = {};
  Map<String, String> _subjectNameToIdMap = {}; // Map subject name to subject ID

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  void _loadAssignments() {
    final tenantId = widget.teacher.tenantId ?? 'main';

    context.read<TeacherAssignmentBloc>().add(
          LoadTeacherAssignmentsEvent(
            tenantId: tenantId,
            teacherId: widget.teacher.id,
          ),
        );

    // Load grades and sections for the assignment editor modal
    context.read<GradeBloc>().add(const LoadGrades());

    context.read<GradeSectionBloc>().add(
          LoadGradeSectionsEvent(tenantId: tenantId),
        );

    // Load subjects per grade like teacher onboarding does
    _loadSubjectsPerGrade(tenantId);
  }

  Future<void> _loadSubjectsPerGrade(String tenantId) async {
    try {
      final supabase = Supabase.instance.client;

      // Fetch all subjects offered by school for each grade (from grade_section_subject table)
      final gradeSubjectsData = await supabase
          .from('grade_section_subject')
          .select('*, grades(grade_number), subjects(id, catalog_subject_id)')
          .eq('tenant_id', tenantId)
          .eq('is_offered', true);

      for (var i = 0; i < (gradeSubjectsData as List).length && i < 3; i++) {
      }

      final subjectsPerGrade = <int, List<String>>{};
      final catalogSubjectIds = <String>{};

      // Collect all catalog subject IDs to fetch names
      for (var gradeSectionSubject in gradeSubjectsData as List) {
        final subjectData = gradeSectionSubject['subjects'] as Map<String, dynamic>?;
        final catalogSubjectId = subjectData?['catalog_subject_id'] as String?;
        if (catalogSubjectId != null) {
          catalogSubjectIds.add(catalogSubjectId);
        }
      }

      // Fetch subject names from catalog
      final catalogSubjectMap = <String, String>{};
      if (catalogSubjectIds.isNotEmpty) {
        try {
          final catalogData = await supabase
              .from('subject_catalog')
              .select('id, subject_name')
              .inFilter('id', catalogSubjectIds.toList());

          for (var catalog in catalogData as List) {
            final id = catalog['id'] as String;
            final name = catalog['subject_name'] as String;
            catalogSubjectMap[id] = name;
          }
        } catch (e) {
        }
      }

      // Build subjects per grade map and name-to-ID mapping
      final subjectNameToIdMap = <String, String>{};
      for (var gradeSectionSubject in gradeSubjectsData as List) {
        final gradeData = gradeSectionSubject['grades'] as Map<String, dynamic>?;
        final gradeNumber = gradeData?['grade_number'] as int?;
        final subjectData = gradeSectionSubject['subjects'] as Map<String, dynamic>?;
        final subjectId = subjectData?['id'] as String?;
        final catalogSubjectId = subjectData?['catalog_subject_id'] as String?;


        if (gradeNumber != null && catalogSubjectId != null && subjectId != null) {
          final subjectName = catalogSubjectMap[catalogSubjectId] ?? catalogSubjectId;


          // Store the mapping from subject name to subject ID
          subjectNameToIdMap[subjectName] = subjectId;

          subjectsPerGrade.putIfAbsent(gradeNumber, () => []);
          if (!subjectsPerGrade[gradeNumber]!.contains(subjectName)) {
            subjectsPerGrade[gradeNumber]!.add(subjectName);
          }
        } else {
        }
      }


      setState(() {
        _subjectsPerGrade = subjectsPerGrade;
        _subjectNameToIdMap = subjectNameToIdMap;
      });
    } catch (e, stackTrace) {
    }
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
            if (state is TeacherAssignmentsLoading) {
              return _buildLoadingState();
            }

            if (state is TeacherAssignmentError) {
              return _buildErrorState(state.errorMessage);
            }

            if (state is TeacherAssignmentsLoaded) {
              return _buildContent(state);
            }

            return _buildLoadingState();
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _showAddAssignmentModal,
          icon: const Icon(Icons.add),
          label: const Text('Add Assignment'),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.teacher.fullName,
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
      ),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
    );
  }

  Widget _buildContent(TeacherAssignmentsLoaded state) {
    // Group assignments by grade + section
    final groupedAssignments =
        _groupAssignmentsByGradeSection(state.assignments);

    if (groupedAssignments.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        _loadAssignments();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(UIConstants.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummary(state.assignments),
            SizedBox(height: UIConstants.spacing24),
            ...groupedAssignments.entries.map((entry) {
              return _buildGradeSectionGroup(
                gradeSection: entry.key,
                assignments: entry.value,
              );
            }).toList(),
            SizedBox(height: UIConstants.spacing32),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(List<TeacherSubjectAssignmentEntity> assignments) {
    final gradeCount = assignments
        .fold<Set<String>>({}, (set, a) {
          set.add(a.gradeId);
          return set;
        })
        .length;

    final subjectCount = assignments
        .fold<Set<String>>({}, (set, a) {
          set.add(a.subjectId);
          return set;
        })
        .length;

    return Container(
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        gradient: assignments.isNotEmpty
            ? AppColors.primaryGradient.scale(0.1)
            : null,
        color: assignments.isEmpty ? AppColors.surface : null,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(
          color: assignments.isNotEmpty
              ? AppColors.primary30
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            assignments.isNotEmpty ? Icons.check_circle : Icons.info_outline,
            color: assignments.isNotEmpty
                ? AppColors.primary
                : AppColors.textSecondary,
            size: UIConstants.iconLarge,
          ),
          SizedBox(width: UIConstants.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignments.isNotEmpty
                      ? 'Assignments Configured'
                      : 'No Assignments Yet',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeLarge,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: UIConstants.spacing4),
                Text(
                  assignments.isNotEmpty
                      ? '$gradeCount ${gradeCount == 1 ? 'grade' : 'grades'}, $subjectCount ${subjectCount == 1 ? 'subject' : 'subjects'}'
                      : 'Tap "Add Assignment" to get started',
                  style: TextStyle(
                    fontSize: UIConstants.fontSizeMedium,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: UIConstants.iconXLarge,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: UIConstants.spacing16),
          Text(
            'No Assignments',
            style: TextStyle(
              fontSize: UIConstants.fontSizeLarge,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UIConstants.spacing8),
          Text(
            'Tap the button below to add assignments',
            style: TextStyle(
              fontSize: UIConstants.fontSizeMedium,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeSectionGroup({
    required String gradeSection,
    required List<TeacherSubjectAssignmentEntity> assignments,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: UIConstants.spacing16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.black04,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGradeSectionHeader(gradeSection, assignments.length),
          Padding(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            child: Wrap(
              spacing: UIConstants.spacing8,
              runSpacing: UIConstants.spacing8,
              children: assignments
                  .map((assignment) =>
                      _buildSubjectChip(assignment, gradeSection))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeSectionHeader(String gradeSection, int subjectCount) {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.class_,
            color: AppColors.primary,
            size: UIConstants.iconMedium,
          ),
          SizedBox(width: UIConstants.spacing8),
          Text(
            'Grade $gradeSection',
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
              color: AppColors.primary10,
              borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
            ),
            child: Text(
              '$subjectCount',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectChip(
    TeacherSubjectAssignmentEntity assignment,
    String gradeSection,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: UIConstants.spacing12,
        vertical: UIConstants.spacing8,
      ),
      decoration: BoxDecoration(
        color: AppColors.success10,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.success),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.book,
            size: 16,
            color: AppColors.success,
          ),
          SizedBox(width: UIConstants.spacing4),
          Text(
            assignment.subjectName ?? assignment.subjectId,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.success,
              fontSize: UIConstants.fontSizeMedium,
            ),
          ),
          SizedBox(width: UIConstants.spacing4),
          GestureDetector(
            onTap: () => _confirmDelete(assignment),
            child: Icon(
              Icons.close,
              size: 14,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<TeacherSubjectAssignmentEntity>>
      _groupAssignmentsByGradeSection(
          List<TeacherSubjectAssignmentEntity> assignments) {
    final grouped = <String, List<TeacherSubjectAssignmentEntity>>{};

    for (final assignment in assignments) {
      final key = assignment.gradeSection;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(assignment);
    }

    // Sort by grade number
    final sorted = <String, List<TeacherSubjectAssignmentEntity>>{};
    final keys = grouped.keys.toList();
    keys.sort((a, b) {
      final gradeA =
          int.tryParse(a.split(':')[0]) ?? 0;
      final gradeB =
          int.tryParse(b.split(':')[0]) ?? 0;
      return gradeA.compareTo(gradeB);
    });

    for (final key in keys) {
      sorted[key] = grouped[key]!;
    }

    return sorted;
  }

  void _showAddAssignmentModal() {

    // Read current state from BLoCs in the parent context BEFORE showing modal
    final gradeState = context.read<GradeBloc>().state;
    final gradeSectionState = context.read<GradeSectionBloc>().state;
    final subjectState = context.read<SubjectBloc>().state;


    // Extract grades from state
    final grades = (gradeState is GradesLoaded) ? gradeState.grades : <GradeEntity>[];

    // Extract sections from state
    final sections = (gradeSectionState is GradeSectionLoaded)
        ? gradeSectionState.sections
        : <GradeSection>[];

    // Extract subjects from state - handle both loaded states
    List<SubjectEntity> subjects = <SubjectEntity>[];
    if (subjectState is SubjectsLoaded) {
      subjects = subjectState.subjects;
      for (var subject in subjects) {
      }
    } else if (subjectState is SubjectCatalogLoaded) {
      // Convert SubjectCatalogModel to SubjectEntity
      for (var catalogItem in subjectState.catalog) {
      }
      final tenantId = widget.teacher.tenantId ?? 'main';
      subjects = subjectState.catalog
          .map((catalog) => SubjectEntity(
                id: catalog.id,
                name: catalog.name,
                tenantId: tenantId,
                catalogSubjectId: catalog.id,
                isActive: catalog.isActive,
                minGrade: catalog.minGrade,
                maxGrade: catalog.maxGrade,
                createdAt: DateTime.now(),
              ))
          .toList();
      for (var subject in subjects) {
      }
    } else if (subjectState is SubjectLoading) {
    } else if (subjectState is SubjectError) {
    } else if (subjectState is SubjectInitial) {
    } else {
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AssignmentEditorModal(
          teacher: widget.teacher,
          grades: grades,
          sections: sections,
          subjectsPerGrade: _subjectsPerGrade,
          subjectNameToIdMap: _subjectNameToIdMap,
          tenantId: widget.teacher.tenantId ?? '',
          onSave: (assignment) {
            // Use the original context to access BLoCs
            this.context.read<TeacherAssignmentBloc>().add(
                  SaveTeacherAssignmentEvent(assignment: assignment),
                );
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void _confirmDelete(TeacherSubjectAssignmentEntity assignment) {
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
        content: Text(
          'Remove ${assignment.subjectName ?? assignment.subjectId} from Grade ${assignment.gradeNumber}?',
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
              context.read<TeacherAssignmentBloc>().add(
                    DeleteTeacherAssignmentEvent(assignmentId: assignment.id),
                  );
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

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error,
          ),
          SizedBox(height: UIConstants.spacing16),
          Text(message),
        ],
      ),
    );
  }

  void _handleStateChanges(BuildContext context, TeacherAssignmentState state) {
    if (state is AssignmentSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: UIConstants.spacing8),
              const Expanded(child: Text('Assignment saved successfully')),
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
      // Reload assignments after save
      _loadAssignments();
    }

    if (state is AssignmentDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: UIConstants.spacing8),
              const Expanded(child: Text('Assignment removed successfully')),
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
      // Reload assignments after delete
      _loadAssignments();
    }

    if (state is TeacherAssignmentError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: UIConstants.spacing8),
              Expanded(child: Text(state.errorMessage)),
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
}
