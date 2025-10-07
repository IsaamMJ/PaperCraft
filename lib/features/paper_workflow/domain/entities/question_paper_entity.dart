// features/paper_workflow/domain/entities/question_paper_entity.dart
import 'package:equatable/equatable.dart';
import 'question_entity.dart';
import '../../../catalog/domain/entities/exam_type_entity.dart';
import 'paper_status.dart';

class QuestionPaperEntity extends Equatable {
  final String id;
  final String title;

  // UUID references to catalog tables
  final String subjectId;
  final String gradeId;
  final String examTypeId;
  final String academicYear;

  final String createdBy;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final PaperStatus status;
  final DateTime? examDate;

  // Rich objects for display (NOT stored in database)
  final ExamTypeEntity examTypeEntity;
  final Map<String, List<Question>> questions;

  // Display-only fields (resolved from IDs via BLoC/UI layer)
  final String? subject;  // Resolved from subjectId
  final String? grade;    // Resolved from gradeId (e.g., "Grade 10")
  final String? examType; // Resolved from examTypeId
  final int? gradeLevel;  // Numeric grade level (e.g., 10)
  final List<String>? selectedSections; // Selected sections (if applicable)

  // Cloud sync fields
  final String? tenantId;
  final String? userId;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;

  const QuestionPaperEntity({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.gradeId,
    required this.examTypeId,
    required this.academicYear,
    required this.createdBy,
    required this.createdAt,
    required this.modifiedAt,
    required this.status,
    required this.examTypeEntity,
    required this.questions,
    this.examDate,
    this.subject,
    this.grade,
    this.examType,
    this.gradeLevel,
    this.selectedSections,
    this.tenantId,
    this.userId,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
  });

  // Computed properties
  bool get hasValidQuestions => questions.isNotEmpty;

  int get totalQuestions {
    return questions.values.fold(0, (sum, list) => sum + list.length);
  }

  int get totalMarks {
    int total = 0;
    for (final sectionQuestions in questions.values) {
      for (final question in sectionQuestions) {
        total += question.totalMarks;
      }
    }
    return total;
  }

  bool get isComplete {
    if (questions.isEmpty) return false;
    if (title.trim().isEmpty) return false;

    for (final section in examTypeEntity.sections) {
      final sectionQuestions = questions[section.name] ?? [];
      if (sectionQuestions.length < section.questions) {
        return false;
      }
    }
    return true;
  }

  List<String> get validationErrors {
    final errors = <String>[];
    if (title.trim().isEmpty) errors.add('Title is required');
    if (questions.isEmpty) errors.add('At least one question required');

    for (final section in examTypeEntity.sections) {
      final sectionQuestions = questions[section.name] ?? [];
      final required = section.questions;
      final actual = sectionQuestions.length;

      if (actual < required) {
        errors.add('Section "${section.name}" needs $required questions, has $actual');
      }
    }
    return errors;
  }

  bool get canSubmit => status.isDraft && isComplete;
  bool get canEdit => status.isDraft;

  // Display properties with fallbacks
  String get gradeDisplayName {
    if (grade != null) return grade!;
    if (gradeLevel != null) return 'Grade $gradeLevel';
    return 'Unknown Grade';
  }

  String get sectionsDisplayName {
    if (selectedSections != null && selectedSections!.isNotEmpty) {
      return selectedSections!.join(', ');
    }
    return 'All Sections';
  }

  String get gradeAndSectionsDisplay {
    final gradeText = gradeDisplayName;
    final sectionsText = sectionsDisplayName;
    if (sectionsText == 'All Sections') {
      return gradeText;
    }
    return '$gradeText - $sectionsText';
  }

  QuestionPaperEntity copyWith({
    String? id,
    String? title,
    String? subjectId,
    String? gradeId,
    String? examTypeId,
    String? academicYear,
    String? createdBy,
    DateTime? createdAt,
    DateTime? modifiedAt,
    PaperStatus? status,
    DateTime? examDate,
    ExamTypeEntity? examTypeEntity,
    Map<String, List<Question>>? questions,
    String? subject,
    String? grade,
    String? examType,
    int? gradeLevel,
    List<String>? selectedSections,
    String? tenantId,
    String? userId,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? rejectionReason,
  }) {
    return QuestionPaperEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      subjectId: subjectId ?? this.subjectId,
      gradeId: gradeId ?? this.gradeId,
      examTypeId: examTypeId ?? this.examTypeId,
      academicYear: academicYear ?? this.academicYear,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      status: status ?? this.status,
      examDate: examDate ?? this.examDate,
      examTypeEntity: examTypeEntity ?? this.examTypeEntity,
      questions: questions ?? this.questions,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      examType: examType ?? this.examType,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      selectedSections: selectedSections ?? this.selectedSections,
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    subjectId,
    gradeId,
    examTypeId,
    academicYear,
    createdBy,
    createdAt,
    modifiedAt,
    status,
    examDate,
    examTypeEntity,
    questions,
    subject,
    grade,
    examType,
    gradeLevel,
    selectedSections,
    tenantId,
    userId,
    submittedAt,
    reviewedAt,
    reviewedBy,
    rejectionReason,
  ];
}