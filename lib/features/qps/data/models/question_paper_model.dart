import 'dart:convert';

import 'package:papercraft/features/qps/services/question_paper_storage_service.dart';

import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../presentation/widgets/question_input_widget.dart';

class QuestionPaperModel {
  final String id;
  final String title;
  final String subject;
  final String examType;
  final String createdBy;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String status; // draft, submitted, approved, rejected
  final ExamTypeEntity examTypeEntity;
  final Map<String, List<Question>> questions;
  final List<SubjectEntity> selectedSubjects;
  final String? rejectionReason;
  final String? approvedBy;
  final DateTime? approvedAt;

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
    required this.selectedSubjects,
    this.rejectionReason,
    this.approvedBy,
    this.approvedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'examType': examType,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'status': status,
      'examTypeEntity': examTypeEntity.toJson(),
      'questions': questions.map((key, value) => MapEntry(
        key,
        value.map((q) => q.toJson()).toList(),
      )),
      'selectedSubjects': selectedSubjects.map((s) => s.toJson()).toList(),
      'rejectionReason': rejectionReason,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.toIso8601String(),
    };
  }

  factory QuestionPaperModel.fromJson(Map<String, dynamic> json) {
    return QuestionPaperModel(
      id: json['id'],
      title: json['title'],
      subject: json['subject'],
      examType: json['examType'],
      createdBy: json['createdBy'],
      createdAt: DateTime.parse(json['createdAt']),
      modifiedAt: DateTime.parse(json['modifiedAt']),
      status: json['status'],
      examTypeEntity: ExamTypeEntity.fromJson(json['examTypeEntity']),
      questions: (json['questions'] as Map<String, dynamic>).map(
            (key, value) => MapEntry(
          key,
          (value as List).map((q) => Question.fromJson(q)).toList(),
        ),
      ),
      selectedSubjects: (json['selectedSubjects'] as List)
          .map((s) => SubjectEntity.fromJson(s))
          .toList(),
      rejectionReason: json['rejectionReason'],
      approvedBy: json['approvedBy'],
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'])
          : null,
    );
  }

  QuestionPaperModel copyWith({
    String? title,
    String? subject,
    String? status,
    String? rejectionReason,
    String? approvedBy,
    DateTime? approvedAt,
    DateTime? modifiedAt,
    ExamTypeEntity? examTypeEntity,
    Map<String, List<Question>>? questions,
    List<SubjectEntity>? selectedSubjects,
  }) {
    return QuestionPaperModel(
      id: id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      examType: examType,
      createdBy: createdBy,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? DateTime.now(),
      status: status ?? this.status,
      examTypeEntity: examTypeEntity ?? this.examTypeEntity,
      questions: questions ?? this.questions,
      selectedSubjects: selectedSubjects ?? this.selectedSubjects,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }
}
