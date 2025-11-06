# Admin Flow Testing Execution Guide

## Overview

This guide provides step-by-step instructions for executing the comprehensive admin flow tests for the Papercraft application. The tests are organized into three levels:

1. **Unit Tests** - Test BLoC logic and state management
2. **Widget Tests** - Test individual UI components
3. **Integration Tests** - Test complete user flows

---

## Prerequisites

Before running tests, ensure you have:

- [ ] Flutter SDK installed and updated
- [ ] Project dependencies installed (`flutter pub get`)
- [ ] A test device/emulator available (for integration tests)
- [ ] Test admin account credentials
- [ ] Supabase backend configured
- [ ] Network connectivity

---

## Quick Start

### Run All Tests
```bash
flutter test
```

### Run Only Admin Tests
```bash
flutter test test/features/admin/
```

### Run with Coverage
```bash
flutter test --coverage
```

---

## Detailed Test Execution

### 1. Unit Tests - Admin Setup BLoC

**File:** `test/features/admin/presentation/bloc/admin_setup_bloc_test.dart`

#### Purpose
Tests the business logic of the admin setup wizard without UI components.

#### Run Command
```bash
flutter test test/features/admin/presentation/bloc/admin_setup_bloc_test.dart
```

#### What It Tests
- ✓ Grade management (add, remove, prevent duplicates)
- ✓ Section management (add, remove, prevent duplicates)
- ✓ Subject management (add, remove, load suggestions)
- ✓ Step navigation (next, previous with validation)
- ✓ School details updates
- ✓ Save functionality with success and error handling

#### Expected Output
```
AdminSetupBloc Tests
  Grade Management Tests
    ✓ should add grade successfully when valid grade number is provided
    ✓ should remove grade successfully when it exists
    ✓ should prevent duplicate grades
  Section Management Tests
    ✓ should add section successfully to a grade
    ✓ should remove section successfully from a grade
  Subject Management Tests
    ✓ should load subject suggestions successfully
    ✓ should add subject successfully to a grade
  Step Navigation Tests
    ✓ should move to next step when validation passes
    ✓ should not move to next step when validation fails on step 1
    ✓ should move to previous step
  Save Admin Setup Tests
    ✓ should save admin setup successfully
    ✓ should handle save errors gracefully
  School Details Update Tests
    ✓ should update school details successfully

All tests passed: 14/14
```

#### Interpreting Results
- ✓ **PASS**: Test scenario works as expected
- ✗ **FAIL**: Test scenario has a bug or issue (see error message)
- ⊘ **SKIP**: Test was skipped (usually indicates a setup issue)

#### Common Issues & Troubleshooting

**Issue:** `MockError: When() called inside test but setUp/tearDown was not being called for MockBloc`
- **Solution:** Ensure `tearDown()` is called to close the BLoC

**Issue:** `StateError: Stream has already been listened to`
- **Solution:** Create fresh BLoC instances for each test

**Issue:** Tests timeout
- **Solution:** Increase timeout or ensure mocks return values quickly

---

### 2. Widget Tests - Admin Setup Wizard Page

**File:** `test/features/admin/presentation/pages/admin_setup_wizard_page_test.dart`

#### Purpose
Tests UI components and their interactions with the user.

#### Run Command
```bash
flutter test test/features/admin/presentation/pages/admin_setup_wizard_page_test.dart -v
```

The `-v` flag provides verbose output showing each test.

#### What It Tests
- ✓ Page initialization and display
- ✓ Grade selection UI and interactions
- ✓ Navigation between steps
- ✓ Progress indicators
- ✓ Input validation feedback
- ✓ Loading and success states
- ✓ Accessibility features
- ✓ Responsive design

#### Expected Output
```
AdminSetupWizardPage Widget Tests
  Page Initialization
    ✓ should display step 1 initially
    ✓ should display progress bar
    ✓ should display step indicators
  Step 1: Grade Selection
    ✓ should display grade selection buttons
    ✓ should add grades when Primary button is tapped
    ✓ should display next button when grade is selected
    ✓ should show validation error when trying to proceed without selecting grades
  Navigation Between Steps
    ✓ should move to step 2 when next button is tapped on step 1
    ✓ should go back to previous step when previous button is tapped
    ✓ should show correct progress indicator for each step
  ... more tests ...

All tests passed: 21/21
```

#### Common Issues & Troubleshooting

**Issue:** `WidgetTestException: No Material widget found`
- **Solution:** Ensure test wraps widget in MaterialApp

