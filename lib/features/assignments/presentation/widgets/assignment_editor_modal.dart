// features/assignments/presentation/widgets/assignment_editor_modal.dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../catalog/domain/entities/grade_entity.dart';
import '../../../catalog/domain/entities/grade_section.dart';
import '../../../catalog/domain/entities/subject_entity.dart';
import '../../domain/entities/teacher_subject_assignment_entity.dart';

class AssignmentEditorModal extends StatefulWidget {
  final UserEntity teacher;
  final List<GradeEntity> grades;
  final List<GradeSection> sections;
  final Map<int, List<String>> subjectsPerGrade; // Subjects offered per grade
  final Map<String, String> subjectNameToIdMap; // Mapping of subject name to subject ID
  final Function(TeacherSubjectAssignmentEntity) onSave;
  final String tenantId;

  const AssignmentEditorModal({
    super.key,
    required this.teacher,
    required this.grades,
    required this.sections,
    required this.subjectsPerGrade,
    required this.subjectNameToIdMap,
    required this.onSave,
    required this.tenantId,
  });

  @override
  State<AssignmentEditorModal> createState() => _AssignmentEditorModalState();
}

class _AssignmentEditorModalState extends State<AssignmentEditorModal> {
  GradeEntity? _selectedGrade;
  final Set<String> _selectedSectionIds = {};
  final Set<String> _selectedSubjectIds = {};

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(UIConstants.radiusXLarge),
          topRight: Radius.circular(UIConstants.radiusXLarge),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: UIConstants.paddingMedium,
            right: UIConstants.paddingMedium,
            top: UIConstants.paddingMedium,
            bottom: MediaQuery.of(context).viewInsets.bottom +
                UIConstants.paddingMedium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              SizedBox(height: UIConstants.spacing24),
              _buildGradeSelector(widget.grades),
              if (_selectedGrade != null) ...[
                SizedBox(height: UIConstants.spacing16),
                _buildSectionSelector(widget.sections),
                SizedBox(height: UIConstants.spacing16),
                _buildSubjectSelector(),
              ],
              SizedBox(height: UIConstants.spacing24),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Add Assignment',
              style: TextStyle(
                fontSize: UIConstants.fontSizeXLarge,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        Text(
          'Assign a grade and subjects to ${widget.teacher.fullName}',
          style: TextStyle(
            fontSize: UIConstants.fontSizeMedium,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildGradeSelector(List<GradeEntity> grades) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Grade',
          style: TextStyle(
            fontSize: UIConstants.fontSizeLarge,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing8),
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: grades
                .map((grade) => _buildGradeButton(grade))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildGradeButton(GradeEntity grade) {
    final isSelected = _selectedGrade?.id == grade.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGrade = grade;
          _selectedSectionIds.clear();
          _selectedSubjectIds.clear();
        });
      },
      child: Container(
        margin: EdgeInsets.only(right: UIConstants.spacing8),
        padding: EdgeInsets.symmetric(
          horizontal: UIConstants.spacing16,
          vertical: UIConstants.spacing12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            'Grade ${grade.gradeNumber}',
            style: TextStyle(
              fontSize: UIConstants.fontSizeMedium,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionSelector(List<GradeSection> sections) {
    if (_selectedGrade == null) {
      return const SizedBox.shrink();
    }

    final gradeId = _selectedGrade?.id;
    if (gradeId == null) {
      return const SizedBox.shrink();
    }

    final gradeSections = sections
        .where((s) => s.gradeId == gradeId)
        .toList();

    if (gradeSections.isEmpty) {
      return Container(
        padding: EdgeInsets.all(UIConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            'No sections available for this grade',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: UIConstants.fontSizeMedium,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Sections',
          style: TextStyle(
            fontSize: UIConstants.fontSizeLarge,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing8),
        Wrap(
          spacing: UIConstants.spacing8,
          runSpacing: UIConstants.spacing8,
          children: gradeSections
              .map((section) => _buildSectionChip(section))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSectionChip(GradeSection section) {
    final isSelected = _selectedSectionIds.contains(section.id);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedSectionIds.remove(section.id);
          } else {
            _selectedSectionIds.add(section.id);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: UIConstants.spacing12,
          vertical: UIConstants.spacing8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          section.sectionName,
          style: TextStyle(
            fontSize: UIConstants.fontSizeMedium,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectSelector() {

    // Get subjects for the selected grade
    final gradeNumber = _selectedGrade?.gradeNumber;
    final subjectsForGrade = gradeNumber != null
        ? widget.subjectsPerGrade[gradeNumber] ?? []
        : <String>[];


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Subjects',
          style: TextStyle(
            fontSize: UIConstants.fontSizeLarge,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: UIConstants.spacing8),
        if (subjectsForGrade.isEmpty)
          Container(
            padding: EdgeInsets.all(UIConstants.paddingMedium),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                'No subjects available for this grade',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: UIConstants.fontSizeMedium,
                ),
              ),
            ),
          )
        else
          Wrap(
            spacing: UIConstants.spacing8,
            runSpacing: UIConstants.spacing8,
            children: subjectsForGrade
                .map((subjectName) => _buildSubjectChip(subjectName))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildSubjectChip(String subjectName) {
    final isSelected = _selectedSubjectIds.contains(subjectName);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedSubjectIds.remove(subjectName);
          } else {
            _selectedSubjectIds.add(subjectName);
          }
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: UIConstants.spacing12,
          vertical: UIConstants.spacing8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          subjectName,
          style: TextStyle(
            fontSize: UIConstants.fontSizeMedium,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final canSave = _selectedGrade != null &&
        _selectedSubjectIds.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                vertical: UIConstants.paddingMedium,
              ),
              side: BorderSide(color: AppColors.border),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: UIConstants.fontSizeMedium,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
        SizedBox(width: UIConstants.spacing12),
        Expanded(
          child: ElevatedButton(
            onPressed: canSave ? _saveAssignments : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canSave ? AppColors.primary : AppColors.border,
              disabledBackgroundColor: AppColors.border,
              padding: EdgeInsets.symmetric(
                vertical: UIConstants.paddingMedium,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
            child: Text(
              'Save',
              style: TextStyle(
                fontSize: UIConstants.fontSizeMedium,
                fontWeight: FontWeight.w600,
                color: canSave ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _saveAssignments() {

    if (_selectedGrade == null || _selectedSubjectIds.isEmpty) {
      return;
    }


    // Create assignment for each selected subject and section
    int assignmentCount = 0;
    for (final subjectName in _selectedSubjectIds) {

      // If no sections selected, create one assignment without section
      final sectionsToUse = _selectedSectionIds.isEmpty
          ? ['']
          : _selectedSectionIds.toList();


      for (final sectionId in sectionsToUse) {

        final selectedSection = _selectedSectionIds.contains(sectionId)
            ? widget.sections.firstWhere(
                (s) => s.id == sectionId,
                orElse: () => widget.sections.first,
              )
            : null;


        // Map subject name to actual subject ID (UUID)
        final actualSubjectId = widget.subjectNameToIdMap[subjectName];

        if (actualSubjectId == null) {
          continue;
        }


        // Set start date to today and end date to end of academic year (May 31, 2026)
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day); // Date only, no time
        final endOfYear = DateTime(2026, 5, 31);

        final assignment = TeacherSubjectAssignmentEntity(
          id: _generateId(),
          tenantId: widget.teacher.tenantId ?? '',
          teacherId: widget.teacher.id,
          gradeId: _selectedGrade!.id,
          subjectId: actualSubjectId, // Use actual UUID, not subject name
          teacherName: widget.teacher.fullName,
          teacherEmail: widget.teacher.email,
          gradeNumber: _selectedGrade!.gradeNumber,
          section: selectedSection?.sectionName,
          subjectName: subjectName, // Store the friendly subject name
          academicYear: '2025-2026',
          startDate: today,
          endDate: endOfYear,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );


        widget.onSave(assignment);
        assignmentCount++;
      }
    }

  }

  String _generateId() {
    return const Uuid().v4();
  }
}
