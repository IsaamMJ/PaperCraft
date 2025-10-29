// features/catalog/domain/entities/paper_section_entity.dart
import 'package:equatable/equatable.dart';

/// Represents a section within a question paper
/// Each section has a type, number of questions, and marks per question
class PaperSectionEntity extends Equatable {
  final String name;
  final String type; // multiple_choice, short_answer, fill_blanks, true_false, match_following
  final int questions;
  final double marksPerQuestion;
  final bool useSharedWordBank; // For fill_blanks: true = shared, false = individual per question
  final List<String> sharedWordBank; // Shared word bank (only used if useSharedWordBank is true)

  const PaperSectionEntity({
    required this.name,
    required this.type,
    required this.questions,
    required this.marksPerQuestion,
    this.useSharedWordBank = false,
    this.sharedWordBank = const [],
  });

  /// Total marks for this section
  double get totalMarks => questions * marksPerQuestion;

  /// Human-readable type name
  String get typeDisplayName {
    switch (type) {
      case 'multiple_choice':
        return 'Multiple Choice';
      case 'short_answer':
        return 'Short Answer';
      case 'fill_in_blanks':
      case 'fill_blanks': // Support legacy type
        return 'Fill in the blanks';
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
      marksPerQuestion: (json['marks_per_question'] as num).toDouble(),
      useSharedWordBank: json['use_shared_word_bank'] as bool? ?? false,
      sharedWordBank: json['shared_word_bank'] != null
          ? List<String>.from(json['shared_word_bank'] as List)
          : const [],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'questions': questions,
      'marks_per_question': marksPerQuestion,
      'use_shared_word_bank': useSharedWordBank,
      'shared_word_bank': sharedWordBank,
    };
  }

  /// Create a copy with modified fields
  PaperSectionEntity copyWith({
    String? name,
    String? type,
    int? questions,
    double? marksPerQuestion,
    bool? useSharedWordBank,
    List<String>? sharedWordBank,
  }) {
    return PaperSectionEntity(
      name: name ?? this.name,
      type: type ?? this.type,
      questions: questions ?? this.questions,
      marksPerQuestion: marksPerQuestion ?? this.marksPerQuestion,
      useSharedWordBank: useSharedWordBank ?? this.useSharedWordBank,
      sharedWordBank: sharedWordBank ?? this.sharedWordBank,
    );
  }

  @override
  List<Object?> get props => [name, type, questions, marksPerQuestion, useSharedWordBank, sharedWordBank];

  @override
  String toString() => '$name: $fullSummary ($typeDisplayName)';
}
