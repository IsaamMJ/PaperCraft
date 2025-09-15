// features/question_papers/data/models/question_paper_model.dart
import 'dart:convert';
import '../../domain/entities/paper_status.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/question_paper_entity.dart';

class QuestionPaperModel {
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

  QuestionPaperModel({
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

  // Convert to domain entity
  QuestionPaperEntity toEntity() {
    return QuestionPaperEntity(
      id: id,
      title: title,
      subject: subject,
      examType: examType,
      createdBy: createdBy,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      status: status,
      examTypeEntity: examTypeEntity,
      questions: questions,
      tenantId: tenantId,
      userId: userId,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt,
      reviewedBy: reviewedBy,
      rejectionReason: rejectionReason,
    );
  }

  // Create from domain entity
  factory QuestionPaperModel.fromEntity(QuestionPaperEntity entity) {
    return QuestionPaperModel(
      id: entity.id,
      title: entity.title,
      subject: entity.subject,
      examType: entity.examType,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
      modifiedAt: entity.modifiedAt,
      status: entity.status,
      examTypeEntity: entity.examTypeEntity,
      questions: entity.questions,
      tenantId: entity.tenantId,
      userId: entity.userId,
      submittedAt: entity.submittedAt,
      reviewedAt: entity.reviewedAt,
      reviewedBy: entity.reviewedBy,
      rejectionReason: entity.rejectionReason,
    );
  }

  // JSON serialization for local storage (SharedPreferences)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'examType': examType,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'status': status.value,
      'examTypeEntity': examTypeEntity.toJson(),
      'questions': questions.map((key, value) => MapEntry(
        key,
        value.map((q) => q.toJson()).toList(),
      )),
      // Cloud fields (usually null for drafts)
      'tenantId': tenantId,
      'userId': userId,
      'submittedAt': submittedAt?.toIso8601String(),
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
      'rejectionReason': rejectionReason,
    };
  }

  // JSON deserialization for local storage (SharedPreferences)
  factory QuestionPaperModel.fromJson(Map<String, dynamic> json) {
    // Parse questions map
    final questionsMap = <String, List<Question>>{};
    final questionsJson = json['questions'] as Map<String, dynamic>? ?? {};

    questionsJson.forEach((key, value) {
      final questionList = (value as List)
          .map((q) => Question.fromJson(q as Map<String, dynamic>))
          .toList();
      questionsMap[key] = questionList;
    });

    return QuestionPaperModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: json['subject'] as String,
      examType: json['examType'] as String,
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
      status: PaperStatus.fromString(json['status'] as String),
      examTypeEntity: ExamTypeEntity.fromJson(json['examTypeEntity'] as Map<String, dynamic>),
      questions: questionsMap,
      tenantId: json['tenantId'] as String?,
      userId: json['userId'] as String?,
      submittedAt: json['submittedAt'] != null
          ? DateTime.parse(json['submittedAt'] as String)
          : null,
      reviewedAt: json['reviewedAt'] != null
          ? DateTime.parse(json['reviewedAt'] as String)
          : null,
      reviewedBy: json['reviewedBy'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
    );
  }

  // Supabase mapping for cloud storage
  Map<String, dynamic> toSupabaseMap() {
    if (tenantId == null || userId == null) {
      throw StateError('Cannot convert draft paper to Supabase format - missing cloud fields');
    }

    return {
      'tenant_id': tenantId,
      'user_id': userId,
      'title': title,
      'subject': subject,
      'exam_type': examType,
      'questions': questions.map((key, value) =>
          MapEntry(key, value.map((q) => q.toJson()).toList())),
      'status': status.value,
      'submitted_at': submittedAt?.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
      'rejection_reason': rejectionReason,
      'metadata': {
        'exam_type_entity': examTypeEntity.toJson(),
        'created_locally_at': createdAt.toIso8601String(),
        'modified_locally_at': modifiedAt.toIso8601String(),
        'local_id': id,
        'created_by': createdBy,
      },
    };
  }

  // Create from Supabase response
  factory QuestionPaperModel.fromSupabase(Map<String, dynamic> json) {
    // Parse questions from JSONB
    final questionsJson = json['questions'] as Map<String, dynamic>? ?? {};
    final questions = <String, List<Question>>{};

    questionsJson.forEach((key, value) {
      final questionList = (value as List)
          .map((q) => Question.fromJson(q as Map<String, dynamic>))
          .toList();
      questions[key] = questionList;
    });

    // Parse metadata
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};

    // Get exam type entity from metadata or create default
    final examTypeEntity = metadata['exam_type_entity'] != null
        ? ExamTypeEntity.fromJson(metadata['exam_type_entity'] as Map<String, dynamic>)
        : ExamTypeEntity(
      id: 'unknown',
      tenantId: json['tenant_id'] as String,
      name: json['exam_type'] as String? ?? 'Unknown',
    );

    // Get local creation info from metadata
    final createdBy = metadata['created_by'] as String? ?? json['user_id'] as String;
    final createdAt = metadata['created_locally_at'] != null
        ? DateTime.parse(metadata['created_locally_at'] as String)
        : DateTime.parse(json['created_at'] as String);
    final modifiedAt = metadata['modified_locally_at'] != null
        ? DateTime.parse(metadata['modified_locally_at'] as String)
        : DateTime.parse(json['submitted_at'] as String? ?? json['created_at'] as String);

    return QuestionPaperModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: json['subject'] as String,
      examType: json['exam_type'] as String,
      createdBy: createdBy,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      status: PaperStatus.fromString(json['status'] as String),
      examTypeEntity: examTypeEntity,
      questions: questions,
      tenantId: json['tenant_id'] as String,
      userId: json['user_id'] as String,
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'] as String)
          : null,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      reviewedBy: json['reviewed_by'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  QuestionPaperModel copyWith({
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
    return QuestionPaperModel(
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
}