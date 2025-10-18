// features/question_papers/domain2/entities/question_entity.dart
import 'package:equatable/equatable.dart';
import '../../../../core/domain/validators/input_validators.dart';

class Question extends Equatable {
  final String text;
  final String type;
  final List<String>? options; // For MCQ only
  final String? correctAnswer;
  final int marks;
  final List<SubQuestion> subQuestions; // For essay/complex questions only
  final bool isOptional;

  // AI Polish tracking fields
  final String? originalText; // Original text before AI polish (for diff view)
  final List<String>? polishChanges; // List of changes made by AI

  const Question({
    required this.text,
    required this.type,
    this.options,
    this.correctAnswer,
    required this.marks,
    this.subQuestions = const [],
    this.isOptional = false,
    this.originalText,
    this.polishChanges,
  });

  // Validation: A question should have EITHER options OR subQuestions, not both
  bool get isValid {
    final hasOptions = options != null && options!.isNotEmpty;
    final hasSubQuestions = subQuestions.isNotEmpty;

    // MCQ questions should have options, not subQuestions
    if (type == 'multiple_choice') {
      return hasOptions && !hasSubQuestions && options!.length >= 2;
    }

    // Essay/complex questions can have subQuestions, but not options
    if (type == 'short_answer' || type == 'essay' || type == 'fill_blanks') {
      return !hasOptions; // subQuestions are optional for these types
    }

    return true;
  }

  // Total marks is just the main question marks (subquestions don't have separate marks)
  int get totalMarks => marks;

  String get validationError {
    // Validate question text length
    final textError = InputValidators.validateQuestionText(text);
    if (textError != null) return textError;

    // Validate marks
    final marksError = InputValidators.validateMarks(marks);
    if (marksError != null) return marksError;

    // Validate options
    if (options != null) {
      if (options!.length > InputValidators.MAX_OPTIONS_PER_QUESTION) {
        return 'Too many options (max ${InputValidators.MAX_OPTIONS_PER_QUESTION})';
      }

      for (final option in options!) {
        final optionError = InputValidators.validateOption(option);
        if (optionError != null) return optionError;
      }
    }

    // Type-specific validation
    if (!isValid) {
      if (type == 'multiple_choice') {
        if (options == null || options!.isEmpty) {
          return 'Multiple choice questions must have options';
        }
        if (options!.length < InputValidators.MIN_OPTIONS_FOR_MCQ) {
          return 'Multiple choice questions must have at least ${InputValidators.MIN_OPTIONS_FOR_MCQ} options';
        }
        if (subQuestions.isNotEmpty) {
          return 'Multiple choice questions cannot have sub-questions';
        }
      }

      if (type != 'multiple_choice' && options != null && options!.isNotEmpty) {
        return 'Non-multiple choice questions cannot have options';
      }
    }

    // Validate sub-questions
    if (subQuestions.length > InputValidators.MAX_SUB_QUESTIONS) {
      return 'Too many sub-questions (max ${InputValidators.MAX_SUB_QUESTIONS})';
    }

    return '';
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'type': type,
      'options': options,
      'correct_answer': correctAnswer,
      'marks': marks,
      'sub_questions': subQuestions.map((sq) => sq.toJson()).toList(),
      'is_optional': isOptional,
      // Note: originalText and polishChanges are not persisted to database
      // They are only used during UI flow
    };
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      text: json['text'] ?? '',
      type: json['type'] ?? 'short_answer',
      options: json['options'] != null
          ? List<String>.from(json['options'])
          : null,
      correctAnswer: json['correct_answer'],
      marks: json['marks'] ?? 1,
      subQuestions: json['sub_questions'] != null
          ? (json['sub_questions'] as List)
          .map((sq) => SubQuestion.fromJson(sq))
          .toList()
          : [],
      isOptional: json['is_optional'] ?? false,
    );
  }

  Question copyWith({
    String? text,
    String? type,
    List<String>? options,
    String? correctAnswer,
    int? marks,
    List<SubQuestion>? subQuestions,
    bool? isOptional,
    String? originalText,
    List<String>? polishChanges,
  }) {
    return Question(
      text: text ?? this.text,
      type: type ?? this.type,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      marks: marks ?? this.marks,
      subQuestions: subQuestions ?? this.subQuestions,
      isOptional: isOptional ?? this.isOptional,
      originalText: originalText ?? this.originalText,
      polishChanges: polishChanges ?? this.polishChanges,
    );
  }

  @override
  List<Object?> get props => [
    text,
    type,
    options,
    correctAnswer,
    marks,
    subQuestions,
    isOptional,
    originalText,
    polishChanges,
  ];
}

class SubQuestion extends Equatable {
  final String text;

  const SubQuestion({
    required this.text,
  });

  Map<String, dynamic> toJson() {
    return {
      'text': text,
    };
  }

  factory SubQuestion.fromJson(Map<String, dynamic> json) {
    return SubQuestion(
      text: json['text'] ?? '',
    );
  }

  SubQuestion copyWith({
    String? text,
  }) {
    return SubQuestion(
      text: text ?? this.text,
    );
  }

  @override
  List<Object?> get props => [text];
}