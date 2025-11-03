# Papercraft Testing Guide

This guide explains the automated test infrastructure set up for the Papercraft exam timetable system.

## Overview

The project uses a **multi-layer testing strategy** to ensure reliability:

1. **Unit Tests** - Test individual components (entities, use cases, services)
2. **Service Tests** - Test business logic and validation
3. **Widget Tests** - Test UI components and interactions
4. **Integration Tests** - Test complete workflows (TBD)
5. **CI/CD Pipeline** - Automated testing on every commit

## Test Structure

```
test/
├── test_helpers.dart                    # Shared test utilities, builders, mock data
├── features/
│   ├── catalog/
│   │   └── domain/
│   │       └── entities/
│   │           └── grade_section_test.dart
│   │       └── usecases/
│   │           └── load_grade_sections_usecase_test.dart
│   ├── assignments/
│   │   └── domain/
│   │       └── entities/
│   │           └── teacher_subject_test.dart
│   └── exams/
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── exam_timetable_test.dart
│       │   │   ├── exam_calendar_test.dart
│       │   │   └── exam_timetable_entry_test.dart
│       │   └── usecases/
│       │       ├── add_timetable_entry_usecase_test.dart
│       │       └── publish_exam_timetable_usecase_test.dart
│       └── data/
│           └── services/
│               └── timetable_validation_service_test.dart
```

## Running Tests

### Run All Tests
```bash
flutter test test/
```

### Run Specific Test File
```bash
flutter test test/features/catalog/domain/entities/grade_section_test.dart
```

### Run Tests with Coverage
```bash
flutter test test/ --coverage
```

### Run Tests and Generate Coverage Report
```bash
bash scripts/run_tests.sh
```

### Run Tests in Watch Mode (auto-run on file changes)
```bash
flutter test test/ --watch
```

### Run Specific Test Group
```bash
flutter test test/features/exams/domain/entities/exam_timetable_test.dart -k "should serialize to JSON"
```

## Test Files Created

### Entity Tests

These tests verify that domain entities can be created, serialized/deserialized, and copied correctly.

#### `grade_section_test.dart`
- ✅ Creation with correct properties
- ✅ Serialization to JSON
- ✅ Deserialization from JSON
- ✅ Round-trip serialization
- ✅ Equality comparison
- ✅ Copy with modifications
- ✅ toString representation

#### `teacher_subject_test.dart`
- ✅ Creation with correct properties
- ✅ Display name computation (e.g., "Grade 5-A Maths")
- ✅ JSON serialization round-trip
- ✅ Copy with modifications
- ✅ Deactivation support
- ✅ Equality comparison

#### `exam_calendar_test.dart`
- ✅ Upcoming exam detection
- ✅ Past deadline detection
- ✅ Days until deadline calculation
- ✅ Null deadline handling
- ✅ JSON serialization with date-only formatting
- ✅ Metadata support
- ✅ Soft deletion via copyWith

#### `exam_timetable_test.dart`
- ✅ Status enum (draft, published, completed, cancelled)
- ✅ Status extension for string conversion
- ✅ Computed properties (isDraft, isPublished, canEdit, displayName)
- ✅ Calendar vs ad-hoc detection
- ✅ JSON round-trip serialization
- ✅ Equality comparison
- ✅ Status lifecycle testing

#### `exam_timetable_entry_test.dart`
- ✅ Display name formatting (e.g., "Grade 5-A Maths")
- ✅ Time range formatting (e.g., "09:00 - 10:30")
- ✅ Exam date formatting (e.g., "Jun 15, 2024")
- ✅ Time parsing from string
- ✅ JSON serialization with time conversion
- ✅ Edge case times (midnight, end of day)
- ✅ Multiple month date formatting

### Use Case Tests

These tests verify business logic and validation rules using mocked repositories.

#### `load_grade_sections_usecase_test.dart`
- ✅ Returns list of sections for tenant
- ✅ Filters by gradeId when provided
- ✅ Returns empty list when no sections exist
- ✅ Returns failure when repository fails
- ✅ Always filters for active sections only
- ✅ Verifies repository calls with correct parameters

