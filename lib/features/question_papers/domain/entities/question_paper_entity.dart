// features/question_papers/domain/entities/question_paper_entity.dart
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';
import 'paper_status.dart';
import 'exam_type_entity.dart';
import 'question_entity.dart';

class QuestionPaperEntity extends Equatable {
  final String id;
  final String title;
  final String subject;
  final String examType;
  final String createdBy;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final PaperStatus status;
  final ExamTypeEntity examTypeEntity;
  final Map<String, List<Question>> questions;

  // Cloud-specific fields (null for local drafts)
  final String? tenantId;
  final String? userId;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;

  const QuestionPaperEntity({
    required this.id,
    required this.title,
    required this.subject,
    required this.examType,
    required this.createdBy,
    required this.createdAt,
    required this.modifiedAt,
    required this.status,
    required this.examTypeEntity,
    required this.questions,
    this.tenantId,
    this.userId,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
  });

  // Factory constructor for creating new drafts
  factory QuestionPaperEntity.createDraft({
    required String title,
    required String subject,
    required String examType,
    required String createdBy,
    required ExamTypeEntity examTypeEntity,
    Map<String, List<Question>>? questions,
  }) {
    return QuestionPaperEntity(
      id: const Uuid().v4(),
      title: title,
      subject: subject,
      examType: examType,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      status: PaperStatus.draft,
      examTypeEntity: examTypeEntity,
      questions: questions ?? {},
    );
  }

  // Business logic methods
  bool get canEdit {
    return status.isDraft || status.isRejected;
  }

  bool get canSubmit {
    return status.isDraft && isComplete && hasValidQuestions;
  }

  bool get canApprove {
    return status.isSubmitted;
  }

  bool get canReject {
    return status.isSubmitted;
  }

  bool get canPullForEditing {
    return status.isRejected;
  }

  bool get isLocal {
    return tenantId == null || userId == null;
  }

  bool get isCloud {
    return !isLocal;
  }

  bool get isComplete {
    return title.trim().isNotEmpty &&
        questions.isNotEmpty &&
        _hasValidQuestions() &&
        _meetsMinimumQuestionRequirements();
  }

  bool get hasValidQuestions {
    return questions.values.every((questionList) =>
        questionList.every((question) => question.isValid));
  }

  bool _hasValidQuestions() {
    return questions.values.any((questionList) => questionList.isNotEmpty);
  }

  bool _meetsMinimumQuestionRequirements() {
    // Check if each section has the minimum required questions
    for (var section in examTypeEntity.sections) {
      final sectionQuestions = questions[section.name] ?? [];
      final mandatoryQuestions = sectionQuestions.where((q) => !q.isOptional).length;

      if (mandatoryQuestions < section.questions) {
        return false;
      }
    }
    return true;
  }

  int get totalQuestions {
    return questions.values.fold(0, (sum, questionList) => sum + questionList.length);
  }

  int get totalMarks {
    int total = 0;
    for (var section in examTypeEntity.sections) {
      final sectionQuestions = questions[section.name] ?? [];
      for (var question in sectionQuestions) {
        total += question.totalMarks;
      }
    }
    return total;
  }

  String get completionSummary {
    final sections = examTypeEntity.sections;
    final List<String> sectionSummaries = [];

    for (var section in sections) {
      final sectionQuestions = questions[section.name] ?? [];
      final mandatoryCount = sectionQuestions.where((q) => !q.isOptional).length;
      final optionalCount = sectionQuestions.where((q) => q.isOptional).length;
      final required = section.questions;

      String summary = '${section.name}: $mandatoryCount/$required';
      if (optionalCount > 0) {
        summary += ' (+$optionalCount optional)';
      }
      sectionSummaries.add(summary);
    }

    return sectionSummaries.join(', ');
  }

  // Status validation for transitions
  bool canTransitionTo(PaperStatus newStatus) {
    return status.canTransitionTo(newStatus);
  }

  // Create a draft copy (for pulling rejected papers back to edit)
  QuestionPaperEntity createDraftCopy() {
    return QuestionPaperEntity(
      id: const Uuid().v4(), // New UUID for new draft
      title: title,
      subject: subject,
      examType: examType,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      status: PaperStatus.draft,
      examTypeEntity: examTypeEntity,
      questions: Map.from(questions), // Deep copy
      rejectionReason: rejectionReason, // Keep for reference
    );
  }

  // Create cloud version for submission
  QuestionPaperEntity createCloudVersion({
    required String tenantId,
    required String userId,
  }) {
    if (!canSubmit) {
      throw StateError('Paper cannot be submitted: not complete or has invalid questions');
    }

    return copyWith(
      status: PaperStatus.submitted,
      tenantId: tenantId,
      userId: userId,
      submittedAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
  }

  // Validation errors for debugging
  List<String> get validationErrors {
    final errors = <String>[];

    if (title.trim().isEmpty) {
      errors.add('Title is required');
    }

    if (questions.isEmpty) {
      errors.add('At least one question is required');
    }

    // Check each section requirements
    for (var section in examTypeEntity.sections) {
      final sectionQuestions = questions[section.name] ?? [];
      final mandatoryQuestions = sectionQuestions.where((q) => !q.isOptional).length;

      if (mandatoryQuestions < section.questions) {
        errors.add('${section.name} needs ${section.questions - mandatoryQuestions} more questions');
      }

      // Check question validity
      for (var i = 0; i < sectionQuestions.length; i++) {
        final question = sectionQuestions[i];
        if (!question.isValid) {
          errors.add('${section.name} Question ${i + 1}: ${question.validationError}');
        }
      }
    }

    return errors;
  }

  QuestionPaperEntity copyWith({
    String? id,
    String? title,
    String? subject,
    String? examType,
    String? createdBy,
    DateTime? createdAt,
    DateTime? modifiedAt,
    PaperStatus? status,
    ExamTypeEntity? examTypeEntity,
    Map<String, List<Question>>? questions,
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
      subject: subject ?? this.subject,
      examType: examType ?? this.examType,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      status: status ?? this.status,
      examTypeEntity: examTypeEntity ?? this.examTypeEntity,
      questions: questions ?? this.questions,
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
    id, title, subject, examType, createdBy, createdAt, modifiedAt,
    status, examTypeEntity, questions, tenantId, userId, submittedAt,
    reviewedAt, reviewedBy, rejectionReason,
  ];
}