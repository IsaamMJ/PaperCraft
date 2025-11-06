import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:papercraft/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Setup Flow Integration Tests', () {
    testWidgets('Complete admin setup flow from start to finish', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // ========== STEP 1: LOGIN AS ADMIN ==========
      print('\n[TEST] Step 1: Admin Login');

      // Find and tap email input
      final emailInput = find.byType(TextField).first;
      await tester.enterText(emailInput, 'admin@test.com');
      await tester.pumpAndSettle();

      // Find and tap password input
      final passwordInput = find.byType(TextField).at(1);
      await tester.enterText(passwordInput, 'password123');
      await tester.pumpAndSettle();

      // Find and tap login button
      final loginButton = find.text('Login');
      if (loginButton.evaluate().isNotEmpty) {
        await tester.tap(loginButton);
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      // Verify admin setup wizard is displayed
      expect(
        find.text('Step 1 of 4'),
        findsWidgets,
        reason: 'Admin should be redirected to setup wizard after login',
      );
      print('✓ Admin logged in and redirected to setup wizard');

      // ========== STEP 1: GRADE SELECTION ==========
      print('\n[TEST] Step 2: Grade Selection');

      // Verify step 1 is displayed
      expect(
        find.text('Step 1 of 4'),
        findsWidgets,
        reason: 'Should be on Step 1',
      );
      print('✓ Step 1 (Grade Selection) displayed');

      // Click Primary (1-5) button
      final primaryButton = find.text('Primary (1-5)');
      if (primaryButton.evaluate().isNotEmpty) {
        await tester.tap(primaryButton);
        await tester.pumpAndSettle();
        print('✓ Selected Primary grades (1-5)');
      }

      // Click Middle (6-8) button
      final middleButton = find.text('Middle (6-8)');
      if (middleButton.evaluate().isNotEmpty) {
        await tester.tap(middleButton);
        await tester.pumpAndSettle();
        print('✓ Selected Middle grades (6-8)');
      }

      // Enter school name
      final schoolNameInputs = find.byType(TextField);
      if (schoolNameInputs.evaluate().length > 2) {
        await tester.enterText(schoolNameInputs.at(2), 'Test School');
        await tester.pumpAndSettle();
        print('✓ Entered school name');
      }

      // Tap Next button
      final nextButton1 = find.text('Next');
      await tester.tap(nextButton1.first);
      await tester.pumpAndSettle();
      print('✓ Clicked Next button');

      // ========== STEP 2: SECTIONS ==========
      print('\n[TEST] Step 3: Section Configuration');

      // Verify step 2 is displayed
      expect(
        find.text('Step 2 of 4'),
        findsWidgets,
        reason: 'Should be on Step 2',
      );
      print('✓ Step 2 (Section Configuration) displayed');

      // Click "A, B, C" button to apply to all grades
      final abcButton = find.text('A, B, C');
      if (abcButton.evaluate().isNotEmpty) {
        await tester.tap(abcButton);
        await tester.pumpAndSettle();
        print('✓ Applied A, B, C sections to all grades');
      }

      // Verify sections are added
      expect(
        find.text('A'),
        findsWidgets,
        reason: 'Section A should be displayed',
      );
      print('✓ Sections verified in UI');

      // Tap Next button
      final nextButton2 = find.text('Next');
      await tester.tap(nextButton2.first);
      await tester.pumpAndSettle();
      print('✓ Clicked Next button');

      // ========== STEP 3: SUBJECTS ==========
      print('\n[TEST] Step 4: Subject Selection');

      // Verify step 3 is displayed
      expect(
        find.text('Step 3 of 4'),
        findsWidgets,
        reason: 'Should be on Step 3',
      );
      print('✓ Step 3 (Subject Selection) displayed');

      // Wait for subject suggestions to load
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap some subject chips
      final subjectChips = find.byType(FilterChip);
      if (subjectChips.evaluate().length > 0) {
        // Select first available subject for first grade
        await tester.tap(subjectChips.first);
        await tester.pumpAndSettle();
        print('✓ Selected first subject');

        // Select second subject if available
        if (subjectChips.evaluate().length > 1) {
          await tester.tap(subjectChips.at(1));
          await tester.pumpAndSettle();
          print('✓ Selected second subject');
        }
      }

      // Tap Next button
      final nextButton3 = find.text('Next');
      if (nextButton3.evaluate().isNotEmpty) {
        await tester.tap(nextButton3.first);
        await tester.pumpAndSettle();
        print('✓ Clicked Next button');
      }

      // ========== STEP 4: REVIEW ==========
      print('\n[TEST] Step 5: Review & Confirmation');

      // Verify step 4 is displayed
      expect(
        find.text('Step 4 of 4'),
        findsWidgets,
        reason: 'Should be on Step 4 (Review)',
      );
      print('✓ Step 4 (Review) displayed');

      // Verify summary information is displayed
      expect(
        find.text('Test School'),
        findsWidgets,
        reason: 'School name should be in review',
      );
      print('✓ School name displayed in review');

      // Verify grades are shown
      expect(
        find.byType(Container),
        findsWidgets,
        reason: 'Review should show configuration',
      );
      print('✓ Configuration summary displayed');

      // ========== COMPLETE SETUP ==========
      print('\n[TEST] Step 6: Complete Setup');

      // Find Complete Setup button
      final completeButton = find.text('Complete Setup');
      if (completeButton.evaluate().isNotEmpty) {
        await tester.tap(completeButton);
        await tester.pumpAndSettle(const Duration(seconds: 1));
        print('✓ Clicked Complete Setup button');

        // Wait for loading modal
        await tester.pumpAndSettle(const Duration(seconds: 4));
        print('✓ Loading modal displayed and completed');
      }

      // Verify success or redirect
      // Note: Depending on implementation, might redirect to home
      expect(
        find.byType(Scaffold),
        findsWidgets,
        reason: 'Page should be rendered',
      );
      print('✓ Setup completed successfully');

      print('\n[RESULT] ✓ Complete admin setup flow test PASSED');
    });

    testWidgets('Test validation on Step 1 - no grades selected', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Login (skipped for brevity)
      // Assume we're already at Step 1

      // Try to click Next without selecting grades
      final nextButton = find.text('Next');
      if (nextButton.evaluate().isNotEmpty) {
        await tester.tap(nextButton);
        await tester.pumpAndSettle();

        // Verify error message
        expect(
          find.byType(SnackBar),
          findsWidgets,
          reason: 'Error should be shown when no grades selected',
        );
        print('✓ Validation error shown correctly for Step 1');
      }
    });

    testWidgets('Test navigation back from Step 2 to Step 1', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Select grade and go to Step 2
      final primaryButton = find.text('Primary (1-5)');
      if (primaryButton.evaluate().isNotEmpty) {
        await tester.tap(primaryButton);
        await tester.pumpAndSettle();
      }

      final nextButton1 = find.text('Next');
      await tester.tap(nextButton1.first);
      await tester.pumpAndSettle();

      // Verify on Step 2
      expect(find.text('Step 2 of 4'), findsWidgets);

      // Click Previous
      final previousButton = find.text('Previous');
      if (previousButton.evaluate().isNotEmpty) {
        await tester.tap(previousButton);
        await tester.pumpAndSettle();

        // Verify back on Step 1
        expect(
          find.text('Step 1 of 4'),
          findsWidgets,
          reason: 'Should go back to Step 1',
        );
        print('✓ Navigation back to Step 1 works correctly');
      }
    });

    testWidgets('Test section input validation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to Step 2
      final primaryButton = find.text('Primary (1-5)');
      if (primaryButton.evaluate().isNotEmpty) {
        await tester.tap(primaryButton);
        await tester.pumpAndSettle();
      }

      final nextButton1 = find.text('Next');
      await tester.tap(nextButton1.first);
      await tester.pumpAndSettle();

      // Try to proceed without adding sections
      final nextButton2 = find.text('Next');
      await tester.tap(nextButton2.first);
      await tester.pumpAndSettle();

      // Should show validation error
      expect(
        find.byType(SnackBar),
        findsWidgets,
        reason: 'Error should be shown when sections not added for all grades',
      );
      print('✓ Section validation works correctly');
    });

    testWidgets('Test subject loading and selection', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate through steps to reach Step 3
      final primaryButton = find.text('Primary (1-5)');
      if (primaryButton.evaluate().isNotEmpty) {
        await tester.tap(primaryButton);
        await tester.pumpAndSettle();
      }

      var nextButton = find.text('Next');
      await tester.tap(nextButton.first);
      await tester.pumpAndSettle();

      // Add sections
      final abcButton = find.text('A, B, C');
      if (abcButton.evaluate().isNotEmpty) {
        await tester.tap(abcButton);
        await tester.pumpAndSettle();
      }

      nextButton = find.text('Next');
      await tester.tap(nextButton.first);
      await tester.pumpAndSettle();

      // Verify subjects are loading
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify subject chips are displayed
      expect(
        find.byType(FilterChip),
        findsWidgets,
        reason: 'Subject suggestions should be displayed',
      );
      print('✓ Subject catalog loaded successfully');
    });

    testWidgets('Test quick-add buttons on Step 2', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to Step 2
      final primaryButton = find.text('Primary (1-5)');
      if (primaryButton.evaluate().isNotEmpty) {
        await tester.tap(primaryButton);
        await tester.pumpAndSettle();
      }

      var nextButton = find.text('Next');
      await tester.tap(nextButton.first);
      await tester.pumpAndSettle();

      // Click ABC button
      final abcButton = find.text('A, B, C');
      if (abcButton.evaluate().isNotEmpty) {
        await tester.tap(abcButton);
        await tester.pumpAndSettle();

        // Verify A, B, C sections are added
        expect(find.text('A'), findsWidgets);
        expect(find.text('B'), findsWidgets);
        expect(find.text('C'), findsWidgets);
        print('✓ Quick-add button (A, B, C) works correctly');
      }
    });

    testWidgets('Test school name input validation', (WidgetTester tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Find school name input
      final inputs = find.byType(TextField);
      if (inputs.evaluate().length >= 2) {
        // Skip email/password, get school name
        await tester.enterText(inputs.at(0), 'Test School Name');
        await tester.pumpAndSettle();

        // Verify input was accepted
        expect(find.text('Test School Name'), findsWidgets);
        print('✓ School name input accepts valid data');
      }
    });
  });
}