**Issue:** `No material localizations found`
- **Solution:** Add localization dependencies:
  ```bash
  flutter pub add flutter_localizations
  ```

**Issue:** `TextField finder returns nothing`
- **Solution:** Check that input fields are actually rendered in the widget

**Issue:** Button not found
- **Solution:** Verify button text matches exactly (including case)

---

### 3. Integration Tests - Complete Flow

**File:** `test/integration/admin_setup_integration_test.dart`

#### Purpose
Tests the complete admin setup flow from login to completion on an actual device/emulator.

#### Prerequisites for Integration Tests
- [ ] Device/emulator running
- [ ] App can be built and run
- [ ] Test account credentials available
- [ ] Supabase backend is accessible

#### Run Command
```bash
flutter test test/integration/admin_setup_integration_test.dart \
  -v \
  --dart-define=ADMIN_EMAIL=admin@test.com \
  --dart-define=ADMIN_PASSWORD=password123
```

Or on a specific device:
```bash
flutter test test/integration/admin_setup_integration_test.dart \
  -v \
  --device-id=<device_id>
```

#### What It Tests
- ✓ Admin login and setup wizard access
- ✓ Complete Step 1 → 4 flow
- ✓ Grade selection
- ✓ Section configuration
- ✓ Subject selection
- ✓ Review and confirmation
- ✓ Setup completion and redirect
- ✓ Validation at each step
- ✓ Navigation back and forward
- ✓ Quick-add buttons
- ✓ Data persistence

#### Expected Output
```
[TEST] Step 1: Admin Login
✓ Admin logged in and redirected to setup wizard

[TEST] Step 2: Grade Selection
✓ Step 1 (Grade Selection) displayed
✓ Selected Primary grades (1-5)
✓ Selected Middle grades (6-8)
✓ Entered school name
✓ Clicked Next button

[TEST] Step 3: Section Configuration
✓ Step 2 (Section Configuration) displayed
✓ Applied A, B, C sections to all grades
✓ Sections verified in UI
✓ Clicked Next button

[TEST] Step 4: Subject Selection
✓ Step 3 (Subject Selection) displayed
✓ Selected first subject
✓ Selected second subject
✓ Clicked Next button

[TEST] Step 5: Review & Confirmation
✓ Step 4 (Review) displayed
✓ School name displayed in review
✓ Configuration summary displayed

[TEST] Step 6: Complete Setup
✓ Clicked Complete Setup button
✓ Loading modal displayed and completed
✓ Setup completed successfully

[RESULT] ✓ Complete admin setup flow test PASSED
```

#### Common Issues & Troubleshooting

**Issue:** `Socket exception - Connection refused`
- **Solution:** Verify Supabase backend is running and accessible

**Issue:** `Authentication failed - Invalid credentials`
- **Solution:** Verify test credentials are correct and account exists

**Issue:** `Timeout waiting for element`
- **Solution:** Increase `pumpAndSettle()` duration or check if element exists

**Issue:** `Element not found after wait`
- **Solution:** Element may not be rendered - check UI logic

---

## Manual Testing Checklist

For comprehensive coverage, also perform manual testing using the provided checklist:

**File:** `ADMIN_FLOW_TEST_CHECKLIST.md`

### Running Manual Tests

1. **Start the app:**
   ```bash
   flutter run
   ```

2. **Login as admin:**
   - Username: `admin@test.com`
   - Password: `password123`

3. **Follow the checklist sections:**
   - Section 1: Login & Admin Access
   - Section 2: Step 1 - Grade Selection
   - Section 3: Step 2 - Sections Configuration
   - Section 4: Step 3 - Subject Selection
   - Section 5: Step 4 - Review & Confirmation
   - Section 6: Save & Completion
   - Sections 7-12: Additional validations

4. **Document findings:**
   - Check off items as you test them
   - Note any bugs or issues using the bug report template
   - Take screenshots of failures

---

## Test Results Analysis

### Success Criteria

✓ **All tests pass** if:
- Unit tests: 14/14 pass
- Widget tests: 21/21 pass (or similar count)
- Integration tests: All flows complete successfully
- Manual checklist: 95%+ items checked

### Issues to Investigate

🔴 **Critical Issues** (Block release):
- Cannot complete setup flow
- Data not saved to database
- Infinite redirect loops
- Validation prevents legitimate input

🟠 **High Issues** (Should fix before release):
- UI rendering errors
- Navigation bugs between steps
- Validation error messages unclear
- Performance problems