#### `add_timetable_entry_usecase_test.dart`
- ✅ Validates start time < end time
- ✅ Returns failure for invalid time ranges
- ✅ Prevents duplicate entries (same grade/subject/section)
- ✅ Calculates duration minutes correctly
- ✅ Creates entry successfully on valid input
- ✅ Handles repository errors gracefully
- ✅ Tests edge cases (same start/end time, 90-minute duration)

#### `publish_exam_timetable_usecase_test.dart`
- ✅ Returns failure when timetable not found
- ✅ Returns failure when no entries exist
- ✅ Updates status to published on success
- ✅ Sets publishedAt timestamp correctly
- ✅ Handles multiple entries correctly
- ✅ Verifies all repository calls in correct order
- ✅ Tests edge cases and error scenarios

### Service Tests

These tests verify business logic validation without repository dependencies.

#### `timetable_validation_service_test.dart`
- ✅ Validates entries list is not empty
- ✅ Detects past exam dates
- ✅ Validates start time < end time
- ✅ Validates duration > 0
- ✅ Detects scheduling conflicts (same grade/section on same date/time)
- ✅ Ignores conflicts for different grades
- ✅ Validates non-overlapping times correctly
- ✅ Single entry validation
- ✅ Multiple error collection

## Test Utilities

### TestData Class
Common constants for all tests:
- `testTenantId` - 'tenant-test-123'
- `testTeacherId` - 'teacher-test-123'
- `testAdminId` - 'admin-test-123'
- `testGradeId` - 'Grade 5'
- `testSubjectId` - 'Maths'
- `testSection` - 'A'
- `testAcademicYear` - '2024-2025'
- `testDateTime` - Fixed past date for consistency
- `futureDateTime` - 1 year in future

### Builder Classes
Fluent builders for creating test objects:

```dart
// Create and customize grade section
final section = GradeSectionBuilder()
    .withSectionName('B')
    .withIsActive(true)
    .buildJson();

// Create timetable with specific dates
final timetable = ExamTimetableBuilder()
    .withExamName('July Monthly Test')
    .withStatus('published')
    .asAdHoc()
    .buildJson();

// Create entry with custom times
final entry = ExamTimetableEntryBuilder()
    .withGradeSubjectSection('Grade 6', 'English', 'A')
    .withTimes('14:00', '15:30')
    .buildJson();

// Create teacher subject
final subject = TeacherSubjectBuilder()
    .withTeacherId('teacher-2')
    .withGradeSubjectSection('Grade 6', 'English', 'B')
    .withAcademicYear('2025-2026')
    .buildJson();

// Create exam calendar
final calendar = ExamCalendarBuilder()
    .withExamName('September Quarterly')
    .withMonthNumber(9)
    .buildJson();
```

## Mocking Strategy

Uses `mockito` package for mocking repository dependencies:

```dart
@GenerateMocks([GradeSectionRepository])
void main() {
  late MockGradeSectionRepository mockRepository;

  setUp(() {
    mockRepository = MockGradeSectionRepository();
  });

  test('should return list of sections', () async {
    // Arrange
    when(mockRepository.getGradeSections(...))
        .thenAnswer((_) async => Right(sections));

    // Act
    final result = await usecase(...);

    // Assert
    verify(mockRepository.getGradeSections(...)).called(1);
  });
}
```

## CI/CD Pipeline

GitHub Actions workflow automatically runs tests on:
- Push to `main`, `develop`, or `branch*` branches
- Pull requests to `main` or `develop`

### Workflow Steps

1. **Checkout Code** - Fetch repository
2. **Setup Flutter** - Install Flutter 3.x
3. **Get Dependencies** - Run `flutter pub get`
4. **Dart Analyzer** - Check for compile errors
5. **Unit Tests** - Run all tests with coverage
6. **Upload Coverage** - Send coverage to Codecov
7. **Formatting Check** - Verify code formatting
8. **Lint Check** - Run analyzer warnings
9. **Build APK** - Verify app builds successfully

### View CI/CD Status
- Check `.github/workflows/tests.yml` for workflow definition
- View test results in GitHub Actions tab on PR
- Coverage reports available via Codecov

