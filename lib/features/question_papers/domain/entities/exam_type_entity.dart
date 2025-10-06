// features/question_papers/domain/entities/exam_type_entity.dart
import 'package:equatable/equatable.dart';

class ExamTypeEntity extends Equatable {
  final String id;
  final String tenantId;
  final String subjectId;  // ADDED
  final String name;
  final String? description;
  final int? durationMinutes;
  final int? totalMarks;
  final int? totalSections;
  final List<ExamSectionEntity> sections;
  final bool isActive;  // ADDED

  const ExamTypeEntity({
    required this.id,
    required this.tenantId,
    required this.subjectId,  // ADDED
    required this.name,
    this.description,
    this.durationMinutes,
    this.totalMarks,
    this.totalSections,
    this.sections = const [],
    this.isActive = true,  // ADDED
  });

  String get formattedDuration {
    if (durationMinutes == null) return 'Not specified';
    final hours = durationMinutes! ~/ 60;
    final minutes = durationMinutes! % 60;
    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  int get calculatedTotalMarks {
    return sections.fold(0, (total, section) =>
    total + (section.questions * section.marksPerQuestion));
  }

  @override
  List<Object?> get props => [
    id,
    tenantId,
    subjectId,  // ADDED
    name,
    description,
    durationMinutes,
    totalMarks,
    totalSections,
    sections,
    isActive,  // ADDED
  ];
}

// ExamSectionEntity remains the same
class ExamSectionEntity extends Equatable {
  final String name;
  final String type;
  final int questions;
  final int marksPerQuestion;

  const ExamSectionEntity({
    required this.name,
    required this.type,
    required this.questions,
    required this.marksPerQuestion,
  });

  int get totalMarks => questions * marksPerQuestion;

  factory ExamSectionEntity.fromJson(Map<String, dynamic> json) {
    return ExamSectionEntity(
      name: json['name'] as String,
      type: json['type'] as String,
      questions: json['questions'] as int,
      marksPerQuestion: json['marks_per_question'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'questions': questions,
      'marks_per_question': marksPerQuestion,
    };
  }

  @override
  List<Object?> get props => [name, type, questions, marksPerQuestion];
}