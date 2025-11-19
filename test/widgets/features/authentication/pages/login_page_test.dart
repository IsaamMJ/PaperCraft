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
    when(() => mockAuthBloc.close()).thenAnswer((_) async {});
  });

  group('LoginPage - Widget Rendering', () {
    testWidgets('should render all key UI elements', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Papercraft'), findsOneWidget);
      // Text wrapping is now handled by softWrap: true, so check substring
      expect(
        find.text('Create, organize, and manage your question papers easily'),
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

    testWidgets('should display logo container with gradient', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);

      final containers = tester.widgetList<Container>(containerFinder);
      final hasGradientContainer = containers.any((container) {
        final decoration = container.decoration;
        return decoration is BoxDecoration && decoration.gradient != null;
      });
      expect(hasGradientContainer, isTrue);
    });

    testWidgets('should display supporting provider message', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(
        find.text('Currently supporting Google sign-in.\nMore providers coming soon.'),
        findsOneWidget,
      );
    });

    testWidgets('should handle tablet screen size without overflow', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Papercraft'), findsOneWidget);
      addTearDown(tester.view.reset);
    });

    testWidgets('should handle small mobile screens without overflow', (tester) async {
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

      // Desktop layout has 2-column design with different hero text
      expect(find.text('Manage Question Papers\nwith Ease'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      addTearDown(tester.view.reset);
    });

    testWidgets('should handle landscape orientation', (tester) async {
      tester.view.physicalSize = const Size(667, 375);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      addTearDown(tester.view.reset);
    });

    testWidgets('should handle very short screens with compact layout', (tester) async {
      tester.view.physicalSize = const Size(375, 550);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Papercraft'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      addTearDown(tester.view.reset);
    });

    testWidgets('should handle very wide desktop screens', (tester) async {
      tester.view.physicalSize = const Size(2560, 1440);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      addTearDown(tester.view.reset);
    });
  });

  group('LoginPage - BLoC State Handling', () {
    testWidgets('should show sign-in button in AuthInitial state', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('should show sign-in button in AuthUnauthenticated state', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      when(() => mockAuthBloc.state).thenReturn(const AuthUnauthenticated());

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('should show loading indicator in AuthLoading state', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthLoading());

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(AppMessages.processingAuth), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('should show error dialog when AuthError state is emitted', (tester) async {
      const errorMessage = 'Sign-in failed. Please try again.';
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final stateController = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => stateController.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      stateController.add(const AuthError(errorMessage));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(AppMessages.authFailedGeneric), findsOneWidget);
      expect(find.text(errorMessage), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await stateController.close();
    });

    testWidgets('should show network error message', (tester) async {
      const errorMessage = 'Network error';
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      controller.add(const AuthError(errorMessage));
      await tester.pump();
      await tester.pump();

      expect(find.text(errorMessage), findsOneWidget);
      await controller.close();
    });

    testWidgets('should show session expired error message', (tester) async {
      const errorMessage = AppMessages.sessionExpired;
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      controller.add(const AuthError(errorMessage));
      await tester.pump();
      await tester.pump();

      expect(find.text(errorMessage), findsOneWidget);
      await controller.close();
    });

    testWidgets('should show account deactivated error message', (tester) async {
      const errorMessage = AppMessages.accountDeactivated;
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      controller.add(const AuthError(errorMessage));
      await tester.pump();
      await tester.pump();

      expect(find.text(errorMessage), findsOneWidget);
      await controller.close();
    });

    testWidgets('should show unauthorized organization error', (tester) async {
      const errorMessage = AppMessages.organizationNotAuthorized;
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      controller.add(const AuthError(errorMessage));
      await tester.pump();
      await tester.pump();

      expect(find.text(errorMessage), findsOneWidget);
      await controller.close();
    });

    testWidgets('should close error dialog when Try Again button tapped', (tester) async {
      const errorMessage = 'Network error';
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final stateController = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => stateController.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      stateController.add(const AuthError(errorMessage));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      await stateController.close();
    });

    testWidgets('should dismiss error dialog by tapping outside (barrierDismissible)', (tester) async {
      const errorMessage = 'Error occurred';
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      controller.add(const AuthError(errorMessage));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);

      // Tap outside the dialog (on the barrier)
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      await controller.close();
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

      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      await controller.close();
    });

    testWidgets('should handle multiple error emissions (second error while first dialog open)', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      // First error
      controller.add(const AuthError('First error'));
      await tester.pump();
      await tester.pump();

      expect(find.text('First error'), findsOneWidget);

      // Second error while first dialog is open
      controller.add(const AuthError('Second error'));
      await tester.pump();
      await tester.pump();

      // Should show second error (new dialog on top)
      expect(find.text('Second error'), findsOneWidget);

      await controller.close();
    });

    testWidgets('should navigate to home when AuthAuthenticated state emitted', (tester) async {
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

      stateController.add(AuthAuthenticated(mockUser));
      await tester.pump();

      verify(() => mockGoRouter.go(any())).called(1);
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

      controller.add(AuthAuthenticated(mockUser, isFirstLogin: true));
      await tester.pump();

      verify(() => mockGoRouter.go(any())).called(1);
      await controller.close();
    });

    testWidgets('should handle AuthAuthenticated without GoRouter gracefully', (tester) async {
      final mockUser = createMockUser();
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      // No goRouter provided
      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      // This should not crash even without goRouter
      controller.add(AuthAuthenticated(mockUser));
      await tester.pump();

      // Widget should still be in tree
      expect(find.byType(LoginPage), findsOneWidget);
      await controller.close();
    });
  });

  group('LoginPage - User Interactions', () {
    testWidgets('should send AuthSignInGoogle event when button is tapped', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockAuthBloc.add(any())).thenReturn(null);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      verify(() => mockAuthBloc.add(const AuthSignInGoogle())).called(1);
    });

    testWidgets('should handle rapid button taps without duplicate events', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockAuthBloc.add(any())).thenReturn(null);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      final buttonFinder = find.text('Continue with Google');

      // Rapid taps - only first tap goes through due to 1-second debounce
      await tester.tap(buttonFinder);
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(buttonFinder); // Blocked by debounce
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(buttonFinder); // Blocked by debounce
      await tester.pump(const Duration(milliseconds: 10));

      // Only 1 event sent due to UI-level debouncing (1s cooldown prevents duplicate events)
      verify(() => mockAuthBloc.add(const AuthSignInGoogle())).called(1);
    });

    testWidgets('should show button press animation on tap', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockAuthBloc.add(any())).thenReturn(null);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      final buttonFinder = find.text('Continue with Google');
      expect(buttonFinder, findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(buttonFinder),
      );
      await tester.pump();

      expect(find.text('Continue with Google'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('should handle tap cancel properly', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockAuthBloc.add(any())).thenReturn(null);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      final buttonFinder = find.text('Continue with Google');
      final gesture = await tester.startGesture(tester.getCenter(buttonFinder));
      await tester.pump();

      // Move away to cancel
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();

      // Should not trigger sign-in
      verifyNever(() => mockAuthBloc.add(any()));
    });

    testWidgets('should not allow button tap when in loading state', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthLoading());
      when(() => mockAuthBloc.add(any())).thenReturn(null);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Continue with Google'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      verifyNever(() => mockAuthBloc.add(any()));
    });

    testWidgets('should handle button tap during rapid state changes', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockAuthBloc.add(any())).thenReturn(null);

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      // Tap button
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      // Rapid state changes
      controller.add(const AuthLoading());
      await tester.pump();
      controller.add(const AuthInitial());
      await tester.pump();
      controller.add(const AuthLoading());
      await tester.pump();

      // Should handle gracefully
      expect(find.byType(LoginPage), findsOneWidget);
      await controller.close();
    });
  });

  group('LoginPage - Animation Tests', () {
    testWidgets('should complete entrance animations without errors', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();

      expect(find.text('Papercraft'), findsOneWidget);
    });

    testWidgets('should handle animation timer cleanup on early dispose', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));

      // Dispose before animation timer fires
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('should dispose animation controllers properly', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('should handle dispose during active animation', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump(const Duration(milliseconds: 500));

      // Dispose while animation is running
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(find.byType(LoginPage), findsNothing);
    });
  });

  group('LoginPage - Edge Cases', () {
    testWidgets('should handle rapid state changes gracefully', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final stateController = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => stateController.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      stateController.add(const AuthLoading());
      await tester.pump();

      stateController.add(const AuthInitial());
      await tester.pump();

      stateController.add(const AuthUnauthenticated());
      await tester.pump();

      expect(find.text('Continue with Google'), findsOneWidget);
      await stateController.close();
    });

    testWidgets('should handle Google icon loading error gracefully', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      // Image.network will fail in tests, errorBuilder shows fallback icon
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byIcon(Icons.g_mobiledata), findsOneWidget);
    });

    testWidgets('should handle state emission during widget dispose', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      // Start disposing widget
      await tester.pumpWidget(const SizedBox.shrink());

      // Emit state during dispose
      controller.add(const AuthError('Error during dispose'));
      await tester.pump();

      // Should not crash
      expect(find.byType(LoginPage), findsNothing);
      await controller.close();
    });

    testWidgets('should handle transition from error to loading state', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      // Show error
      controller.add(const AuthError('First error'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);

      // Transition to loading (user retried)
      controller.add(const AuthLoading());
      await tester.pump();
      await tester.pump();

      // Dialog should be dismissed, loading should show
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await controller.close();
    });

    testWidgets('should handle AuthError with empty message', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      controller.add(const AuthError(''));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(AppMessages.authFailedGeneric), findsOneWidget);
      await controller.close();
    });

    testWidgets('should handle very long error messages', (tester) async {
      const longError = 'This is a very long error message that should still display properly in the dialog without causing any overflow or rendering issues in the UI';
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      controller.add(const AuthError(longError));
      await tester.pump();
      await tester.pump();

      expect(find.text(longError), findsOneWidget);
      await controller.close();
    });

    testWidgets('should handle multiple AuthAuthenticated emissions', (tester) async {
      final mockUser1 = createMockUser(id: 'user-1');
      final mockUser2 = createMockUser(id: 'user-2');

      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockGoRouter.go(any())).thenAnswer((_) async {});

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(
        createTestableWidget(authBloc: mockAuthBloc, goRouter: mockGoRouter),
      );
      await tester.pump();

      controller.add(AuthAuthenticated(mockUser1));
      await tester.pump();

      controller.add(AuthAuthenticated(mockUser2));
      await tester.pump();

      // Should navigate twice
      verify(() => mockGoRouter.go(any())).called(2);
      await controller.close();
    });

    testWidgets('should handle bloc disposed while widget is active', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockAuthBloc.add(any())).thenReturn(null);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      // Simulate bloc being disposed
      when(() => mockAuthBloc.state).thenThrow(StateError('Bloc disposed'));

      // Try to tap button
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      // Should handle gracefully
      expect(find.byType(LoginPage), findsOneWidget);
    });
  });

  group('LoginPage - Accessibility', () {
    testWidgets('should have proper semantics for screen readers', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Papercraft'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      final buttonFinder = find.widgetWithText(InkWell, 'Continue with Google');
      expect(buttonFinder, findsOneWidget);
    });

    testWidgets('should have tappable button with proper area', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockAuthBloc.add(any())).thenReturn(null);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      final buttonFinder = find.text('Continue with Google');
      final buttonSize = tester.getSize(buttonFinder.first);

      // Button should have reasonable tap target size
      expect(buttonSize.height, greaterThan(48));

      await tester.tap(buttonFinder);
      await tester.pump();

      verify(() => mockAuthBloc.add(const AuthSignInGoogle())).called(1);
    });

    testWidgets('should maintain contrast ratios for text', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      // Verify key text elements are visible
      expect(find.text('Papercraft'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(
        find.text('By continuing, you agree to our Terms of Service\nand Privacy Policy'),
        findsOneWidget,
      );
    });
  });

  group('LoginPage - Integration Scenarios', () {
    testWidgets('should handle complete sign-in flow', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final mockUser = createMockUser();
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockAuthBloc.add(any())).thenReturn(null);
      when(() => mockGoRouter.go(any())).thenAnswer((_) async {});

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(
        createTestableWidget(authBloc: mockAuthBloc, goRouter: mockGoRouter),
      );
      await tester.pumpAndSettle();

      // 1. User taps sign-in button
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      verify(() => mockAuthBloc.add(const AuthSignInGoogle())).called(1);

      // 2. Loading state
      controller.add(const AuthLoading());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 3. Success - Authenticated
      controller.add(AuthAuthenticated(mockUser));
      await tester.pump();

      verify(() => mockGoRouter.go(any())).called(1);

      await controller.close();
    });

    testWidgets('should handle sign-in failure and retry', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockAuthBloc.add(any())).thenReturn(null);

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      // 1. First attempt - tap button
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      // 2. Loading
      controller.add(const AuthLoading());
      await tester.pump();

      // 3. Error
      controller.add(const AuthError('Network error'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);

      // 4. Dismiss error by tapping Try Again button
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      // 5. Back to initial state
      controller.add(const AuthInitial());
      await tester.pump();

      // 6. Retry
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      verify(() => mockAuthBloc.add(const AuthSignInGoogle())).called(2);

      await controller.close();
    });

    testWidgets('should handle authentication during loading state correctly', (tester) async {
      final mockUser = createMockUser();
      when(() => mockAuthBloc.state).thenReturn(const AuthLoading());
      when(() => mockGoRouter.go(any())).thenAnswer((_) async {});

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(
        createTestableWidget(authBloc: mockAuthBloc, goRouter: mockGoRouter),
      );
      await tester.pump();

      // Start in loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Transition to authenticated
      controller.add(AuthAuthenticated(mockUser));
      await tester.pump();

      verify(() => mockGoRouter.go(any())).called(1);

      await controller.close();
    });

    testWidgets('should handle error during loading correctly', (tester) async {
      when(() => mockAuthBloc.state).thenReturn(const AuthLoading());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Error occurs
      controller.add(const AuthError('Authentication failed'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await controller.close();
    });

    testWidgets('should handle multiple navigation attempts', (tester) async {
      final mockUser = createMockUser();
      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
      when(() => mockGoRouter.go(any())).thenAnswer((_) async {});

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(
        createTestableWidget(authBloc: mockAuthBloc, goRouter: mockGoRouter),
      );
      await tester.pump();

      // Emit authenticated multiple times rapidly
      controller.add(AuthAuthenticated(mockUser));
      await tester.pump();

      controller.add(AuthAuthenticated(mockUser));
      await tester.pump();

      controller.add(AuthAuthenticated(mockUser));
      await tester.pump();

      // Should attempt navigation each time
      verify(() => mockGoRouter.go(any())).called(3);

      await controller.close();
    });
  });

  group('LoginPage - Memory and Performance', () {
    testWidgets('should not leak memory on repeated mount/unmount', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (int i = 0; i < 5; i++) {
        await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
        await tester.pump();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }

      // Should complete without memory issues
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('should handle rapid rebuild cycles', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

      final controller = StreamController<AuthState>.broadcast();
      when(() => mockAuthBloc.stream).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));

      // Rapid rebuilds
      for (int i = 0; i < 10; i++) {
        await tester.pump();
      }

      expect(find.text('Papercraft'), findsOneWidget);

      await controller.close();
    });

    testWidgets('should clean up all resources on dispose', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      // Remove widget
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpAndSettle();

      // Verify bloc wasn't closed by the widget (it's provided externally)
      verifyNever(() => mockAuthBloc.close());

      expect(find.byType(LoginPage), findsNothing);
    });
  });

  group('LoginPage - Responsive Layout Breakpoints', () {
    testWidgets('should use mobile layout for screens < 600', (tester) async {
      tester.view.physicalSize = const Size(599, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Papercraft'), findsOneWidget);
    });

    testWidgets('should use tablet layout for screens >= 600 and < 1024', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Papercraft'), findsOneWidget);
    });

    testWidgets('should use desktop layout for screens >= 1024', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      // Desktop layout has different hero text on the left
      expect(find.text('Manage Question Papers\nwith Ease'), findsOneWidget);
      // Sign In header on the right
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('should handle transition between breakpoints', (tester) async {
      // Start mobile
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createTestableWidget(authBloc: mockAuthBloc));
      await tester.pumpAndSettle();

      expect(find.text('Papercraft'), findsOneWidget);

      // Transition to tablet (still mobile layout)
      tester.view.physicalSize = const Size(800, 1024);
      await tester.pumpAndSettle();

      expect(find.text('Papercraft'), findsOneWidget);

      // Transition to desktop (2-column layout)
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpAndSettle();

      // Desktop layout has different hero text
      expect(find.text('Manage Question Papers\nwith Ease'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);

      addTearDown(tester.view.reset);
    });
  });
}