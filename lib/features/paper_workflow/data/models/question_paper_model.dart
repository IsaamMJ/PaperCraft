// features/question_papers/data/models/question_paper_model.dart
import 'dart:convert';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/question_paper_entity.dart';
import '../../../catalog/domain/entities/paper_section_entity.dart';
import '../../../catalog/domain/entities/exam_type.dart';
import '../../domain/entities/paper_status.dart';

class QuestionPaperModel extends QuestionPaperEntity {
  const QuestionPaperModel({
    required super.id,
    required super.title,
    required super.subjectId,
    required super.gradeId,
    required super.academicYear,
    required super.createdBy,
    required super.createdAt,
    required super.modifiedAt,
    required super.status,
    required super.paperSections,
    required super.questions,
    required super.examType,
    super.examDate,
    super.examNumber,
    super.subject,
    super.grade,
    super.gradeLevel,
    super.selectedSections,
    super.tenantId,
    super.userId,
    super.submittedAt,
    super.reviewedAt,
    super.reviewedBy,
    super.rejectionReason,
    super.examTimetableEntryId,
    super.section,
  });

  factory QuestionPaperModel.fromEntity(QuestionPaperEntity entity) {
    return QuestionPaperModel(
      id: entity.id,
      title: entity.title,
      subjectId: entity.subjectId,
      gradeId: entity.gradeId,
      academicYear: entity.academicYear,
      createdBy: entity.createdBy,
      createdAt: entity.createdAt,
      modifiedAt: entity.modifiedAt,
      status: entity.status,
      paperSections: entity.paperSections,
      questions: entity.questions,
      examType: entity.examType,
      examDate: entity.examDate,
      examNumber: entity.examNumber,
      subject: entity.subject,
      grade: entity.grade,
      gradeLevel: entity.gradeLevel,
      selectedSections: entity.selectedSections,
      tenantId: entity.tenantId,
      userId: entity.userId,
      submittedAt: entity.submittedAt,
      reviewedAt: entity.reviewedAt,
      reviewedBy: entity.reviewedBy,
      rejectionReason: entity.rejectionReason,
      examTimetableEntryId: entity.examTimetableEntryId,
      section: entity.section,
    );
  }

  QuestionPaperEntity toEntity() => this;

