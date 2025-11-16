// features/paper_workflow/domain/entities/question_paper_entity.dart
import 'package:equatable/equatable.dart';
import 'question_entity.dart';
import '../../../catalog/domain/entities/paper_section_entity.dart';
import '../../../catalog/domain/entities/exam_type.dart';
import '../../../../core/domain/validators/input_validators.dart';
import 'paper_status.dart';

class QuestionPaperEntity extends Equatable {
  final String id;
  final String title;

  // UUID references to catalog tables
  final String subjectId;
  final String gradeId;
  final String academicYear;

  final String createdBy;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final PaperStatus status;
  final DateTime? examDate;

  // Dynamic paper sections (replaces examTypeEntity)
  final List<PaperSectionEntity> paperSections;
  final Map<String, List<Question>> questions;

  // Exam type fields
  final ExamType examType;  // Required: Monthly Test, Daily Test, etc.
  final int? examNumber;    // Optional: For "Daily Test - 1", "Monthly Test - 2"

  // Display-only fields (resolved from IDs via BLoC/UI layer)
  final String? subject;  // Resolved from subjectId
  final String? grade;    // Resolved from gradeId (e.g., "Grade 10")
  final int? gradeLevel;  // Numeric grade level (e.g., 10)
  final List<String>? selectedSections; // Selected sections (if applicable)

  // Cloud sync fields
  final String? tenantId;
  final String? userId;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;

  // Auto-assignment fields
  final String? examTimetableEntryId;  // Links to auto-assigned exam timetable entry
  final String? section;              // Section (e.g., "A", "B") - pre-filled for auto-assigned papers

  const QuestionPaperEntity({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.gradeId,
    required this.academicYear,
    required this.createdBy,
    required this.createdAt,
    required this.modifiedAt,
    required this.status,
    required this.paperSections,
    required this.questions,
    required this.examType,
    this.examDate,
    this.examNumber,
    this.subject,
    this.grade,
    this.gradeLevel,
    this.selectedSections,
    this.tenantId,
    this.userId,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.examTimetableEntryId,
    this.section,
  });

  // Computed properties
  bool get hasValidQuestions => questions.isNotEmpty;

  int get totalQuestions {
    return questions.values.fold(0, (sum, list) => sum + list.length);
  }

  double get totalMarks {
    double total = 0.0;

    final sectionDefMap = {for (var section in paperSections) section.name: section};

    for (final sectionName in questions.keys) {
      final sectionQuestions = questions[sectionName]!;
      final sectionDef = sectionDefMap[sectionName];

      if (sectionDef != null && sectionDef.type == 'match_following') {
        // For match_following: use section.questions (number of pairs) not question count
        final nonOptionalCount = sectionQuestions
            .where((q) => !(q.isOptional ?? false))
            .length;

        // If there are non-optional questions, calculate based on pairs count
        if (nonOptionalCount > 0) {
          total += sectionDef.marksPerQuestion * sectionDef.questions;
        }
      } else {
        for (final question in sectionQuestions) {
          if (!(question.isOptional ?? false)) {
            total += question.marks;
          }
        }
      }
    }

    return total;
  }

  bool get isComplete {
    if (questions.isEmpty) return false;
    if (title.trim().isEmpty) return false;

    for (final section in paperSections) {
      final sectionQuestions = questions[section.name] ?? [];

      // Special handling for matching questions
      // For matching: 1 question with N pairs is valid (not N separate questions)
      if (section.type == 'match_following') {
        if (sectionQuestions.isEmpty) {
          return false;
        }
      } else {
        // For other question types, count must match section.questions
        if (sectionQuestions.length < section.questions) {
          return false;
        }
      }
    }
    return true;
  }

  List<String> get validationErrors {
    final errors = <String>[];

    // Validate title using InputValidators
    final titleError = InputValidators.validatePaperTitle(title);
    if (titleError != null) errors.add(titleError);

    // Validate total marks
    if (totalMarks > InputValidators.MAX_TOTAL_MARKS) {
      errors.add('Total marks cannot exceed ${InputValidators.MAX_TOTAL_MARKS}');
    }

    if (questions.isEmpty) errors.add('At least one question required');

    // Check total question count
    int totalQuestionCount = 0;
    for (final section in questions.values) {
      totalQuestionCount += section.length;
    }
    if (totalQuestionCount > InputValidators.MAX_TOTAL_QUESTIONS) {
      errors.add('Total questions cannot exceed ${InputValidators.MAX_TOTAL_QUESTIONS}');
    }

    for (final section in paperSections) {
      final sectionQuestions = questions[section.name] ?? [];
      final required = section.questions;
      final actual = sectionQuestions.length;

      // Special handling for matching questions
      // For matching: 1 question with N pairs is valid (not N separate questions)
      if (section.type == 'match_following') {
        // For matching questions, just need at least 1 question
        if (actual < 1) {
          errors.add('Section "${section.name}" needs at least 1 matching question');
        }
      } else {
        // For other question types, count must match section.questions
        if (actual < required) {
          errors.add('Section "${section.name}" needs $required questions, has $actual');
        }
      }

      // Validate each question in the section
      for (final question in sectionQuestions) {
        final questionError = InputValidators.validateQuestionText(question.text);
        if (questionError != null) {
          errors.add('Invalid question in ${section.name}: $questionError');
        }

        final marksError = InputValidators.validateMarks(question.totalMarks);
        if (marksError != null) {
          errors.add('Invalid marks in ${section.name}: $marksError');
        }
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

  // Clean PDF title with exam type and number (for professional PDF display)
  // Example: "Daily Test - 1 - Mathematics" or "Monthly Test - Mathematics"
  String get pdfTitle {
    if (subject != null) {
      if (examNumber != null) {
        return '${examType.displayName} - $examNumber - $subject';
      }
      return '${examType.displayName} - $subject';
    }
    return title;
  }

  // Just the grade number for PDF display
  int? get gradeNumber => gradeLevel;

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
    String? academicYear,
    String? createdBy,
    DateTime? createdAt,
    DateTime? modifiedAt,
    PaperStatus? status,
    DateTime? examDate,
    List<PaperSectionEntity>? paperSections,
    Map<String, List<Question>>? questions,
    ExamType? examType,
    int? examNumber,
    String? subject,
    String? grade,
    int? gradeLevel,
    List<String>? selectedSections,
    String? tenantId,
    String? userId,
    DateTime? submittedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? rejectionReason,
    String? examTimetableEntryId,
    String? section,
  }) {
    return QuestionPaperEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      subjectId: subjectId ?? this.subjectId,
      gradeId: gradeId ?? this.gradeId,
      academicYear: academicYear ?? this.academicYear,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      status: status ?? this.status,
      examDate: examDate ?? this.examDate,
      paperSections: paperSections ?? this.paperSections,
      questions: questions ?? this.questions,
      examType: examType ?? this.examType,
      examNumber: examNumber ?? this.examNumber,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      selectedSections: selectedSections ?? this.selectedSections,
      tenantId: tenantId ?? this.tenantId,
      userId: userId ?? this.userId,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      examTimetableEntryId: examTimetableEntryId ?? this.examTimetableEntryId,
      section: section ?? this.section,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    subjectId,
    gradeId,
    academicYear,
    createdBy,
    createdAt,
    modifiedAt,
    status,
    examDate,
    paperSections,
    questions,
    examType,
    examNumber,
    subject,
    grade,
    gradeLevel,
    selectedSections,
    tenantId,
    userId,
    submittedAt,
    reviewedAt,
    reviewedBy,
    rejectionReason,
    examTimetableEntryId,
    section,
  ];
}