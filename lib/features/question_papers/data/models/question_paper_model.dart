// features/question_papers/data/models/question_paper_model.dart
import 'dart:convert';
import '../../domain/entities/question_paper_entity.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/paper_status.dart';

class QuestionPaperModel extends QuestionPaperEntity {
  const QuestionPaperModel({
    required super.id,
    required super.title,
    required super.subject,
    required super.examType,
    required super.createdBy,
    required super.createdAt,
    required super.modifiedAt,
    required super.status,
    required super.examTypeEntity,
    required super.questions,
    super.gradeLevel,
    super.selectedSections = const [],
    super.tenantId,
    super.userId,
    super.submittedAt,
    super.reviewedAt,
    super.reviewedBy,
    super.rejectionReason,
  });

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
      gradeLevel: entity.gradeLevel,
      selectedSections: entity.selectedSections,
      tenantId: entity.tenantId,
      userId: entity.userId,
      submittedAt: entity.submittedAt,
      reviewedAt: entity.reviewedAt,
      reviewedBy: entity.reviewedBy,
      rejectionReason: entity.rejectionReason,
    );
  }

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
      gradeLevel: gradeLevel,
      selectedSections: selectedSections,
      tenantId: tenantId,
      userId: userId,
      submittedAt: submittedAt,
      reviewedAt: reviewedAt,
      reviewedBy: reviewedBy,
      rejectionReason: rejectionReason,
    );
  }

  // Create from Supabase JSON response
  factory QuestionPaperModel.fromSupabase(Map<String, dynamic> json) {
    try {
      // Parse questions from JSONB
      Map<String, List<Question>> questionsMap = {};
      if (json['questions'] != null) {
        final questionsJson = json['questions'] as Map<String, dynamic>;
        questionsJson.forEach((sectionName, questionsList) {
          if (questionsList is List) {
            questionsMap[sectionName] = questionsList
                .map((q) => Question.fromJson(q as Map<String, dynamic>))
                .toList();
          }
        });
      }

      // Parse exam type entity from metadata or reconstruct
      ExamTypeEntity examTypeEntity;
      if (json['metadata'] != null && json['metadata']['exam_type_entity'] != null) {
        examTypeEntity = ExamTypeEntity.fromJson(
            json['metadata']['exam_type_entity'] as Map<String, dynamic>
        );
      } else {
        // Fallback: create a basic exam type entity
        examTypeEntity = ExamTypeEntity(
          id: 'unknown',
          tenantId: json['tenant_id'] ?? '',
          name: json['exam_type'] ?? 'Unknown',
          sections: const [],
        );
      }

      // Parse selected sections from the new column or metadata
      List<String> selectedSections = [];
      if (json['selected_sections'] != null) {
        selectedSections = List<String>.from(json['selected_sections'] as List);
      } else if (json['metadata'] != null && json['metadata']['selected_sections'] != null) {
        selectedSections = List<String>.from(json['metadata']['selected_sections'] as List);
      }

      return QuestionPaperModel(
        id: json['id'] as String,
        title: json['title'] as String,
        subject: json['subject'] as String,
        examType: json['exam_type'] as String,
        createdBy: json['user_id'] as String, // Use user_id as createdBy for cloud papers
        createdAt: DateTime.parse(json['created_at'] as String),
        modifiedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.parse(json['created_at'] as String),
        status: PaperStatus.fromString(json['status'] as String),
        examTypeEntity: examTypeEntity,
        questions: questionsMap,
        gradeLevel: json['grade_level'] as int?,
        selectedSections: selectedSections,
        tenantId: json['tenant_id'] as String?,
        userId: json['user_id'] as String?,
        submittedAt: json['submitted_at'] != null
            ? DateTime.parse(json['submitted_at'] as String)
            : null,
        reviewedAt: json['reviewed_at'] != null
            ? DateTime.parse(json['reviewed_at'] as String)
            : null,
        reviewedBy: json['reviewed_by'] as String?,
        rejectionReason: json['rejection_reason'] as String?,
      );
    } catch (e) {
      throw FormatException('Failed to parse QuestionPaperModel from Supabase JSON: $e');
    }
  }

  // Convert to Supabase format for storage
  // Convert to Supabase format for storage
  Map<String, dynamic> toSupabaseMap() {
    // Convert questions to JSON format
    Map<String, dynamic> questionsJson = {};
    questions.forEach((sectionName, questionsList) {
      questionsJson[sectionName] = questionsList.map((q) => q.toJson()).toList();
    });

    // Create metadata object
    final metadata = {
      'exam_type_entity': examTypeEntity.toJson(),
      'grade_level': gradeLevel, // Backup in metadata
      'selected_sections': selectedSections, // Backup in metadata
      'created_with_grade_section_support': true,
    };

    final map = <String, dynamic>{
      'tenant_id': tenantId,
      'user_id': userId,
      'title': title,
      'subject': subject,
      'exam_type': examType,
      'questions': questionsJson,
      'status': status.value,
      'grade_level': gradeLevel, // New dedicated column
      'selected_sections': selectedSections, // New dedicated column
      'metadata': metadata,
      'submitted_at': submittedAt?.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
      'rejection_reason': rejectionReason,
    };

    // Only include ID if it's not empty (let Supabase generate UUID if empty)
    if (id.isNotEmpty) {
      map['id'] = id;
    }

    return map;
  }

  // Convert to Hive format for local storage
  Map<String, dynamic> toHiveMap() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'exam_type': examType,
      'created_by': createdBy,
      'created_at': createdAt.millisecondsSinceEpoch,
      'modified_at': modifiedAt.millisecondsSinceEpoch,
      'status': status.value,
      'exam_type_entity': jsonEncode(examTypeEntity.toJson()),
      'grade_level': gradeLevel,
      'selected_sections': jsonEncode(selectedSections),
      'tenant_id': tenantId,
      'user_id': userId,
      'submitted_at': submittedAt?.millisecondsSinceEpoch,
      'reviewed_at': reviewedAt?.millisecondsSinceEpoch,
      'reviewed_by': reviewedBy,
      'rejection_reason': rejectionReason,
    };
  }

  // Create from Hive format
  factory QuestionPaperModel.fromHive(
      Map<String, dynamic> paperMap,
      Map<String, List<Question>> questionsMap,
      ) {
    try {
      // Parse exam type entity
      final examTypeEntityJson = jsonDecode(paperMap['exam_type_entity'] as String);
      final examTypeEntity = ExamTypeEntity.fromJson(examTypeEntityJson);

      // Parse selected sections
      List<String> selectedSections = [];
      if (paperMap['selected_sections'] != null) {
        final sectionsJson = paperMap['selected_sections'] as String;
        selectedSections = List<String>.from(jsonDecode(sectionsJson));
      }

      return QuestionPaperModel(
        id: paperMap['id'] as String,
        title: paperMap['title'] as String,
        subject: paperMap['subject'] as String,
        examType: paperMap['exam_type'] as String,
        createdBy: paperMap['created_by'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(paperMap['created_at'] as int),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(paperMap['modified_at'] as int),
        status: PaperStatus.fromString(paperMap['status'] as String),
        examTypeEntity: examTypeEntity,
        questions: questionsMap,
        gradeLevel: paperMap['grade_level'] as int?,
        selectedSections: selectedSections,
        tenantId: paperMap['tenant_id'] as String?,
        userId: paperMap['user_id'] as String?,
        submittedAt: paperMap['submitted_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(paperMap['submitted_at'] as int)
            : null,
        reviewedAt: paperMap['reviewed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(paperMap['reviewed_at'] as int)
            : null,
        reviewedBy: paperMap['reviewed_by'] as String?,
        rejectionReason: paperMap['rejection_reason'] as String?,
      );
    } catch (e) {
      throw FormatException('Failed to parse QuestionPaperModel from Hive: $e');
    }
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
    int? gradeLevel,
    List<String>? selectedSections,
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
}