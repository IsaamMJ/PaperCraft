// features/question_papers/presentation/widgets/question_input_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:papercraft/features/question_papers/presentation/widgets/question_input/question_input_coordinator.dart';
import '../../../domain/entities/exam_type_entity.dart';
import '../../../domain/entities/question_entity.dart';
import '../../../domain/entities/question_paper_entity.dart';
import '../../../domain/entities/subject_entity.dart';

class QuestionInputDialog extends StatelessWidget {
  final List<ExamSectionEntity> sections;
  final ExamTypeEntity examType;
  final List<SubjectEntity> selectedSubjects;
  final String paperTitle;
  final int gradeLevel;
  final List<String> selectedSections;
  final Function(QuestionPaperEntity) onPaperCreated;

  // Edit mode parameters
  final Map<String, List<Question>>? existingQuestions;
  final bool isEditing;
  final String? existingPaperId;

  const QuestionInputDialog({
    super.key,
    required this.sections,
    required this.examType,
    required this.selectedSubjects,
    required this.paperTitle,
    required this.gradeLevel,
    required this.selectedSections,
    required this.onPaperCreated,
    this.existingQuestions,
    this.isEditing = false,
    this.existingPaperId,
  });

  @override
  Widget build(BuildContext context) {
    // The dialog now simply wraps the coordinator
    return QuestionInputCoordinator(
      sections: sections,
      examType: examType,
      selectedSubjects: selectedSubjects,
      paperTitle: paperTitle,
      gradeLevel: gradeLevel,
      selectedSections: selectedSections,
      onPaperCreated: onPaperCreated,
      existingQuestions: existingQuestions,
      isEditing: isEditing,
      existingPaperId: existingPaperId,
    );
  }
}