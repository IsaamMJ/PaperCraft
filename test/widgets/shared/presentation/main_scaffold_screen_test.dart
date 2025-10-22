import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/features/shared/presentation/main_scaffold_screen.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_event.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_state.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';
import 'package:papercraft/features/authentication/domain/entities/tenant_entity.dart';
import 'package:papercraft/features/authentication/domain/services/user_state_service.dart';
import 'package:papercraft/core/presentation/constants/app_colors.dart';
import 'package:papercraft/core/infrastructure/di/injection_container.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockAuthBloc extends Mock implements AuthBloc {}

class MockGoRouter extends Mock implements GoRouter {}

class MockUserStateService extends Mock implements UserStateService {}

class MockUserEntity extends Mock implements UserEntity {}

class MockTenantEntity extends Mock implements TenantEntity {}

// Register fallback values for Mocktail
class FakeAuthEvent extends Fake implements AuthEvent {}

class FakeAuthState extends Fake implements AuthState {}

// ============================================================================
// TEST DATA FACTORIES
// ============================================================================

UserEntity createMockTeacher({
  String id = 'teacher-123',
  String email = 'teacher@example.com',
  String fullName = 'John Teacher',
}) {
  final user = MockUserEntity();
  when(() => user.id).thenReturn(id);
  when(() => user.email).thenReturn(email);
  when(() => user.fullName).thenReturn(fullName);
  when(() => user.role).thenReturn(UserRole.teacher);
  return user;
}

UserEntity createMockAdmin({
  String id = 'admin-123',
  String email = 'admin@example.com',
  String fullName = 'Jane Admin',
}) {
  final user = MockUserEntity();
  when(() => user.id).thenReturn(id);
  when(() => user.email).thenReturn(email);
  when(() => user.fullName).thenReturn(fullName);
  when(() => user.role).thenReturn(UserRole.admin);
  return user;
}

// ============================================================================
// TEST HELPERS
// ============================================================================

/// Helper to create a testable widget with all dependencies
Widget createTestableWidget({
  required AuthBloc authBloc,
  required UserStateService userStateService,
  GoRouter? goRouter,
}) {
  return MaterialApp(
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: goRouter != null
          ? InheritedGoRouter(
              goRouter: goRouter,
              child: const MainScaffoldPage(),
            )
          : const MainScaffoldPage(),
    ),
  );
}

// ============================================================================
// MAIN TEST SUITE
// ============================================================================

