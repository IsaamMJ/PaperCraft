# Testing Quick Start

Quick reference for running tests in Papercraft.

## Most Common Commands

```bash
# Run all tests
flutter test test/

# Run tests with coverage report
bash scripts/run_tests.sh

# Run specific test file
flutter test test/features/catalog/domain/entities/grade_section_test.dart

# Run tests matching a pattern
flutter test test/ -k "should serialize"

# Run with verbose output
flutter test test/ -v

# Watch mode (auto-run on changes)
flutter test test/ --watch
```

## Test Structure

- **Entity Tests** (5 files) - Verify JSON serialization and properties
  - `grade_section_test.dart`
  - `teacher_subject_test.dart`
  - `exam_calendar_test.dart`
  - `exam_timetable_test.dart`
  - `exam_timetable_entry_test.dart`

- **Use Case Tests** (3 files) - Verify business logic with mocks
  - `load_grade_sections_usecase_test.dart`
  - `add_timetable_entry_usecase_test.dart`
  - `publish_exam_timetable_usecase_test.dart`

- **Service Tests** (1 file) - Verify validation logic
  - `timetable_validation_service_test.dart`

- **Test Infrastructure**
  - `test_helpers.dart` - Builders and test data
  - `scripts/run_tests.sh` - Automated test runner
  - `.github/workflows/tests.yml` - CI/CD pipeline

## Running Tests Before Commit

```bash
# Quick test (no coverage)
flutter test test/

# Full test (with coverage, analyzer, etc.)
bash scripts/run_tests.sh
```

## GitHub Actions CI/CD

Tests run automatically on:
- Push to `main`, `develop`, or `branch*`
- Pull requests to `main` or `develop`

View results in GitHub Actions tab.

## Common Test Scenarios

### Test Entity JSON Serialization
```bash
flutter test test/features/exams/domain/entities/exam_timetable_test.dart -k "JSON"
```

### Test Use Case Validation
```bash
flutter test test/features/exams/domain/usecases/add_timetable_entry_usecase_test.dart
```

### Test Service Logic
```bash
flutter test test/features/exams/data/services/timetable_validation_service_test.dart
```

## Using Test Builders

All test builders are in `test/test_helpers.dart`:

```dart
// Grade section
final section = GradeSectionBuilder()
    .withSectionName('B')
    .buildJson();

// Exam timetable
final timetable = ExamTimetableBuilder()
    .withExamName('Custom Exam')
    .buildJson();

// Timetable entry
final entry = ExamTimetableEntryBuilder()
    .withTimes('10:00', '11:30')
    .buildJson();

// Teacher subject assignment
final subject = TeacherSubjectBuilder()
    .withTeacherId('teacher-2')
    .buildJson();

// Exam calendar
final calendar = ExamCalendarBuilder()
    .withMonthNumber(9)
    .buildJson();
```

## IDE Test Running

### VS Code
- Click "Run" above test
- Press Ctrl+F5 to debug
- Press Ctrl+Shift+D for test explorer

### Android Studio
- Click play icon next to test
- Right-click test → Run

### WebStorm
- Use Run menu → Run Tests
- Or Ctrl+Shift+F10

## Generating Mocks

If you add new repositories/services:

```bash
# Generate mock files
dart run build_runner build

# Or with cleanup
dart run build_runner build --delete-conflicting-outputs
```

## Troubleshooting

**Tests not found**: Run `flutter pub get` first

**Mock generation errors**: Try:
```bash
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

**Timeout errors**: Increase timeout:
```bash
flutter test test/file_test.dart --timeout 30s
```

**Memory issues**: Run tests serially:
```bash
flutter test test/ --concurrency=1
```

## Test Coverage

View coverage report after running `bash scripts/run_tests.sh`:

```
Coverage report generated at coverage/lcov.info
```

## Next Steps

1. Run existing tests to verify setup
2. Write tests for new features (TDD)
3. Ensure all tests pass before commit
4. Check CI/CD results on GitHub

## More Information

See `TEST_GUIDE.md` for comprehensive testing documentation.

---

**Quick Links**:
- Entity tests: 10+ files covering JSON serialization
- Use case tests: Tests with mocked repositories
- Service tests: Business logic validation
- CI/CD: GitHub Actions automatic testing
