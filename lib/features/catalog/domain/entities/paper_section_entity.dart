// features/catalog/domain/entities/paper_section_entity.dart
import 'package:equatable/equatable.dart';

/// Represents a section within a question paper
/// Each section has a type, number of questions, and marks per question
class PaperSectionEntity extends Equatable {
  final String name;
  final String type; // multiple_choice, short_answer, fill_blanks, true_false, match_following
  final int questions;
  final int marksPerQuestion;

  const PaperSectionEntity({
    required this.name,
    required this.type,
    required this.questions,
    required this.marksPerQuestion,
  });

  /// Total marks for this section
  int get totalMarks => questions * marksPerQuestion;

  /// Human-readable type name
  String get typeDisplayName {
    switch (type) {
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'short_answer':
        return 'Short Answer';
      case 'fill_in_blanks':
      case 'fill_blanks': // Support legacy type
        return 'Fill in the Blanks';
      case 'true_false':
        return 'True/False';
      case 'match_following':
        return 'Match the Following';
      default:
        return type;
    }
  }

  /// Summary string for display (e.g., "10 × 2 marks")
  String get summary => '$questions × $marksPerQuestion mark${marksPerQuestion > 1 ? 's' : ''}';

  /// Full summary with total (e.g., "10 × 2 = 20 marks")
  String get fullSummary => '$summary = $totalMarks mark${totalMarks > 1 ? 's' : ''}';

  /// Create from JSON
  factory PaperSectionEntity.fromJson(Map<String, dynamic> json) {
    return PaperSectionEntity(
      name: json['name'] as String,
      type: json['type'] as String,
      questions: json['questions'] as int,
      marksPerQuestion: json['marks_per_question'] as int,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'questions': questions,
      'marks_per_question': marksPerQuestion,
    };
  }

  /// Create a copy with modified fields
  PaperSectionEntity copyWith({
    String? name,
    String? type,
    int? questions,
    int? marksPerQuestion,
  }) {
    return PaperSectionEntity(
      name: name ?? this.name,
      type: type ?? this.type,
      questions: questions ?? this.questions,
      marksPerQuestion: marksPerQuestion ?? this.marksPerQuestion,
    );
  }

  @override
  List<Object?> get props => [name, type, questions, marksPerQuestion];

  @override
  String toString() => '$name: $fullSummary ($typeDisplayName)';
}
