import 'package:equatable/equatable.dart';

class ExamTypeEntity extends Equatable {
  final String id;
  final String tenantId;
  final String name;
  final int? durationMinutes;
  final int? totalMarks;
  final int? totalQuestions;
  final List<ExamSectionEntity> sections;

  const ExamTypeEntity({
    required this.id,
    required this.tenantId,
    required this.name,
    this.durationMinutes,
    this.totalMarks,
    this.totalQuestions,
    this.sections = const [],
  });

  // Helper method to get formatted duration
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

  // Calculate total marks based on questions to answer (not questions provided)
  int get calculatedTotalMarks {
    return sections.fold(0, (total, section) => total + section.totalMarksForExam);
  }

  factory ExamTypeEntity.fromJson(Map<String, dynamic> json) {
    return ExamTypeEntity(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      durationMinutes: json['duration_minutes'] as int?,
      totalMarks: json['total_marks'] as int?,
      totalQuestions: json['total_questions'] as int?,
      sections: (json['sections'] as List<dynamic>?)
          ?.map((section) => ExamSectionEntity.fromJson(section as Map<String, dynamic>))
          .toList() ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'duration_minutes': durationMinutes,
      'total_marks': totalMarks,
      'total_questions': totalQuestions,
      'sections': sections.map((section) => section.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [id, tenantId, name, durationMinutes, totalMarks, totalQuestions, sections];
}

class ExamSectionEntity extends Equatable {
  final String name;
  final String type;
  final int questions; // Total questions provided by teacher
  final int marksPerQuestion;
  final int? questionsToAnswer; // Questions student needs to answer (null = answer all)

  const ExamSectionEntity({
    required this.name,
    required this.type,
    required this.questions,
    required this.marksPerQuestion,
    this.questionsToAnswer, // Optional field
  });

  // Total marks if all questions were answered (for teacher reference)
  int get totalMarks => questions * marksPerQuestion;

  // Total marks for the actual exam (based on questions to answer)
  int get totalMarksForExam => (questionsToAnswer ?? questions) * marksPerQuestion;

  // Questions student needs to answer
  int get questionsForExam => questionsToAnswer ?? questions;

  // Whether this section has optional questions
  bool get hasOptionalQuestions => questionsToAnswer != null && questionsToAnswer! < questions;

  // Helper text for displaying question requirements
  String get questionRequirement {
    if (hasOptionalQuestions) {
      return 'Answer $questionsForExam out of $questions questions';
    }
    return 'Answer all $questions questions';
  }

  // Helper method to get formatted question type
  String get formattedType {
    switch (type) {
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'fill_blanks':
        return 'Fill in Blanks';
      case 'matching':
        return 'Match the Following';
      case 'short_answer':
        return 'Short Answer';
      case 'true_false':
        return 'True/False';
      default:
        return type;
    }
  }

  factory ExamSectionEntity.fromJson(Map<String, dynamic> json) {
    return ExamSectionEntity(
      name: json['name'] as String,
      type: json['type'] as String,
      questions: json['questions'] as int,
      marksPerQuestion: json['marks_per_question'] as int,
      questionsToAnswer: json['questions_to_answer'] as int?, // New field
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'questions': questions,
      'marks_per_question': marksPerQuestion,
      'questions_to_answer': questionsToAnswer, // New field
    };
  }

  // Helper method to create a copy with different values
  ExamSectionEntity copyWith({
    String? name,
    String? type,
    int? questions,
    int? marksPerQuestion,
    int? questionsToAnswer,
  }) {
    return ExamSectionEntity(
      name: name ?? this.name,
      type: type ?? this.type,
      questions: questions ?? this.questions,
      marksPerQuestion: marksPerQuestion ?? this.marksPerQuestion,
      questionsToAnswer: questionsToAnswer ?? this.questionsToAnswer,
    );
  }

  @override
  List<Object?> get props => [name, type, questions, marksPerQuestion, questionsToAnswer];
}