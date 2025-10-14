// features/question_papers/pages/widgets/question_input_dialog.dart
import 'package:flutter/material.dart';
import 'package:papercraft/features/paper_creation/domain/services/question_input_coordinator.dart';
import '../../../../catalog/domain/entities/paper_section_entity.dart';
import '../../../../catalog/domain/entities/subject_entity.dart';
import '../../../../paper_workflow/domain/entities/question_entity.dart';
import '../../../../paper_workflow/domain/entities/question_paper_entity.dart';

class QuestionInputDialog extends StatelessWidget {
  final List<PaperSectionEntity> paperSections;
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
    required this.paperSections,
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
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        margin: EdgeInsets.only(top: isMobile ? 40 : 60),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(isMobile ? 20 : 12)),
        ),
        child: Column(
          children: [
            // Header with close button
            Container(
              padding: EdgeInsets.fromLTRB(20, isMobile ? 16 : 20, 8, 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Questions' : 'Add Questions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Coordinator content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 20 : 24),
                child: QuestionInputCoordinator(
                  paperSections: paperSections,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}