## Writing New Tests

### Test File Naming
- Entity tests: `{entity}_test.dart`
- Use case tests: `{usecase}_test.dart`
- Service tests: `{service}_test.dart`

### Test Structure
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeatureName', () {
    // Setup
    setUp(() {
      // Initialize test objects
    });

    test('should do something specific', () async {
      // Arrange - set up test data and mocks

      // Act - execute the code under test

      // Assert - verify the results
    });
  });
}
```

### Using Builders
```dart
final builder = GradeSectionBuilder()
    .withSectionName('C')
    .withIsActive(false);

final json = builder.buildJson(); // Returns Map<String, dynamic>
final entity = GradeSection.fromJson(json); // For testing
```

### Mocking Repositories
```dart
when(mockRepository.getGradeSections(
  tenantId: anyNamed('tenantId'),
  gradeId: anyNamed('gradeId'),
  activeOnly: anyNamed('activeOnly'),
)).thenAnswer((_) async => Right(sections));
```

## Test Coverage Goals

- **Entities**: 100% - All JSON serialization and properties
- **Use Cases**: 95%+ - Happy path and major error scenarios
- **Services**: 100% - All validation logic
- **UI Widgets**: 80%+ - Main user flows (TBD)
- **Overall**: 75%+ minimum

## Common Issues and Solutions

### Issue: "Unresolved reference to TestData"
**Solution**: Ensure `test_helpers.dart` is imported:
```dart
import '../../../../test_helpers.dart';
```

### Issue: "Cannot find annotation @GenerateMocks"
**Solution**: Run build runner:
```bash
dart run build_runner build
```

### Issue: "No MockX implementation"
**Solution**: The mock needs to be generated. Run:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### Issue: "Test times out"
**Solution**: Increase timeout in test:
```dart
test('should handle long operation', () async {
  // test code
}, timeout: Timeout(Duration(seconds: 30)));
```

## Future Test Enhancements

- [ ] Widget tests for all UI screens
- [ ] Integration tests for complete workflows
- [ ] Performance tests for large datasets
- [ ] Accessibility tests (a11y)
- [ ] Golden image tests for UI consistency
- [ ] Load testing for concurrent operations
- [ ] E2E tests with real backend

## Running Tests in IDE

### VS Code
1. Install Dart and Flutter extensions
2. Open test file
3. Click "Run" above test or group
4. Or press Ctrl+F5 to run with debugger

### Android Studio
1. Open test file
2. Click green play icon next to test
3. Or right-click and select "Run"

### WebStorm
1. Open test file
2. Use Run menu → Run Tests
3. Or press Ctrl+Shift+F10

## Test Maintenance

### Running Tests Before Commit
```bash
flutter test test/
# Or use pre-commit hook
# Add to .git/hooks/pre-commit:
# flutter test test/ || exit 1
```

### Updating Tests After Code Changes
1. Run all tests to identify failures
2. Update test expectations to match new behavior
3. Update builders if entity signatures change
4. Add new tests for new functionality

## Debugging Tests

### Print Debug Output
```dart
test('debug test', () {
  debugPrint('Variable value: $variable');
  // Test code
});
```

### Run with Verbose Output
```bash
flutter test test/ -v
```

### Run Specific Test with Debugger
```bash
flutter test test/file_test.dart --start-paused
```

Then attach debugger in VS Code.

## Test Performance

### Current Test Suite Performance
- Entity tests: < 1 second
- Use case tests: < 2 seconds
- Service tests: < 1 second
- Total: ~4 seconds for quick feedback

### Optimization Tips
- Use mocks to avoid slow I/O
- Use builders for consistent test data
- Avoid heavy computations in tests
- Run tests in parallel when possible

## Contributing

When adding new features:
1. Write tests first (TDD style)
2. Implement the feature
3. Ensure all tests pass
4. Add to appropriate test file
5. Update this guide if needed
6. Push with green tests

---

**Last Updated**: 2024-11-03
**Test Files**: 10+
**Test Cases**: 100+
**Framework**: Flutter Test + Mockito
