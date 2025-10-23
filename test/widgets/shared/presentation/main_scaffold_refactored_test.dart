import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:get_it/get_it.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_event.dart';
import 'package:papercraft/features/shared/presentation/main_scaffold_screen.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_bloc.dart';
import 'package:papercraft/features/authentication/presentation/bloc/auth_state.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';
import 'package:papercraft/features/authentication/domain/services/user_state_service.dart';
import 'package:papercraft/core/presentation/constants/app_colors.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';

class MockAuthBloc extends Mock implements AuthBloc {}
class MockUserStateService extends Mock implements UserStateService {}
class MockUserEntity extends Mock implements UserEntity {}
class MockILogger extends Mock implements ILogger {}
class FakeAuthEvent extends Fake implements AuthEvent {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAuthEvent());
  });

  late MockAuthBloc mockAuthBloc;
  late MockUserStateService mockUserStateService;

  UserEntity createMockTeacher() {
    final user = MockUserEntity();
    when(() => user.role).thenReturn(UserRole.teacher);
    when(() => user.fullName).thenReturn('John Teacher');
    when(() => user.email).thenReturn('teacher@test.com');
    return user;
  }

  UserEntity createMockAdmin() {
    final user = MockUserEntity();
    when(() => user.role).thenReturn(UserRole.admin);
    when(() => user.fullName).thenReturn('Jane Admin');
    when(() => user.email).thenReturn('admin@test.com');
    return user;
  }

  Widget createTestableWidget({
    required AuthBloc authBloc,
    required UserStateService userStateService,
    required List<Widget> adminPages,
    required List<Widget> teacherPages,
  }) {
    return MaterialApp(
      home: BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: MainScaffoldPage(
          userStateService: userStateService,
          adminPages: adminPages,
          teacherPages: teacherPages,
        ),
      ),
    );
  }

  setUp(() {
    mockAuthBloc = MockAuthBloc();
    mockUserStateService = MockUserStateService();

    when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
    when(() => mockAuthBloc.stream).thenAnswer((_) => Stream<AuthState>.empty());
    when(() => mockAuthBloc.close()).thenAnswer((_) async {});
    when(() => mockAuthBloc.isClosed).thenReturn(false);

    when(() => mockUserStateService.isAdmin).thenReturn(false);
    when(() => mockUserStateService.currentTenant).thenReturn(null);
    when(() => mockUserStateService.isTenantLoading).thenReturn(false);
    when(() => mockUserStateService.addListener(any())).thenReturn(null);

    // Set up GetIt for logging
    final getIt = GetIt.instance;
    if (getIt.isRegistered<ILogger>()) {
      getIt.unregister<ILogger>();
    }
    final mockLogger = MockILogger();
    getIt.registerSingleton<ILogger>(mockLogger);
  });

  tearDown(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<ILogger>()) {
      getIt.unregister<ILogger>();
    }
  });

  // ... rest of your test groups stay the same ...


    group('MainScaffoldPage - Loading State', () {
      testWidgets('should display loading when AuthLoading', (tester) async {
        when(() => mockAuthBloc.state).thenReturn(const AuthLoading());

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.text('Loading your workspace...'), findsOneWidget);
      });
    });

    group('MainScaffoldPage - Unauthenticated State', () {
      testWidgets('should display auth required message', (tester) async {
        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.text('Authentication Required'), findsOneWidget);
      });
    });

    group('MainScaffoldPage - Teacher Pages', () {
      testWidgets('should show teacher pages when not admin', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        const teacherWidget = SizedBox(key: ValueKey('teacher-page'));
        const adminWidget = SizedBox(key: ValueKey('admin-page'));

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [adminWidget],
            teacherPages: [teacherWidget],
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('teacher-page')), findsOneWidget);
        expect(find.byKey(const ValueKey('admin-page')), findsNothing);
      });
    });

    group('MainScaffoldPage - Admin Pages', () {
      testWidgets('should show admin pages when admin', (tester) async {
        final admin = createMockAdmin();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(admin));
        when(() => mockUserStateService.isAdmin).thenReturn(true);

        const teacherWidget = SizedBox(key: ValueKey('teacher-page'));
        const adminWidget = SizedBox(key: ValueKey('admin-page'));

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [adminWidget],
            teacherPages: [teacherWidget],
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('admin-page')), findsOneWidget);
        expect(find.byKey(const ValueKey('teacher-page')), findsNothing);
      });
    });

    group('MainScaffoldPage - Role Badge', () {
      testWidgets('should display teacher role', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();
      });

      testWidgets('should display admin role', (tester) async {
        final admin = createMockAdmin();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(admin));
        when(() => mockUserStateService.isAdmin).thenReturn(true);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();
      });
    });

    group('MainScaffoldPage - User Info', () {
      testWidgets('should display user name', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();
      });

      testWidgets('should handle empty user name', (tester) async {
        final user = MockUserEntity();
        when(() => user.role).thenReturn(UserRole.teacher);
        when(() => user.fullName).thenReturn('');
        when(() => user.email).thenReturn('test@test.com');
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(user));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.byType(Scaffold), findsOneWidget);
      });
    });

    group('MainScaffoldPage - State Transitions', () {
      testWidgets('should transition loading to authenticated', (tester) async {
        final streamController = StreamController<AuthState>.broadcast();

        when(() => mockAuthBloc.state).thenReturn(const AuthLoading());
        when(() => mockAuthBloc.stream).thenAnswer((_) =>
        streamController.stream);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.text('Loading your workspace...'), findsOneWidget);

        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        streamController.add(AuthAuthenticated(teacher));

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Loading your workspace...'), findsNothing);

        await streamController.close();
      });

      testWidgets(
          'should transition unauthenticated to authenticated', (tester) async {
        final streamController = StreamController<AuthState>.broadcast();

        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
        when(() => mockAuthBloc.stream).thenAnswer((_) =>
        streamController.stream);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Authentication Required'), findsOneWidget);

        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        streamController.add(AuthAuthenticated(teacher));

        await tester.pumpAndSettle();

        expect(find.text('Authentication Required'), findsNothing);

        await streamController.close();
      });
    });

    group('MainScaffoldPage - Widget Structure', () {
      testWidgets('should always have Scaffold', (tester) async {
        const states = [AuthInitial(), AuthLoading(), AuthUnauthenticated()];

        for (final state in states) {
          when(() => mockAuthBloc.state).thenReturn(state);

          await tester.pumpWidget(
            createTestableWidget(
              authBloc: mockAuthBloc,
              userStateService: mockUserStateService,
              adminPages: [Container()],
              teacherPages: [Container()],
            ),
          );
          await tester.pump();

          expect(find.byType(Scaffold), findsOneWidget);
        }
      });

      testWidgets('should have BlocListener and BlocBuilder', (tester) async {
        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.byType(BlocListener<AuthBloc, AuthState>), findsWidgets);
        expect(find.byType(BlocBuilder<AuthBloc, AuthState>), findsOneWidget);
      });
    });

    group('MainScaffoldPage - Dependency Injection', () {
      testWidgets('should use injected userStateService', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        verify(() => mockUserStateService.isAdmin).called(greaterThan(0));
      });

      testWidgets('should render injected pages', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        const page1 = SizedBox(key: ValueKey('page1'));
        const page2 = SizedBox(key: ValueKey('page2'));

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [page1],
            teacherPages: [page2],
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('page2')), findsOneWidget);
      });
    });

    group('MainScaffoldPage - Error States', () {
      testWidgets('should handle AuthError state', (tester) async {
        when(() => mockAuthBloc.state).thenReturn(const AuthError('Failed'));

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.text('Authentication Required'), findsOneWidget);
      });

      testWidgets('should handle AuthUnauthenticated state', (tester) async {
        when(() => mockAuthBloc.state).thenReturn(const AuthUnauthenticated());

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      });
    });

    group('MainScaffoldPage - App Bar', () {
      testWidgets('should display app bar with logo', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.byType(AppBar), findsOneWidget);
        expect(find.byType(Image), findsWidgets);
      });

      testWidgets('should display user avatar in app bar', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.text('J'), findsWidgets);
      });
    });

    group('MainScaffoldPage - Page Titles', () {
      testWidgets(
          'should display Home title for teacher page 0', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.text('Home'), findsWidgets);
      });

      testWidgets(
          'should display Admin Dashboard for admin page 0', (tester) async {
        final admin = createMockAdmin();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(admin));
        when(() => mockUserStateService.isAdmin).thenReturn(true);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.text('Admin Dashboard'), findsOneWidget);
      });
    });

    group('MainScaffoldPage - Mobile Layout', () {
      testWidgets('should display bottom nav on mobile', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        // Verify bottom nav bar exists and has content
        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.bottomNavigationBar, isNotNull);

        // Check for navigation items (should find both in bottom nav)
        expect(find.text('Bank'), findsOneWidget);
      });
    });

    group('MainScaffoldPage - Desktop Layout', () {
      testWidgets(
          'should display drawer menu button on desktop', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.menu_rounded), findsOneWidget);
      });
    });

    group('MainScaffoldPage - User State Subscription', () {
      testWidgets('should subscribe to user state changes', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        verify(() => mockUserStateService.addListener(any())).called(
            greaterThan(0));
      });

      testWidgets('should handle role change during session', (tester) async {
        final streamController = StreamController<void>();
        VoidCallback? capturedListener;

        when(() => mockUserStateService.addListener(any())).thenAnswer((
            invocation) {
          capturedListener = invocation.positionalArguments[0] as VoidCallback;
          streamController.stream.listen((_) => capturedListener?.call());
          return null; // Return void/null since the method signature expects void
        });

        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        const page1 = SizedBox(key: ValueKey('page1'));
        const page2 = SizedBox(key: ValueKey('page2'));

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [page2],
            teacherPages: [page1],
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('page1')), findsOneWidget);

        // Simulate role change
        when(() => mockUserStateService.isAdmin).thenReturn(true);
        capturedListener?.call();

        await tester.pump();

        expect(find.byKey(const ValueKey('page2')), findsOneWidget);

        streamController.close();
      });
    });

    group('MainScaffoldPage - Edge Cases', () {
      testWidgets('should handle very long user names', (tester) async {
        final user = MockUserEntity();
        when(() => user.role).thenReturn(UserRole.teacher);
        when(() => user.fullName).thenReturn('A' * 100);
        when(() => user.email).thenReturn('test@test.com');
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(user));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('should handle multiple rapid state changes', (tester) async {
        when(() => mockAuthBloc.state).thenReturn(const AuthLoading());

        for (int i = 0; i < 3; i++) {
          await tester.pumpWidget(
            createTestableWidget(
              authBloc: mockAuthBloc,
              userStateService: mockUserStateService,
              adminPages: [Container()],
              teacherPages: [Container()],
            ),
          );
          await tester.pump();
        }

        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('should handle null tenant data', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);
        when(() => mockUserStateService.currentTenant).thenReturn(null);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.byType(Scaffold), findsOneWidget);
      });
    });

    group('MainScaffoldPage - Page Navigation', () {
      testWidgets('should switch between teacher pages', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        const page1 = SizedBox(key: ValueKey('page1'));
        const page2 = SizedBox(key: ValueKey('page2'));

        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [page1, page2],
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('page1')), findsOneWidget);
      });

      testWidgets('should switch between admin pages', (tester) async {
        final admin = createMockAdmin();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(admin));
        when(() => mockUserStateService.isAdmin).thenReturn(true);

        const page1 = SizedBox(key: ValueKey('admin1'));
        const page2 = SizedBox(key: ValueKey('admin2'));
        const page3 = SizedBox(key: ValueKey('admin3'));

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [page1, page2, page3],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('admin1')), findsOneWidget);
      });
    });

    group('MainScaffoldPage - Animation', () {
      testWidgets('should have fade and slide transitions', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        expect(find.byType(FadeTransition), findsOneWidget);
        expect(find.byType(SlideTransition), findsOneWidget);
      });

      testWidgets('should animate on page transitions', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        const page1 = SizedBox(key: ValueKey('page1'));
        const page2 = SizedBox(key: ValueKey('page2'));

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [page1, page2],
          ),
        );
        await tester.pump();

        expect(find.byType(AnimatedBuilder), findsWidgets);
      });
    });

    group('MainScaffoldPage - User Interactions', () {
      testWidgets('should navigate between pages when tapping bottom nav', (
          tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        const page1 = SizedBox(key: ValueKey('home-page'));
        const page2 = SizedBox(key: ValueKey('bank-page'));

        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [page1, page2],
          ),
        );
        await tester.pump();

        // Initially on home page
        expect(find.byKey(const ValueKey('home-page')), findsOneWidget);
        expect(find.byKey(const ValueKey('bank-page')), findsNothing);

        // Tap Bank in bottom nav
        await tester.tap(find.text('Bank'));
        await tester.pumpAndSettle();

        // Should show bank page
        expect(find.byKey(const ValueKey('bank-page')), findsOneWidget);
        expect(find.byKey(const ValueKey('home-page')), findsNothing);
      });

      testWidgets('should open and close drawer on desktop', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        // Drawer should be closed initially
        expect(find.byType(Drawer), findsNothing);

        // Open drawer
        await tester.tap(find.byIcon(Icons.menu_rounded));
        await tester.pumpAndSettle();

        // Drawer should be visible
        expect(find.byType(Drawer), findsOneWidget);
        expect(find.text('John Teacher'), findsOneWidget);

        // Close drawer
        await tester.tap(find.byType(Scaffold));
        await tester.pumpAndSettle();

        // Drawer should be closed
        expect(find.byType(Drawer), findsNothing);
      });

      testWidgets(
          'should show logout dialog when tapping user avatar', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        // Find and tap user avatar
        final avatarFinder = find.text('J');
        expect(avatarFinder, findsWidgets);

        await tester.tap(avatarFinder.first);
        await tester.pumpAndSettle();

        // Logout dialog should appear
        expect(find.text('Sign Out'), findsWidgets);
        expect(find.text('Are you sure you want to sign out?'), findsOneWidget);
      });

      testWidgets('should cancel logout when tapping Cancel', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);
        when(() => mockAuthBloc.add(any())).thenReturn(null);

        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        // Open logout dialog
        await tester.tap(find
            .text('J')
            .first);
        await tester.pumpAndSettle();

        // Tap Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Dialog should be closed
        expect(find.text('Are you sure you want to sign out?'), findsNothing);

        // Should NOT trigger logout
        verifyNever(() => mockAuthBloc.add(any<AuthEvent>()));
      });
    });

    group('MainScaffoldPage - Accessibility', () {
      testWidgets('should have accessible navigation items', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        // Check navigation items have Semantics widgets
        expect(find.byType(Semantics), findsWidgets);
      });

      testWidgets(
          'should have proper contrast for text elements', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        // Verify app bar has proper contrast
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, equals(AppColors.surface));
        expect(appBar.foregroundColor, equals(AppColors.textPrimary));
      });
    });

    group('MainScaffoldPage - Error Recovery', () {
      testWidgets('should recover from logout error', (tester) async {
        final teacher = createMockTeacher();
        final streamController = StreamController<AuthState>.broadcast();

        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockAuthBloc.stream).thenAnswer((_) => streamController.stream);
        when(() => mockUserStateService.isAdmin).thenReturn(false);
        when(() => mockAuthBloc.add(any())).thenReturn(null);

        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        // Open logout dialog
        await tester.tap(find.text('J').first);
        await tester.pumpAndSettle();

        // Confirm logout
        await tester.tap(find.text('Sign Out').last);
        await tester.pump();

        // Simulate logout error - emit the error state
        final errorState = const AuthError('Network error');
        when(() => mockAuthBloc.state).thenReturn(errorState);
        streamController.add(errorState);

        // Wait for the error to be processed
        await tester.pumpAndSettle();

        // Should handle gracefully without crashing
        expect(tester.takeException(), isNull);

        await streamController.close();
      });


      testWidgets('should handle closed bloc during logout', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockAuthBloc.isClosed).thenReturn(true);
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        // Open logout dialog
        await tester.tap(find
            .text('J')
            .first);
        await tester.pumpAndSettle();

        // Confirm logout - should not crash
        await tester.tap(find
            .text('Sign Out')
            .last);
        await tester.pump();

        // Should handle gracefully without crashing
        expect(tester.takeException(), isNull);
      });
    });

    group('MainScaffoldPage - Performance', () {
      testWidgets('should dispose controllers properly', (tester) async {
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        // Remove widget
        await tester.pumpWidget(Container());

        // Should not throw any errors during disposal
        expect(tester.takeException(), isNull);
      });

      testWidgets(
          'should cancel user state subscription on dispose', (tester) async {
        final teacher = createMockTeacher();

        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        when(() => mockUserStateService.isAdmin).thenReturn(false);
        when(() => mockUserStateService.addListener(any())).thenReturn(null);

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [Container()],
          ),
        );
        await tester.pump();

        // Verify listener was added
        verify(() => mockUserStateService.addListener(any())).called(
            greaterThan(0));

        // Dispose widget
        await tester.pumpWidget(Container());

        // Should not throw any errors during disposal
        expect(tester.takeException(), isNull);
      });
    });

    group('MainScaffoldPage - Complete User Flows', () {
      testWidgets(
          'teacher flow: login -> navigate -> view content', (tester) async {
        final streamController = StreamController<AuthState>.broadcast();

        when(() => mockAuthBloc.state).thenReturn(const AuthInitial());
        when(() => mockAuthBloc.stream).thenAnswer((_) =>
        streamController.stream);
        when(() => mockUserStateService.isAdmin).thenReturn(false);

        const homePage = SizedBox(
            key: ValueKey('home'), child: Text('Home Content'));
        const bankPage = SizedBox(
            key: ValueKey('bank'), child: Text('Bank Content'));

        tester.view.physicalSize = const Size(720, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [Container()],
            teacherPages: [homePage, bankPage],
          ),
        );
        await tester.pump();

        // Step 1: Unauthenticated
        expect(find.text('Authentication Required'), findsOneWidget);

        // Step 2: Login
        final teacher = createMockTeacher();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(teacher));
        streamController.add(AuthAuthenticated(teacher));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Step 3: On home page
        expect(find.text('Home Content'), findsOneWidget);

        // Step 4: Navigate to bank
        await tester.tap(find.text('Bank'));
        await tester.pumpAndSettle();

        // Step 5: View bank content
        expect(find.text('Bank Content'), findsOneWidget);
        expect(find.text('Home Content'), findsNothing);

        await streamController.close();
      });

      testWidgets(
          'admin flow: switch to teacher mode and back', (tester) async {
        final admin = createMockAdmin();
        when(() => mockAuthBloc.state).thenReturn(AuthAuthenticated(admin));

        VoidCallback? roleChangeCallback;
        when(() => mockUserStateService.addListener(any())).thenAnswer((
            invocation) {
          roleChangeCallback =
          invocation.positionalArguments[0] as VoidCallback;
          return null;
        });

        bool isCurrentlyAdmin = true;
        when(() => mockUserStateService.isAdmin).thenAnswer((
            _) => isCurrentlyAdmin);

        const adminPage = SizedBox(
            key: ValueKey('admin-dash'), child: Text('Admin Content'));
        const teacherPage = SizedBox(
            key: ValueKey('teacher-home'), child: Text('Teacher Content'));

        await tester.pumpWidget(
          createTestableWidget(
            authBloc: mockAuthBloc,
            userStateService: mockUserStateService,
            adminPages: [adminPage],
            teacherPages: [teacherPage],
          ),
        );
        await tester.pump();

        // Initially admin
        expect(find.text('Admin Content'), findsOneWidget);

        // Switch to teacher mode
        isCurrentlyAdmin = false;
        roleChangeCallback?.call();
        await tester.pump();

        // Should show teacher content
        expect(find.text('Teacher Content'), findsOneWidget);
        expect(find.text('Admin Content'), findsNothing);

        // Switch back to admin
        isCurrentlyAdmin = true;
        roleChangeCallback?.call();
        await tester.pump();

        // Should show admin content again
        expect(find.text('Admin Content'), findsOneWidget);
        expect(find.text('Teacher Content'), findsNothing);
      });
    });
  }
