// test/core/domain/validators/input_validators_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:papercraft/core/domain/validators/input_validators.dart';

/// This is our first test file!
/// Tests verify that our validation functions work correctly.
///
/// Structure:
/// - main() function wraps all tests
/// - group() organizes related tests together
/// - test() defines individual test cases
/// - expect() checks if actual result matches expected result

void main() {
  // Group 1: Testing question text validation
  group('validateQuestionText', () {

    test('returns error when question text is empty', () {
      // Arrange: Set up test data
      final emptyText = '';

      // Act: Call the function we want to test
      final result = InputValidators.validateQuestionText(emptyText);

      // Assert: Check the result is what we expect
      expect(result, isNotNull); // Should return an error message
      expect(result, contains('required')); // Error should mention "required"
    });

    test('returns error when question text is too short', () {
      // Question text must be at least 3 characters
      final shortText = 'Hi'; // Only 2 characters (too short)

      final result = InputValidators.validateQuestionText(shortText);

      expect(result, isNotNull);
      expect(result, contains('at least'));
    });

    test('returns error when question text is too long', () {
      // Create a string longer than max allowed (2000 characters)
      final longText = 'A' * 2001; // 2001 characters

      final result = InputValidators.validateQuestionText(longText);

      expect(result, isNotNull);
      expect(result, contains('exceed'));
    });

    test('returns null (no error) for valid question text', () {
      final validText = 'What is the capital of France?';

      final result = InputValidators.validateQuestionText(validText);

      expect(result, isNull); // null means validation passed!
    });

    test('returns error for text with only spaces', () {
      final spacesOnly = '     ';

      final result = InputValidators.validateQuestionText(spacesOnly);

      expect(result, isNotNull); // Should fail validation
    });
  });

  // Group 2: Testing marks validation
  group('validateMarks', () {

    test('returns error for negative marks', () {
      final negativeMarks = -5;

      final result = InputValidators.validateMarks(negativeMarks);

      expect(result, isNotNull);
      expect(result, contains('at least'));
    });

    test('returns error for zero marks', () {
      final zeroMarks = 0;

      final result = InputValidators.validateMarks(zeroMarks);

      expect(result, isNotNull);
    });

    test('returns null for valid marks (1)', () {
      final validMarks = 1;

      final result = InputValidators.validateMarks(validMarks);

      expect(result, isNull); // Valid!
    });

    test('returns null for valid marks (10)', () {
      final validMarks = 10;

      final result = InputValidators.validateMarks(validMarks);

      expect(result, isNull);
    });

    test('returns error for marks exceeding maximum (100)', () {
      final tooManyMarks = 101;

      final result = InputValidators.validateMarks(tooManyMarks);

      expect(result, isNotNull);
      expect(result, contains('exceed'));
    });
  });

  // Group 3: Testing option validation (for MCQ)
  group('validateOption', () {

    test('returns error for empty option', () {
      final emptyOption = '';

      final result = InputValidators.validateOption(emptyOption);

      expect(result, isNotNull);
    });

    test('returns error for option with only spaces', () {
      final spacesOption = '   ';

      final result = InputValidators.validateOption(spacesOption);

      expect(result, isNotNull);
    });

    test('returns null for valid option', () {
      final validOption = 'Paris';

      final result = InputValidators.validateOption(validOption);

      expect(result, isNull);
    });

    test('returns error for option that is too long', () {
      // Max option length is 500 characters
      final longOption = 'A' * 501;

      final result = InputValidators.validateOption(longOption);

      expect(result, isNotNull);
      expect(result, contains('exceed'));
    });
  });

  // Group 4: Testing paper title validation
  group('validatePaperTitle', () {

    test('returns error for empty title', () {
      final result = InputValidators.validatePaperTitle('');
      expect(result, isNotNull);
    });

    test('returns error for title that is too short', () {
      final result = InputValidators.validatePaperTitle('Hi'); // Less than 3 chars
      expect(result, isNotNull);
    });

    test('returns null for valid title', () {
      final result = InputValidators.validatePaperTitle('Math Final Exam 2024');
      expect(result, isNull);
    });

    test('returns error for title that is too long', () {
      final longTitle = 'A' * 201; // Max is 200 characters
      final result = InputValidators.validatePaperTitle(longTitle);
      expect(result, isNotNull);
    });
  });
}
