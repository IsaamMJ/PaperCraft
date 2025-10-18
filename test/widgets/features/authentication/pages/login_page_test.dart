import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:go_router/go_router.dart';
import 'package:papercraft/features/authentication/presentation/pages/login_page.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_event.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_state.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/core/presentation/constants/app_messages.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockAuthBloc extends Mock implements AuthBloc {}

class MockGoRouter extends Mock implements GoRouter {}

class MockUserEntity extends Mock implements UserEntity {}

// Register fallback values for Mocktail
class FakeAuthEvent extends Fake implements AuthEvent {}

class FakeAuthState extends Fake implements AuthState {}

// ============================================================================
// TEST HELPERS
// ============================================================================

/// Helper to create a testable widget with all dependencies
Widget createTestableWidget({
  required AuthBloc authBloc,
  GoRouter? goRouter,
}) {
  return MaterialApp(
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: goRouter != null
          ? InheritedGoRouter(
        goRouter: goRouter,
        child: const LoginPage(),
      )
          : const LoginPage(),
    ),
  );
}

/// Helper to create a mock user
UserEntity createMockUser({
  String id = 'test-user-123',
  String email = 'test@example.com',
  String fullName = 'Test User',
}) {
  final user = MockUserEntity();
  when(() => user.id).thenReturn(id);
  when(() => user.email).thenReturn(email);
  when(() => user.fullName).thenReturn(fullName);
  return user;
}

// ============================================================================
// MAIN TEST SUITE
// ============================================================================

