// features/question_papers/pages/widgets/question_input_dialog.dart
import 'package:flutter/material.dart';
import 'package:papercraft/features/paper_creation/domain/services/question_input_coordinator.dart';
import '../../../../catalog/domain/entities/exam_type_entity.dart';
import '../../../../catalog/domain/entities/subject_entity.dart';
import '../../../../paper_workflow/domain/entities/question_entity.dart';
import '../../../../paper_workflow/domain/entities/question_paper_entity.dart';

class QuestionInputDialog extends StatelessWidget {
  final List<ExamSectionEntity> sections;
  final ExamTypeEntity examType;
  final List<SubjectEntity> selectedSubjects;
  final String paperTitle;
  final int gradeLevel;
  final String gradeId;
  final String academicYear;
  final List<String> selectedSections;
  final Function(QuestionPaperEntity) onPaperCreated;
  final DateTime? examDate;
  final bool isAdmin;

  // Edit mode parameters
  final Map<String, List<Question>>? existingQuestions;
  final bool isEditing;
  final String? existingPaperId;
  final String? existingTenantId;
  final String? existingUserId;

  const QuestionInputDialog({
    super.key,
    required this.sections,
    required this.examType,
    required this.selectedSubjects,
    required this.paperTitle,
    required this.gradeLevel,
    required this.gradeId,
    required this.academicYear,
    required this.selectedSections,
    required this.onPaperCreated,
    required this.isAdmin,
    this.existingQuestions,
    this.isEditing = false,
    this.existingPaperId,
    this.existingTenantId,
    this.existingUserId,
    this.examDate,
  });

  @override
  Widget build(BuildContext context) {
    return QuestionInputCoordinator(
      sections: sections,
      examType: examType,
      selectedSubjects: selectedSubjects,
      paperTitle: paperTitle,
      gradeLevel: gradeLevel,
      gradeId: gradeId,
      academicYear: academicYear,
      selectedSections: selectedSections,
      onPaperCreated: onPaperCreated,
      isAdmin: isAdmin,
      existingQuestions: existingQuestions,
      isEditing: isEditing,
      existingPaperId: existingPaperId,
      existingTenantId: existingTenantId,
      existingUserId: existingUserId,
      examDate: examDate,
    );
  }
}