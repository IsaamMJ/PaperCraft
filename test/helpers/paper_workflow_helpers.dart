import 'package:papercraft/features/catalog/domain/entities/exam_type.dart';
import 'package:papercraft/features/catalog/domain/entities/paper_section_entity.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/paper_status.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/question_entity.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/question_paper_entity.dart';

QuestionPaperEntity createMockPaper({
  String id = 'paper-123',
  String title = 'Test Paper',
  PaperStatus status = PaperStatus.draft,
  String? userId,
  String? tenantId,
  String? rejectionReason,
}) {
  return QuestionPaperEntity(
    id: id,
    title: title,
    subjectId: 'subject-1',
    gradeId: 'grade-1',
    academicYear: '2024-2025',
    createdBy: 'user-1',
    createdAt: DateTime(2024, 1, 1),
    modifiedAt: DateTime(2024, 1, 1),
    status: status,
    examType: ExamType.monthlyTest,
    paperSections: [
      PaperSectionEntity(name: 'Section A', type: 'multiple_choice', questions: 2, marksPerQuestion: 2),
    ],
    questions: {
      'Section A': [
        Question(text: 'What is 2+2?', type: 'multiple_choice', options: ['2', '3', '4', '5'], correctAnswer: '4', marks: 2),
        Question(text: 'What is 3+3?', type: 'multiple_choice', options: ['4', '5', '6', '7'], correctAnswer: '6', marks: 2),
      ],
    },
    userId: userId,
    tenantId: tenantId,
    rejectionReason: rejectionReason,
  );
}
