# Testing Guide for Papercraft

## What We Created

We've written **41 automated tests** for your application that verify the code works correctly!

## Test Results

```
✅ All 41 tests passed!

📋 Test Breakdown:
- 18 validator tests
- 23 Question entity tests
```

## How to Run Tests

### Run All Tests
```bash
flutter test
```

### Run Specific Test File
```bash
# Run only validator tests
flutter test test/core/domain/validators/input_validators_test.dart

# Run only Question entity tests
flutter test test/features/paper_workflow/domain/entities/question_entity_test.dart
```

### Run Tests in Watch Mode (Auto-runs on file changes)
```bash
flutter test --watch
```

### Run With Coverage Report
```bash
flutter test --coverage
```

## What the Tests Do

### 1. Validator Tests (18 tests)
**File:** `test/core/domain/validators/input_validators_test.dart`

Tests that ensure your validation logic works correctly:

✅ **Question Text Validation:**
- Rejects empty questions
- Rejects questions that are too short (< 3 characters)
- Rejects questions that are too long (> 2000 characters)
- Accepts valid questions
- Rejects questions with only spaces

✅ **Marks Validation:**
- Rejects negative marks
- Rejects zero marks
- Accepts valid marks (1-100)
- Rejects marks over 100

✅ **Option Validation (for MCQs):**
- Rejects empty options
- Rejects options with only spaces
- Accepts valid options
- Rejects options that are too long (> 500 characters)

✅ **Paper Title Validation:**
- Rejects empty titles
- Rejects titles that are too short
- Accepts valid titles
- Rejects titles that are too long

### 2. Question Entity Tests (23 tests)
**File:** `test/features/paper_workflow/domain/entities/question_entity_test.dart`

Tests that verify your Question entity and the bug fixes we made:

✅ **MCQ Validation:**
- MCQ must have at least 2 options *(Bug #2 fix)*
- MCQ cannot have subquestions
- MCQ without options is invalid

✅ **SubQuestion Entity:**
- SubQuestions can be created with just text *(Bug fix: no marks field)*
- SubQuestions serialize to JSON correctly (without marks)
- SubQuestions can be created from JSON
- copyWith works correctly

✅ **Essay Questions:**
- Can have subquestions
- Can work without subquestions
- Cannot have MCQ-style options

✅ **totalMarks Calculation:**
- Returns main question marks only *(Bug fix: removed subquestion marks summing)*
- Works for questions without subquestions

✅ **Edge Cases:**
- Prevents more than 10 subquestions *(Max limit)*
- Allows exactly 10 subquestions *(Bug #3 fix)*
- Rejects empty question text
- Rejects negative marks
- Rejects zero marks

✅ **JSON Serialization:**
- Questions can be converted to/from JSON
- MCQ options are preserved in JSON

✅ **copyWith Method:**
- Can update individual fields
- Doesn't modify original question

## Why These Tests Are Important

### 1. **Catch Bugs Early**
Before we wrote tests, bugs like "MCQ with only 1 option" could slip through. Now, if someone accidentally breaks this rule, the test fails immediately!

```dart
// This test ensures the bug never comes back:
test('MCQ is invalid with only 1 option', () {
  final question = Question(
    text: 'What is the capital?',
    type: 'multiple_choice',
    options: ['Paris'], // Only 1 option!
    marks: 1,
  );

  expect(question.isValid, isFalse); // ✅ Test catches the error
});
```

### 2. **Safe Refactoring**
Remember when we removed the `marks` field from `SubQuestion`? The tests told us exactly where to fix things:

```
❌ Test failed: The getter 'marks' isn't defined for SubQuestion
```

We fixed it, ran tests again:
```
✅ All tests passed!
```

Now we're confident the change works!

### 3. **Documentation**
Tests show HOW your code should be used:

```dart
test('SubQuestion has no marks field', () {
  // This documents that SubQuestions don't track individual marks
  final subQ = SubQuestion(text: 'Explain gravity');

  expect(subQ.text, equals('Explain gravity'));
  // No subQ.marks - because it doesn't exist!
});
```

### 4. **Prevent Regressions**
If in 6 months someone tries to add a 27th subquestion feature, the test will fail and remind them of the 10-limit rule!

## Understanding Test Output

When you run `flutter test`, you'll see:

```
00:00 +1: validateQuestionText returns error when question text is empty
00:00 +2: validateQuestionText returns error when question text is too short
00:00 +3: validateQuestionText returns null for valid question text
...
00:01 +41: All tests passed!
```

**What it means:**
- `+1`, `+2`, `+3` = Number of passing tests
- `00:00`, `00:01` = Time elapsed
- `All tests passed!` = 🎉 Success!

If a test fails:
```
00:00 +5 -1: validateMarks returns error for negative marks [E]
  Expected: not null
    Actual: <null>
```

**What it means:**
- `+5 -1` = 5 passed, 1 failed
- `[E]` = Error
- Shows what was expected vs what actually happened

## Next Steps

### Add More Tests
As you add features, write tests for them! For example:

```dart
// Test for the AI polish feature
test('AI polish preserves blanks in fill-in questions', () async {
  final input = 'Mammals are ____ animals';
  final result = await GroqService.polishText(input);

  expect(result.polished, contains('____')); // Blanks preserved!
});
```

### Run Tests Before Committing
Make it a habit:
```bash
# Before you commit code:
flutter test

# If all pass:
git add .
git commit -m "Add new feature"
```

## Test File Structure

```
test/
├── core/
│   └── domain/
│       └── validators/
│           └── input_validators_test.dart (18 tests)
└── features/
    └── paper_workflow/
        └── domain/
            └── entities/
                └── question_entity_test.dart (23 tests)
```

## Key Testing Concepts

### Arrange-Act-Assert Pattern
```dart
test('example test', () {
  // ARRANGE: Set up test data
  final question = Question(text: 'Test?', type: 'essay', marks: 5);

  // ACT: Perform the action
  final result = question.isValid;

  // ASSERT: Check the result
  expect(result, isTrue);
});
```

### expect() Function
```dart
expect(actual, matcher);

// Common matchers:
expect(value, isNull);
expect(value, isNotNull);
expect(value, equals(expected));
expect(value, isTrue);
expect(value, isFalse);
expect(list, hasLength(5));
expect(string, contains('text'));
expect(string, isEmpty);
expect(string, isNotEmpty);
```

### group() for Organization
```dart
group('Validation tests', () {
  test('test 1', () { ... });
  test('test 2', () { ... });
  test('test 3', () { ... });
});
```

## Common Commands

```bash
# Run all tests
flutter test

# Run with detailed output
flutter test --reporter=expanded

# Run specific file
flutter test test/core/domain/validators/input_validators_test.dart

# Run tests matching pattern
flutter test --name="validates"

# Generate coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

## Benefits You're Getting

✅ **Confidence** - Know your code works before deploying
✅ **Faster Development** - Find bugs in seconds, not hours
✅ **Better Design** - Testable code is usually better architected
✅ **Documentation** - Tests show how code should be used
✅ **Regression Prevention** - Old bugs stay fixed
✅ **Refactoring Safety** - Change code without fear

## Remember

> **"Tests are not about finding bugs; they're about preventing bugs from reaching users."**

Every test you write is an investment in quality and saves debugging time later!

---

Happy Testing! 🧪✨