void main() {
  late MockAuthBloc mockAuthBloc;
  late MockGoRouter mockGoRouter;

  // Setup before each test
  setUp(() {
    mockAuthBloc = MockAuthBloc();
    mockGoRouter = MockGoRouter();

    // Register fallback values
    registerFallbackValue(FakeAuthEvent());
    registerFallbackValue(FakeAuthState());

    // Default behavior: start with AuthInitial state
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    when(() => mockAuthBloc.stream).thenAnswer((_) => const Stream.empty());

    // Fix: Mock close() to return Future<void>
    when(() => mockAuthBloc.close()).thenAnswer((_) async {});
  });

  group('LoginPage - Widget Rendering', () {
    testWidgets('should render all key UI elements', (tester) async {
      // Set a reasonable screen size to avoid overflow
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Arrange
      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));

      // Act
      await tester.pumpAndSettle();

      // Assert - Check all key elements are present
      expect(find.text('Papercraft'), findsOneWidget);
      expect(
        find.text('Create, organize, and manage\nyour question papers easily'),
        findsOneWidget,
      );
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(
        find.text(
          'By continuing, you agree to our Terms of Service\nand Privacy Policy',
        ),
        findsOneWidget,
      );
    });

    testWidgets('should display logo container', (tester) async {
      // Set a reasonable screen size
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Arrange
      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));

      // Act
      await tester.pumpAndSettle();

      // Assert - Logo container should be present (with gradient decoration)
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);

      // Verify at least one container has BoxDecoration with gradient
      final containers = tester.widgetList<Container>(containerFinder);
      final hasGradientContainer = containers.any((container) {
        final decoration = container.decoration;
        return decoration is BoxDecoration && decoration.gradient != null;
      });
      expect(hasGradientContainer, isTrue);
    });

    testWidgets('should handle tablet screen size without overflow',
            (tester) async {
          // Test tablet size
          tester.view.physicalSize = const Size(768, 1024);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
          await tester.pumpAndSettle();

          // Should render without errors
          expect(find.text('Papercraft'), findsOneWidget);

          // Reset
          addTearDown(tester.view.reset);
        });

    testWidgets('should handle small mobile screens without overflow',
            (tester) async {
          // Test very small screens (iPhone SE size)
          tester.view.physicalSize = const Size(375, 667);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
          await tester.pumpAndSettle();

          expect(find.text('Papercraft'), findsOneWidget);
          expect(find.text('Continue with Google'), findsOneWidget);
          addTearDown(tester.view.reset);
        });

    testWidgets('should handle desktop screens', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Papercraft'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      addTearDown(tester.view.reset);
    });

    testWidgets('should handle landscape orientation', (tester) async {
      // Landscape mobile
      tester.view.physicalSize = const Size(667, 375);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      addTearDown(tester.view.reset);
    });
  });

  group('LoginPage - BLoC State Handling', () {
    testWidgets('should show sign-in button in AuthInitial state',
            (tester) async {
          // Set reasonable screen size
          tester.view.physicalSize = const Size(800, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          // Arrange
          when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

          // Act
          await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
          await tester.pumpAndSettle();

          // Assert
          expect(find.text('Continue with Google'), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        });

    testWidgets('should show loading indicator in AuthLoading state',
            (tester) async {
          // Arrange
          when(() => mockAuthBloc.state).thenReturn(const AuthLoading());

          // Act
          await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
          // Use pump instead of pumpAndSettle to avoid timeout with infinite animation
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          // Assert
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.text(AppMessages.processingAuth), findsOneWidget);
          expect(find.text('Continue with Google'), findsNothing);
        });

    testWidgets('should show error dialog when AuthError state is emitted',
            (tester) async {
          // Arrange
          const errorMessage = 'Sign-in failed. Please try again.';
          when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

          // Use a broadcast stream to allow multiple listeners
          final stateController = StreamController<AuthState>.broadcast();
          when(() => mockAuthBloc.stream).thenAnswer((_) => stateController.stream);

          await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
          await tester.pump();

          // Act - Emit error state
          stateController.add(const AuthError(errorMessage));
          await tester.pump(); // Trigger BlocListener
          await tester.pump(); // Build dialog

          // Assert
          expect(find.byType(AlertDialog), findsOneWidget);
          expect(find.text(AppMessages.authFailedGeneric), findsOneWidget);
          expect(find.text(errorMessage), findsOneWidget);
          expect(find.text(AppMessages.goBack), findsOneWidget);

          // Cleanup
          await stateController.close();
        });

    testWidgets('should show different error messages correctly',
            (tester) async {
          const errors = [
            'Network error',
            'Invalid credentials',
            'Account disabled',
          ];

          for (final error in errors) {
            when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
            final controller = StreamController<AuthState>.broadcast();
            when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

            await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
            await tester.pump();

            controller.add(AuthError(error));
            await tester.pump();
            await tester.pump();

            expect(find.text(error), findsOneWidget);

            // Close dialog
            await tester.tap(find.text(AppMessages.goBack));
            await tester.pumpAndSettle();

            await controller.close();
          }
        });

    testWidgets('should close error dialog when dismissed', (tester) async {
      // Arrange
      const errorMessage = 'Network error';
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final stateController = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => stateController.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      // Show error dialog
      stateController.add(const AuthError(errorMessage));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);

      // Act - Tap "Go Back" button
      await tester.tap(find.text(AppMessages.goBack));
      await tester.pumpAndSettle();

      // Assert - Dialog should be closed
      expect(find.byType(AlertDialog), findsNothing);

      // Cleanup
      await stateController.close();
    });

    testWidgets('should close dialog on back button press', (tester) async {
      const errorMessage = 'Error';
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      controller.add(const AuthError(errorMessage));
      await tester.pump();
      await tester.pump();

      // Simulate back button
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);

      await controller.close();
    });

    testWidgets('should navigate to home when AuthAuthenticated state emitted',
            (tester) async {
          // Arrange
          final mockUser = createMockUser();
          when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
          when(() => mockGoRouter.go(any())).thenAnswer((_) async {});

          final stateController = StreamController<AuthState>.broadcast();
          when(() => mockAuthBloc.stream).thenAnswer((_) => stateController.stream);

          await tester.pumpWidget(
            createTestableWidget(
              authBloc: mockAuthBloc,
              goRouter: mockGoRouter,
            ),
          );
          await tester.pump();

          // Act - Emit authenticated state
          stateController.add(AuthAuthenticated(mockUser));
          await tester.pump();

          // Assert - Should call navigation
          verify(() => mockGoRouter.go(any())).called(1);

          // Cleanup
          await stateController.close();
        });

    testWidgets('should handle first login correctly', (tester) async {
      final mockUser = createMockUser();
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockGoRouter.go(any())).thenAnswer((_) async {});

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(
        createTestableWidget(authBloc: mockAuthBloc, goRouter: mockGoRouter),
      );
      await tester.pump();

      // Test with isFirstLogin = true
      controller.add(AuthAuthenticated(mockUser, isFirstLogin: true));
      await tester.pump();

      verify(() => mockGoRouter.go(any())).called(1);

      await controller.close();
    });
  });

  group('LoginPage - User Interactions', () {
    testWidgets('should send AuthSignInGoogle event when button is tapped',
            (tester) async {
          // Set reasonable screen size
          tester.view.physicalSize = const Size(800, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          // Arrange
          when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
          when(() => mockAuthBloc.add(any())).thenReturn(null);

          await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
          await tester.pumpAndSettle();

          // Act - Tap the sign-in button
          await tester.tap(find.text('Continue with Google'));
          await tester.pump();

          // Assert - Verify event was sent to BLoC
          verify(() => mockAuthBloc.add(const AuthSignInGoogle())).called(1);
        });

    testWidgets('should show button press animation on tap', (tester) async {
      // Set reasonable screen size
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Arrange
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockAuthBloc.add(any())).thenReturn(null);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      // Find the button
      final buttonFinder = find.text('Continue with Google');
      expect(buttonFinder, findsOneWidget);

      // Act - Start pressing (but don't release)
      final gesture = await tester.startGesture(
        tester.getCenter(buttonFinder),
      );
      await tester.pump();

      // Assert - No errors occurred during animation
      expect(find.text('Continue with Google'), findsOneWidget);

      // Release
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('should not allow button tap when in loading state',
            (tester) async {
          // Arrange
          when(() => mockAuthBloc.state).thenReturn(const AuthLoading());
          when(() => mockAuthBloc.add(any())).thenReturn(null);

          await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));

          // Assert - Button should not be present
          expect(find.text('Continue with Google'), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);

          // Verify no events were sent
          verifyNever(() => mockAuthBloc.add(any()));
        });
  });

  group('LoginPage - Animation Tests', () {
    testWidgets('should complete entrance animations without errors',
            (tester) async {
          // Set reasonable screen size
          tester.view.physicalSize = const Size(800, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          // Arrange
          await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));

          // Act - Pump through animations
          await tester.pump(); // Initial frame
          await tester.pump(const Duration(milliseconds: 200)); // Fast duration
          await tester.pump(const Duration(milliseconds: 800)); // Slow duration
          await tester.pumpAndSettle(); // Complete all animations

          // Assert - No errors during animation
          expect(find.text('Papercraft'), findsOneWidget);
        });

    testWidgets('should dispose animation controllers properly',
            (tester) async {
          // Set reasonable screen size
          tester.view.physicalSize = const Size(800, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          // Arrange
          await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
          await tester.pumpAndSettle();

          // Act - Remove widget from tree (triggers dispose)
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();

          // Assert - No memory leak errors (test completes successfully)
          expect(find.byType(LoginPage), findsNothing);
        });
  });

  group('LoginPage - Edge Cases', () {
    testWidgets('should handle tablet screens without overflow', (tester) async {
      // Arrange - Tablet screen
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      // Assert - Should render without overflow
      expect(find.text('Papercraft'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      // Reset
      addTearDown(tester.view.reset);
    });

    testWidgets('should handle rapid state changes gracefully', (tester) async {
      // Arrange
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      // Use broadcast stream
      final stateController = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => stateController.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      // Act - Rapid state changes
      stateController.add(const AuthLoading());
      await tester.pump();

      stateController.add(const AuthInitial());
      await tester.pump();

      // Assert - Should handle gracefully
      expect(find.text('Continue with Google'), findsOneWidget);

      // Cleanup
      await stateController.close();
    });

    testWidgets('should handle Google icon loading error gracefully',
            (tester) async {
          // Set reasonable screen size
          tester.view.physicalSize = const Size(800, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          // Arrange
          await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
          await tester.pumpAndSettle();

          // The Image.network will fail in tests, but errorBuilder should handle it
          // Assert - Page should still render
          expect(find.text('Continue with Google'), findsOneWidget);
        });
  });

  group('LoginPage - Accessibility', () {
    testWidgets('should have proper semantics for screen readers',
            (tester) async {
          // Set reasonable screen size
          tester.view.physicalSize = const Size(800, 600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          // Arrange
          await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
          await tester.pumpAndSettle();

          // Assert - Check key text is present for screen readers
          expect(find.text('Papercraft'), findsOneWidget);
          expect(find.text('Continue with Google'), findsOneWidget);

          // Verify tappable button exists
          final buttonFinder = find.widgetWithText(InkWell, 'Continue with Google');
          expect(buttonFinder, findsOneWidget);
        });
  });
}