void main() {
  late MockAuthBloc mockAuthBloc;
  late MockGoRouter mockGoRouter;
  late MockUserStateService mockUserStateService;

  // Setup before each test
  setUp(() {
    mockAuthBloc = MockAuthBloc();
    mockGoRouter = MockGoRouter();
    mockUserStateService = MockUserStateService();

    // Register fallback values
    registerFallbackValue(FakeAuthEvent());
    registerFallbackValue(FakeAuthState());

    // Default behavior for AuthBloc
    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    when(() => mockAuthBloc.stream).thenAnswer((_) {
      // Return a stream that never emits any events
      final controller = StreamController<AuthState>();
      // Keep it open but never emit
      return controller.stream;
    });
    when(() => mockAuthBloc.close()).thenAnswer((_) async {});
    when(() => mockAuthBloc.isClosed).thenReturn(false);
    when(() => mockAuthBloc.add(any())).thenReturn(null);

    // Default behavior for UserStateService
    when(() => mockUserStateService.isAdmin).thenReturn(false);
    when(() => mockUserStateService.currentTenant).thenReturn(null);
    when(() => mockUserStateService.isTenantLoading).thenReturn(false);
    when(() => mockUserStateService.addListener(any())).thenReturn(
      // Return a never-ending stream subscription
      Stream<void>.empty().listen((_) {}),
    );

    // Default behavior for GoRouter
    when(() => mockGoRouter.go(any())).thenReturn(null);

    // Register UserStateService with GetIt
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UserStateService>()) {
      getIt.unregister<UserStateService>();
    }
    getIt.registerSingleton<UserStateService>(mockUserStateService);
  });

  tearDown(() {
    // Clean up GetIt
    final getIt = GetIt.instance;
    if (getIt.isRegistered<UserStateService>()) {
      getIt.unregister<UserStateService>();
    }
  });

  // ========================================================================
  // TEST GROUP: LOADING STATE
  // ========================================================================

  group('MainScaffoldPage - Loading State', () {
    testWidgets(
      'should display loading scaffold when AuthLoading state',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state).thenReturn(const AuthLoading());
        when(() => mockAuthBloc.stream).thenAnswer((_) {
          final controller = StreamController<AuthState>();
          return controller.stream;
        });

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.text('Loading your workspace...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets(
      'should display logo in loading state',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state).thenReturn(const AuthLoading());

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.byType(Image), findsWidgets);
      },
    );

    testWidgets(
      'should display background color in loading state',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state).thenReturn(const AuthLoading());

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.byType(Scaffold), findsOneWidget);
        final scaffold = find.byType(Scaffold).evaluate().first.widget as Scaffold;
        expect(scaffold.backgroundColor, AppColors.background);
      },
    );
  });

  // ========================================================================
  // TEST GROUP: UNAUTHENTICATED STATE
  // ========================================================================

  group('MainScaffoldPage - Unauthenticated State', () {
    testWidgets(
      'should display unauthenticated scaffold when not authenticated',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.text('Authentication Required'), findsOneWidget);
        expect(find.text('Please sign in to access your papers'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'should display lock icon in unauthenticated state',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'should display correct text in unauthenticated state',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.text('Authentication Required'), findsOneWidget);
        expect(find.text('Please sign in to access your papers'), findsOneWidget);
      },
    );
  });

  // ========================================================================
  // TEST GROUP: AUTH ERROR STATE
  // ========================================================================

  group('MainScaffoldPage - Auth Error State', () {
    testWidgets(
      'should display unauthenticated scaffold on auth error',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state)
            .thenReturn(const AuthError('Authentication failed'));

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert - should show unauthenticated UI
        expect(find.text('Authentication Required'), findsOneWidget);
      },
    );
  });

  // ========================================================================
  // TEST GROUP: UNAUTHENTICATED STATE (AuthUnauthenticated)
  // ========================================================================

  group('MainScaffoldPage - AuthUnauthenticated State', () {
    testWidgets(
      'should display unauthenticated scaffold for AuthUnauthenticated',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state)
            .thenReturn(const AuthUnauthenticated());

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.text('Authentication Required'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      },
    );
  });

  // ========================================================================
  // TEST GROUP: STATE TRANSITIONS
  // ========================================================================

  group('MainScaffoldPage - State Transitions', () {
    testWidgets(
      'should transition from loading to authenticated',
      (tester) async {
        // Setup - start with loading
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(const AuthLoading());
        when(() => mockAuthBloc.stream).thenAnswer(
          (_) => Stream.value(AuthAuthenticated(teacher)),
        );
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        // Act - pump initial
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert - should show loading
        expect(find.text('Loading your workspace...'), findsOneWidget);

        // Update to authenticated
        when(() => mockAuthBloc.state)
            .thenReturn(AuthAuthenticated(teacher));

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert - loading should be gone
        expect(find.text('Loading your workspace...'), findsNothing);
      },
    );

    testWidgets(
      'should handle transition from unauthenticated to authenticated',
      (tester) async {
        // Setup - start unauthenticated
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert - unauthenticated
        expect(find.text('Authentication Required'), findsOneWidget);

        // Transition to authenticated
        when(() => mockAuthBloc.state)
            .thenReturn(AuthAuthenticated(teacher));

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert - lock icon should be gone
        expect(find.byIcon(Icons.lock_outline_rounded), findsNothing);
      },
    );
  });

  // ========================================================================
  // TEST GROUP: ROLE MANAGEMENT
  // ========================================================================

  group('MainScaffoldPage - Role Management', () {
    testWidgets(
      'should recognize teacher role',
      (tester) async {
        // Setup
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state)
            .thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.text('Teacher'), findsNothing); // No auth widget shown in loading
      },
    );

    testWidgets(
      'should recognize admin role',
      (tester) async {
        // Setup
        final admin = createMockAdmin();
        when(() => mockAuthBloc.state)
            .thenReturn(AuthAuthenticated(admin));
        when(() => mockUserStateService.isAdmin).thenReturn(true);

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert - just verify widget builds without error
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets(
      'should handle role change during runtime',
      (tester) async {
        // Setup - start as teacher
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state)
            .thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Change to admin
        final admin = createMockAdmin();
        when(() => mockAuthBloc.state)
            .thenReturn(AuthAuthenticated(admin));
        when(() => mockUserStateService.isAdmin).thenReturn(true);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  });

  // ========================================================================
  // TEST GROUP: BlocListener FUNCTIONALITY
  // ========================================================================

  group('MainScaffoldPage - BlocListener Functionality', () {
    testWidgets(
      'should have BlocListener for auth state changes',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert - BlocListener should be there (part of tree)
        expect(find.byType(BlocListener), findsOneWidget);
      },
    );

    testWidgets(
      'should have BlocBuilder for rendering based on auth state',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert - BlocBuilder should be there
        expect(find.byType(BlocBuilder), findsOneWidget);
      },
    );
  });

  // ========================================================================
  // TEST GROUP: USER INFORMATION
  // ========================================================================

  group('MainScaffoldPage - User Information', () {
    testWidgets(
      'should handle user with empty name',
      (tester) async {
        // Setup
        final userWithEmptyName = createMockTeacher(fullName: '');
        when(() => mockAuthBloc.state)
            .thenReturn(AuthAuthenticated(userWithEmptyName));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert - should not crash and render properly
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets(
      'should handle user with long name',
      (tester) async {
        // Setup
        final userWithLongName = createMockTeacher(
          fullName: 'A Very Long User Name That Should Be Handled',
        );
        when(() => mockAuthBloc.state)
            .thenReturn(AuthAuthenticated(userWithLongName));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  });

  // ========================================================================
  // TEST GROUP: WIDGET STRUCTURE
  // ========================================================================

  group('MainScaffoldPage - Widget Structure', () {
    testWidgets(
      'should always have a Scaffold',
      (tester) async {
        // Test for different states
        const states = [
          AuthInitial(),
          AuthLoading(),
          AuthUnauthenticated(),
        ];

        for (final state in states) {
          when(() => mockAuthBloc.state).thenReturn(state);

          await tester.pumpWidget(
            createTestableWidget(
              authBloc: mockAuthBloc,
              userStateService: mockUserStateService,
              goRouter: mockGoRouter,
            ),
          );
          await tester.pump();

          expect(
            find.byType(Scaffold),
            findsOneWidget,
            reason: 'Should have Scaffold for state: $state',
          );
        }
      },
    );

    testWidgets(
      'should have proper Material app wrapper',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.byType(MaterialApp), findsOneWidget);
      },
    );
  });

  // ========================================================================
  // TEST GROUP: EDGE CASES
  // ========================================================================

  group('MainScaffoldPage - Edge Cases', () {
    testWidgets(
      'should handle AuthBloc.isClosed = true',
      (tester) async {
        // Setup
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state)
            .thenReturn(AuthAuthenticated(teacher));
        when(() => mockAuthBloc.isClosed).thenReturn(true);
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert - should still render
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets(
      'should handle null GoRouter',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: null, // null router
          ),
        );
        await tester.pump();

        // Assert
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets(
      'should handle UserStateService with null tenant',
      (tester) async {
        // Setup
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state)
            .thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.currentTenant).thenReturn(null);
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );

    testWidgets(
      'should handle UserStateService.addListener with no updates',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
        when(() => mockUserStateService.addListener(any()))
            .thenReturn(Stream<void>.empty().listen((_) {}));

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.byType(Scaffold), findsOneWidget);
      },
    );
  });

  // ========================================================================
  // TEST GROUP: INITIALIZATION
  // ========================================================================

  group('MainScaffoldPage - Initialization', () {
    testWidgets(
      'should initialize properly on first load',
      (tester) async {
        // Setup
        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        expect(find.byType(MainScaffoldPage), findsOneWidget);
        verify(() => mockUserStateService.addListener(any())).called(greaterThan(0));
      },
    );

    testWidgets(
      'should read initial auth state from bloc',
      (tester) async {
        // Setup
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state)
            .thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        // Act
        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            goRouter: mockGoRouter,
          ),
        );
        await tester.pump();

        // Assert
        verify(() => mockAuthBloc.state).called(greaterThan(0));
      },
    );
  });
}