🟡 **Medium Issues** (Fix soon):
- Minor UI alignment issues
- Typos in text
- Accessibility improvements needed
- Performance optimizations

🟢 **Low Issues** (Nice to fix):
- Code style issues
- Unused imports
- Duplicate code

---

## Continuous Integration Setup

### GitHub Actions Example

Create `.github/workflows/test.yml`:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'

      - run: flutter pub get

      - run: flutter test

      - run: flutter test --coverage

      - uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
```

### Local Pre-commit Hook

Create `.git/hooks/pre-commit`:

```bash
#!/bin/bash
echo "Running tests before commit..."
flutter test test/features/admin/
if [ $? -ne 0 ]; then
  echo "Tests failed. Commit aborted."
  exit 1
fi
```

---

## Test Data Management

### Creating Test Data

```bash
# Create test admin account
# Use Supabase dashboard or scripts/seed_test_data.sh

# Or manually:
# 1. Go to Supabase dashboard
# 2. Create user with role = 'admin'
# 3. Note tenant_id for database entries
```

### Resetting Test Data

```bash
# Delete all setup data for a tenant
# Run in Supabase SQL editor:

DELETE FROM grade_section_subject WHERE tenant_id = 'test-tenant-id';
DELETE FROM grade_sections WHERE tenant_id = 'test-tenant-id';
DELETE FROM grades WHERE tenant_id = 'test-tenant-id';
DELETE FROM subjects WHERE tenant_id = 'test-tenant-id';
UPDATE tenants SET is_initialized = false WHERE id = 'test-tenant-id';
```

---

## Performance Testing

### Memory Usage
```bash
flutter test --profile
```

### Frame Rate
```bash
flutter run --profile
# Then in device: Enable "Show Performance Overlay"
```

### Build Time
```bash
time flutter build apk --release
time flutter build ios --release
```

---

## Bug Reporting

### Bug Template

When you find a bug, document it:

```markdown
## Bug: [Title]

### Severity: [Critical/High/Medium/Low]

### Reproduction Steps:
1. ...
2. ...
3. ...

### Expected Result:
...

### Actual Result:
...

### Screenshots:
[Attach image]

### Environment:
- Device: [iPhone/Android/Web]
- OS Version: [Version]
- App Version: [Version]
- Test Date: [Date]

### Root Cause (if known):
...

### Suggested Fix:
...
```

### Bug Tracking

Store bugs in:
- GitHub Issues (for public projects)
- Jira (for enterprise)
- Local file: `BUGS_FOUND.md`

---

## Test Maintenance

### Keep Tests Updated

- [ ] Update tests when UI changes
- [ ] Update tests when BLoC changes
- [ ] Remove tests for deleted features
- [ ] Add tests for new features
- [ ] Keep mock data current

### Review Test Coverage

```bash
# Generate coverage report
flutter test --coverage

# View coverage
open coverage/index.html  # macOS
# or
start coverage/index.html  # Windows
```

Target: **80%+ code coverage** for critical features

---

## Appendix: Useful Commands

```bash
# Run tests with tags
flutter test -t admin_setup

# Run tests matching pattern
flutter test --name "should add grade"

# Run tests in debug mode
flutter test --debug

# Run tests in release mode
flutter test -r

# Generate test report
flutter test --test-randomize-ordering-seed=random

# Run specific file
flutter test test/features/admin/presentation/bloc/admin_setup_bloc_test.dart

# Watch mode (re-run on changes)
flutter test --watch

# Show coverage
flutter test --coverage
```

---

## Next Steps

After completing these tests:

1. ✓ Review test results
2. ✓ Document bugs found
3. ✓ Create issues for bugs
4. ✓ Assign bugs to developers
5. ✓ Run tests again after fixes
6. ✓ Update test coverage
7. ✓ Merge code to main branch
8. ✓ Deploy to production

---

## Additional Resources

- [Flutter Testing Documentation](https://flutter.dev/docs/testing)
- [BLoC Testing Guide](https://bloclibrary.dev/#/testing)
- [Integration Testing](https://flutter.dev/docs/testing/integration-tests)
- [Flutter Test Cheat Sheet](https://gist.github.com/devkaul/...)

---

## Support

For issues with the tests:
1. Check the troubleshooting section above
2. Review test logs carefully
3. Check Flutter version compatibility
4. Consult team members
5. Report issues in GitHub Issues

---

**Last Updated:** 2025-11-05
**Maintained By:** QA Team
**Version:** 1.0
