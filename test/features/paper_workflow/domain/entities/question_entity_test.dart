// test/features/paper_workflow/domain/entities/question_entity_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/features/paper_workflow/domain/entities/question_entity.dart';

/// Testing the Question entity
/// This tests the business logic and validation rules we implemented

void main() {
  // Group 1: Testing MCQ (Multiple Choice Questions) validation
  group('MCQ Question validation', () {

    test('MCQ is valid with at least 2 options', () {
      // Create a valid MCQ question
      final question = Question(
        text: 'What is 2+2?',
        type: 'multiple_choice',
        options: ['3', '4', '5', '6'], // 4 options
        marks: 1,
      );

      // Check if it's valid
      expect(question.isValid, isTrue);
      expect(question.validationError, isEmpty);
    });

    test('MCQ is invalid with only 1 option', () {
      // This tests the bug fix - MCQ must have at least 2 options
      final question = Question(
        text: 'What is the capital of France?',
        type: 'multiple_choice',
        options: ['Paris'], // Only 1 option - should be invalid!
        marks: 1,
      );

      expect(question.isValid, isFalse);
      expect(question.validationError, isNotEmpty);
      expect(question.validationError, contains('at least'));
    });

    test('MCQ is invalid with no options', () {
      final question = Question(
        text: 'Question without options',
        type: 'multiple_choice',
        options: [], // Empty options list
        marks: 1,
      );

      expect(question.isValid, isFalse);
      expect(question.validationError, contains('must have options'));
    });

    test('MCQ cannot have subquestions', () {
      // This tests that MCQ and subquestions are mutually exclusive
      final question = Question(
        text: 'MCQ with subquestions - should be invalid',
        type: 'multiple_choice',
        options: ['A', 'B', 'C'],
        subQuestions: [
          SubQuestion(text: 'This should not be allowed'),
        ],
        marks: 1,
      );

      expect(question.isValid, isFalse);
      expect(question.validationError, contains('cannot have sub-questions'));
    });
  });

  // Group 2: Testing SubQuestions (the fix we made)
  group('SubQuestion entity', () {

    test('SubQuestion can be created with just text', () {
      // After our fix, SubQuestion no longer has marks field
      final subQuestion = SubQuestion(text: 'Define photosynthesis');

      expect(subQuestion.text, equals('Define photosynthesis'));
    });

    test('SubQuestion can be converted to JSON', () {
      final subQuestion = SubQuestion(text: 'Explain gravity');

      final json = subQuestion.toJson();

      expect(json['text'], equals('Explain gravity'));
      // Make sure there's NO marks field in JSON
      expect(json.containsKey('marks'), isFalse);
    });

    test('SubQuestion can be created from JSON', () {
      final json = {'text': 'What is evolution?'};

      final subQuestion = SubQuestion.fromJson(json);

      expect(subQuestion.text, equals('What is evolution?'));
    });

    test('SubQuestion copyWith works correctly', () {
      final original = SubQuestion(text: 'Original text');
      final copied = original.copyWith(text: 'New text');

      expect(copied.text, equals('New text'));
      expect(original.text, equals('Original text')); // Original unchanged
    });
  });

  // Group 3: Testing Essay questions with subquestions
  group('Essay Question with subquestions', () {

    test('Essay question can have subquestions', () {
      final question = Question(
        text: 'Explain the water cycle',
        type: 'essay',
        marks: 10,
        subQuestions: [
          SubQuestion(text: 'Define evaporation'),
          SubQuestion(text: 'Define condensation'),
          SubQuestion(text: 'Define precipitation'),
        ],
      );

      expect(question.isValid, isTrue);
      expect(question.subQuestions.length, equals(3));
    });

    test('Essay question without subquestions is also valid', () {
      final question = Question(
        text: 'Write an essay about climate change',
        type: 'essay',
        marks: 15,
        subQuestions: [], // No subquestions is OK for essay
      );

      expect(question.isValid, isTrue);
    });

    test('Essay question cannot have options', () {
      // Essay questions shouldn't have MCQ-style options
      final question = Question(
        text: 'Essay question',
        type: 'essay',
        options: ['A', 'B', 'C'], // This should make it invalid
        marks: 10,
      );

      expect(question.isValid, isFalse);
      expect(question.validationError, contains('cannot have options'));
    });
  });

  // Group 4: Testing totalMarks (our bug fix)
  group('Question totalMarks calculation', () {

    test('totalMarks returns the main question marks', () {
      // After our fix, totalMarks is just the question's marks
      // (subquestions don't have separate marks)
      final question = Question(
        text: 'Question with subquestions',
        type: 'essay',
        marks: 10,
        subQuestions: [
          SubQuestion(text: 'Part a'),
          SubQuestion(text: 'Part b'),
          SubQuestion(text: 'Part c'),
        ],
      );

      // Total marks should be 10 (just the main question marks)
      expect(question.totalMarks, equals(10));
    });

    test('totalMarks for question without subquestions', () {
      final question = Question(
        text: 'Simple question',
        type: 'short_answer',
        marks: 5,
      );

      expect(question.totalMarks, equals(5));
    });
  });

  // Group 5: Testing the duplicate subquestion prevention (Bug #3 fix)
  group('Question validation edge cases', () {

    test('Question with too many subquestions is invalid', () {
      // Create 27 subquestions (max is 26)
      final tooManySubQuestions = List.generate(
        27,
        (index) => SubQuestion(text: 'Subquestion ${index + 1}'),
      );

      final question = Question(
        text: 'Question with too many subquestions',
        type: 'essay',
        marks: 10,
        subQuestions: tooManySubQuestions,
      );

      expect(question.validationError, isNotEmpty);
      expect(question.validationError, contains('Too many sub-questions'));
    });

    test('Question with exactly 10 subquestions is valid', () {
      // Exactly 10 subquestions (max allowed) should be valid
      final exactlyMaxSubQuestions = List.generate(
        10,
        (index) => SubQuestion(text: 'Subquestion ${index + 1}'),
      );

      final question = Question(
        text: 'Question with max subquestions',
        type: 'essay',
        marks: 10,
        subQuestions: exactlyMaxSubQuestions,
      );

      // Should be valid
      expect(question.validationError, isEmpty);
    });

    test('Question text cannot be empty', () {
      final question = Question(
        text: '', // Empty text
        type: 'short_answer',
        marks: 5,
      );

      expect(question.validationError, isNotEmpty);
      expect(question.validationError, contains('required'));
    });

    test('Question with negative marks is invalid', () {
      final question = Question(
        text: 'Question with negative marks',
        type: 'short_answer',
        marks: -5, // Negative marks!
      );

      expect(question.validationError, isNotEmpty);
    });

    test('Question with zero marks is invalid', () {
      final question = Question(
        text: 'Question with zero marks',
        type: 'short_answer',
        marks: 0, // Zero marks not allowed
      );

      expect(question.validationError, isNotEmpty);
    });
  });

  // Group 6: Testing JSON serialization
  group('Question JSON serialization', () {

    test('Question can be converted to JSON and back', () {
      final original = Question(
        text: 'What is photosynthesis?',
        type: 'essay',
        marks: 10,
        options: null,
        correctAnswer: null,
        subQuestions: [
          SubQuestion(text: 'Define chlorophyll'),
          SubQuestion(text: 'Explain the process'),
        ],
        isOptional: false,
      );

      // Convert to JSON
      final json = original.toJson();

      // Convert back from JSON
      final reconstructed = Question.fromJson(json);

      // Check they're the same
      expect(reconstructed.text, equals(original.text));
      expect(reconstructed.type, equals(original.type));
      expect(reconstructed.marks, equals(original.marks));
      expect(reconstructed.subQuestions.length, equals(2));
      expect(reconstructed.subQuestions[0].text, equals('Define chlorophyll'));
    });

    test('MCQ question JSON includes options', () {
      final mcq = Question(
        text: 'What is 2+2?',
        type: 'multiple_choice',
        options: ['2', '3', '4', '5'],
        correctAnswer: '4',
        marks: 1,
      );

      final json = mcq.toJson();

      expect(json['options'], isNotNull);
      expect(json['options'], hasLength(4));
      expect(json['correct_answer'], equals('4'));
    });
  });

  // Group 7: Testing copyWith method
  group('Question copyWith', () {

    test('copyWith can update text while keeping other fields', () {
      final original = Question(
        text: 'Original text',
        type: 'essay',
        marks: 10,
      );

      final updated = original.copyWith(text: 'Updated text');

      expect(updated.text, equals('Updated text'));
      expect(updated.type, equals('essay')); // Unchanged
      expect(updated.marks, equals(10)); // Unchanged
    });

    test('copyWith can update marks', () {
      final original = Question(
        text: 'Question',
        type: 'short_answer',
        marks: 5,
      );

      final updated = original.copyWith(marks: 10);

      expect(updated.marks, equals(10));
      expect(updated.text, equals('Question')); // Unchanged
    });

    test('copyWith can update subquestions', () {
      final original = Question(
        text: 'Question',
        type: 'essay',
        marks: 10,
        subQuestions: [],
      );

      final updated = original.copyWith(
        subQuestions: [
          SubQuestion(text: 'New subquestion'),
        ],
      );

      expect(updated.subQuestions.length, equals(1));
      expect(original.subQuestions.length, equals(0)); // Original unchanged
    });
  });
}
