// test/features/admin/presentation/pages/admin_dashboard_page_test_mocks.dart

import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/material.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/features/authentication/domain/services/user_state_service.dart';
import 'package:papercraft/features/catalog/domain/entities/exam_type.dart';
import 'package:papercraft/features/catalog/domain/entities/paper_section_entity.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/paper_status.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/question_entity.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/question_paper_entity.dart';
import 'package:papercraft/features/paper_workflow/domain/services/user_info_service.dart';
import 'package:papercraft/features/paper_workflow/presentation/bloc/question_paper_bloc.dart';


// Mock BLoC
class MockQuestionPaperBloc extends MockBloc<QuestionPaperEvent, QuestionPaperState>
    implements QuestionPaperBloc {}

// Mock Services
class MockUserStateService extends Mock implements UserStateService {}
class MockUserInfoService extends Mock implements UserInfoService {}
class MockNavigatorObserver extends Mock implements NavigatorObserver {}
class MockILogger extends Mock implements ILogger {}

// Fake classes for registerFallbackValue
class FakeQuestionPaperEvent extends Fake implements QuestionPaperEvent {}
class FakeQuestionPaperState extends Fake implements QuestionPaperState {}
class FakeRoute extends Fake implements Route<dynamic> {}

// Test Data Factory
class TestDataFactory {
  static QuestionPaperEntity createPaper({
    String id = 'paper-1',
    String title = 'Mathematics Test',
    String? subject = 'Mathematics',
    String createdBy = 'user-123',
    DateTime? createdAt,
    PaperStatus status = PaperStatus.submitted,
    int totalQuestions = 10,
    int totalMarks = 50,
  }) {
    return QuestionPaperEntity(
      id: id,
      title: title,
      subjectId: 'subject-1',
      gradeId: 'grade-1',
      academicYear: '2024-2025',
      createdBy: createdBy,
      createdAt: createdAt ?? DateTime(2024, 3, 15),
      modifiedAt: createdAt ?? DateTime(2024, 3, 15),
      status: status,
      paperSections: [
        PaperSectionEntity(
          name: 'Section A',
          type: 'multiple_choice',
          questions: totalQuestions,
          marksPerQuestion: (totalMarks / totalQuestions).round(),
        ),
      ],
      questions: {
        'Section A': List.generate(
          totalQuestions,
              (i) => Question(
            text: 'Question ${i + 1}',
            type: 'multiple_choice',
            marks: (totalMarks / totalQuestions).round(),
            options: ['A', 'B', 'C', 'D'],
            correctAnswer: 'A',
          ),
        ),
      },
      examType: ExamType.monthlyTest,
      subject: subject,
      grade: 'Grade 10',
      gradeLevel: 10,
    );
  }

  static List<QuestionPaperEntity> createPaperList({
    int count = 5,
    PaperStatus? status,
  }) {
    return List.generate(
      count,
          (i) => createPaper(
        id: 'paper-$i',
        title: 'Test Paper $i',
        subject: ['Mathematics', 'Physics', 'Chemistry'][i % 3],
        createdBy: 'user-${i % 3}',
        status: status ?? PaperStatus.submitted,
        totalQuestions: 10 + i,
        totalMarks: 50 + (i * 10),
      ),
    );
  }

  static List<QuestionPaperEntity> createMixedStatusPapers() {
    return [
      createPaper(
        id: 'paper-1',
        title: 'Submitted Paper',
        status: PaperStatus.submitted,
      ),
      createPaper(
        id: 'paper-2',
        title: 'Approved Paper',
        status: PaperStatus.approved,
      ),
      createPaper(
        id: 'paper-3',
        title: 'Rejected Paper',
        status: PaperStatus.rejected,
      ),
      createPaper(
        id: 'paper-4',
        title: 'Draft Paper',
        status: PaperStatus.draft,
      ),
    ];
  }
}