  /// Parse from Supabase response (enriched view with joins)
  factory QuestionPaperModel.fromSupabase(Map<String, dynamic> json) {
    try {
      // Parse questions JSONB
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

      // Parse paper sections from JSONB
      List<PaperSectionEntity> paperSections = [];
      if (json['paper_sections'] != null && json['paper_sections'] is List) {
        paperSections = (json['paper_sections'] as List<dynamic>)
            .map((section) => PaperSectionEntity.fromJson(section as Map<String, dynamic>))
            .toList();
      }

      // Extract display fields from joined columns or nested relationships
      // Support both flat fields (legacy) and nested objects (from joins)
      String? subjectName = json['subject_name'] as String?;
      if (subjectName == null && json['subjects'] is Map) {
        // Extract from nested subjects relationship: subjects.subject_catalog.subject_name
        final subjectsData = json['subjects'] as Map<String, dynamic>?;
        if (subjectsData != null && subjectsData['subject_catalog'] is Map) {
          final catalogData = subjectsData['subject_catalog'] as Map<String, dynamic>;
          subjectName = catalogData['subject_name'] as String?;
        }
      }

      String? gradeName = json['grade_name'] as String?;
      int? gradeLevel = json['grade_level'] as int?;
      if (gradeName == null && gradeLevel == null && json['grades'] is Map) {
        // Extract from nested grades relationship
        final gradesData = json['grades'] as Map<String, dynamic>?;
        if (gradesData != null) {
          gradeLevel = gradesData['grade_number'] as int?;
        }
      }

      // Parse selected sections if exists
      List<String>? selectedSections;
      if (json['metadata'] != null && json['metadata']['selected_sections'] != null) {
        selectedSections = List<String>.from(json['metadata']['selected_sections'] as List);
      }

      return QuestionPaperModel(
        id: json['id'] as String,
        title: json['title'] as String,
        subjectId: json['subject_id'] as String,
        gradeId: json['grade_id'] as String,
        academicYear: json['academic_year'] as String,
        createdBy: json['user_id'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        modifiedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : DateTime.parse(json['created_at'] as String),
        status: PaperStatus.fromString(json['status'] as String),
        paperSections: paperSections,
        questions: questionsMap,
        examType: json['exam_type'] != null
            ? ExamType.fromJson(json['exam_type'] as String)
            : ExamType.monthlyTest, // Default fallback
        examDate: json['exam_date'] != null
            ? DateTime.parse(json['exam_date'] as String)
            : null,
        examNumber: json['exam_number'] as int?,
        subject: subjectName,
        grade: gradeName,
        gradeLevel: gradeLevel,
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
      throw FormatException('Failed to parse QuestionPaperModel from Supabase: $e');
    }
  }

  /// Convert to Supabase format for INSERT/UPDATE
  Map<String, dynamic> toSupabaseMap() {
    // Validate UUID fields before serialization
    if (id.isEmpty) {
      throw ArgumentError('Paper ID cannot be empty');
    }
    if (tenantId == null || tenantId!.isEmpty) {
      throw ArgumentError('Tenant ID cannot be null or empty');
    }
    if (userId == null || userId!.isEmpty) {
      throw ArgumentError('User ID cannot be null or empty');
    }
    if (subjectId.isEmpty) {
      throw ArgumentError('Subject ID cannot be empty');
    }
    if (gradeId.isEmpty) {
      throw ArgumentError('Grade ID cannot be empty');
    }
    if (paperSections.isEmpty) {
      throw ArgumentError('Paper sections cannot be empty');
    }
    if (reviewedBy != null && reviewedBy!.isEmpty) {
      throw ArgumentError('Reviewed By cannot be empty string (use null instead)');
    }

    // Convert questions to JSON
    final Map<String, dynamic> questionsJson = {};
    questions.forEach((sectionName, questionsList) {
      questionsJson[sectionName] = questionsList.map((q) => q.toJson()).toList();
    });

    // Store selected sections in metadata
    final Map<String, dynamic> metadata = {};

    if (selectedSections != null) {
      metadata['selected_sections'] = selectedSections;
    }

    final Map<String, dynamic> map = {
      'id': id,
      'tenant_id': tenantId,
      'user_id': userId,
      'subject_id': subjectId,
      'grade_id': gradeId,
      'academic_year': academicYear,
      'title': title,
      'exam_type': examType.toJson(),
      'exam_number': examNumber,
      'exam_date': examDate?.toIso8601String(),
      'paper_sections': paperSections.map((s) => s.toJson()).toList(),
      'questions': questionsJson,
      'metadata': metadata.isNotEmpty ? metadata : null,
      'status': status.value,
      'submitted_at': submittedAt?.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': (reviewedBy != null && reviewedBy!.isNotEmpty) ? reviewedBy : null,
      'rejection_reason': rejectionReason,
    };

    return map;
  }

  /// Convert to Hive format for local storage
  Map<String, dynamic> toHiveMap() {
    // Serialize questions map to JSON string
    final Map<String, dynamic> questionsJson = {};
    questions.forEach((sectionName, questionsList) {
      questionsJson[sectionName] = questionsList.map((q) => q.toJson()).toList();
    });

    return {
      'id': id,
      'title': title,
      'subject_id': subjectId,
      'grade_id': gradeId,
      'academic_year': academicYear,
      'created_by': createdBy,
      'created_at': createdAt.millisecondsSinceEpoch,
      'modified_at': modifiedAt.millisecondsSinceEpoch,
      'status': status.value,
      'paper_sections': jsonEncode(paperSections.map((s) => s.toJson()).toList()),
      'questions': jsonEncode(questionsJson),
      'exam_type': examType.toJson(),
      'exam_number': examNumber,
      'exam_date': examDate?.millisecondsSinceEpoch,
      'subject': subject,
      'grade': grade,
      'grade_level': gradeLevel,
      'selected_sections': selectedSections != null ? jsonEncode(selectedSections) : null,
      'tenant_id': tenantId,
      'user_id': userId,
      'submitted_at': submittedAt?.millisecondsSinceEpoch,
      'reviewed_at': reviewedAt?.millisecondsSinceEpoch,
      'reviewed_by': reviewedBy,
      'rejection_reason': rejectionReason,
    };
  }

  /// Parse from Hive storage
  factory QuestionPaperModel.fromHive(Map<String, dynamic> paperMap) {
    try {
      // Parse paper sections from JSON string
      List<PaperSectionEntity> paperSections = [];
      if (paperMap['paper_sections'] != null) {
        final sectionsJson = jsonDecode(paperMap['paper_sections'] as String) as List<dynamic>;
        paperSections = sectionsJson
            .map((section) => PaperSectionEntity.fromJson(section as Map<String, dynamic>))
            .toList();
      }

      // Parse questions from JSON string
      Map<String, List<Question>> questionsMap = {};
      if (paperMap['questions'] != null) {
        final questionsJson = jsonDecode(paperMap['questions'] as String) as Map<String, dynamic>;
        questionsJson.forEach((sectionName, questionsList) {
          if (questionsList is List) {
            questionsMap[sectionName] = questionsList
                .map((q) => Question.fromJson(q as Map<String, dynamic>))
                .toList();
          }
        });
      }

      // Parse selected sections if exists
      List<String>? selectedSections;
      if (paperMap['selected_sections'] != null) {
        selectedSections = List<String>.from(jsonDecode(paperMap['selected_sections'] as String));
      }

      return QuestionPaperModel(
        id: paperMap['id'] as String,
        title: paperMap['title'] as String,
        subjectId: paperMap['subject_id'] as String,
        gradeId: paperMap['grade_id'] as String,
        academicYear: paperMap['academic_year'] as String,
        createdBy: paperMap['created_by'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(paperMap['created_at'] as int),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(paperMap['modified_at'] as int),
        status: PaperStatus.fromString(paperMap['status'] as String),
        paperSections: paperSections,
        questions: questionsMap,
        examType: paperMap['exam_type'] != null
            ? ExamType.fromJson(paperMap['exam_type'] as String)
            : ExamType.monthlyTest,
        examDate: paperMap['exam_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(paperMap['exam_date'] as int)
            : null,
        examNumber: paperMap['exam_number'] as int?,
        subject: paperMap['subject'] as String?,
        grade: paperMap['grade'] as String?,
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

  @override
  QuestionPaperModel copyWith({
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
    return QuestionPaperModel(
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
}