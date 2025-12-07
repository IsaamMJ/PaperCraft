import 'package:flutter/foundation.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:papercraft/core/domain/errors/failures.dart';
import 'package:papercraft/core/domain/interfaces/i_clock.dart';
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/features/authentication/domain/entities/tenant_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_entity.dart';
import 'package:papercraft/features/authentication/domain/entities/user_role.dart';
import 'package:papercraft/features/authentication/domain/services/user_state_service.dart';
import 'package:papercraft/features/authentication/domain/usecases/auth_usecase.dart';
import 'package:papercraft/features/authentication/domain/usecases/get_tenant_usecase.dart';
import '../../../../../helpers/mock_clock.dart';

// ============================================================================
// MOCKS
// ============================================================================

class MockLogger extends Mock implements ILogger {}

class MockGetTenantUseCase extends Mock implements GetTenantUseCase {}

class MockAuthUseCase extends Mock implements AuthUseCase {}

// ============================================================================
// SETUP
// ============================================================================



// ============================================================================
// TEST HELPERS
// ============================================================================

UserEntity createMockUser({
String id = 'user-123',
String email = 'test@example.com',
String fullName = 'Test User',
String? tenantId = 'tenant-123',
UserRole role = UserRole.teacher,
bool isActive = true,
}) {
return UserEntity(
id: id,
email: email,
fullName: fullName,
tenantId: tenantId,
role: role,
isActive: isActive,
createdAt: DateTime.now(),
lastLoginAt: DateTime.now(),
);
}

TenantEntity createMockTenant({
String id = 'tenant-123',
String name = 'Test School',
bool isActive = true,
bool isInitialized = true,
}) {
return TenantEntity(
id: id,
name: name,
isActive: isActive,
isInitialized: isInitialized,
createdAt: DateTime.now(),
);
}

// ============================================================================
// MAIN TEST SUITE
// ============================================================================

void main() {
late UserStateService userStateService;
late MockLogger mockLogger;
late MockGetTenantUseCase mockGetTenantUseCase;
late MockAuthUseCase mockAuthUseCase;
late FakeClock fakeClock;


setUpAll(() {
  registerFallbackValue(LogCategory.auth);
});


setUp(() {
mockLogger = MockLogger();
mockGetTenantUseCase = MockGetTenantUseCase();
mockAuthUseCase = MockAuthUseCase();
fakeClock = FakeClock();

// Default logger behavior
when(() => mockLogger.debug(any(), category: any(named: 'category'), context: any(named: 'context')))
    .thenReturn(null);
when(() => mockLogger.warning(any(), category: any(named: 'category'), context: any(named: 'context')))
    .thenReturn(null);
when(() => mockLogger.error(any(), category: any(named: 'category'), error: any(named: 'error'),
stackTrace: any(named: 'stackTrace'), context: any(named: 'context')))
    .thenReturn(null);
when(() => mockLogger.info(any(), category: any(named: 'category'), context: any(named: 'context')))
    .thenReturn(null);

userStateService = UserStateService(
mockLogger,
mockGetTenantUseCase,
mockAuthUseCase,
fakeClock,
);
});

tearDown(() {
userStateService.dispose();
fakeClock.cancelAllTimers();
});

group('UserStateService - Initialization', () {
test('starts with no user authenticated', () {
expect(userStateService.isAuthenticated, false);
expect(userStateService.currentUser, isNull);
expect(userStateService.currentTenant, isNull);
});

test('logs initialization message', () {
verify(() => mockLogger.debug(
'UserStateService initialized',
category: LogCategory.auth,
context: {
'serviceType': 'domain_service',
'responsibilities': ['user_state', 'permissions', 'tenant_management'],
},
)).called(1);
});
});

group('UserStateService - updateUser', () {
test('updates current user and sets authenticated state', () async {
// Arrange
final mockUser = createMockUser();
final mockTenant = createMockTenant();

when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Right(mockTenant));

// Act
await userStateService.updateUser(mockUser);

// Assert
expect(userStateService.currentUser, mockUser);
expect(userStateService.isAuthenticated, true);
expect(userStateService.currentUserId, mockUser.id);
});

test('loads tenant data when user has tenantId', () async {
// Arrange
final mockUser = createMockUser(tenantId: 'tenant-456');
final mockTenant = createMockTenant(id: 'tenant-456');

when(() => mockGetTenantUseCase('tenant-456'))
    .thenAnswer((_) async => Right(mockTenant));

// Act
await userStateService.updateUser(mockUser);

// Assert
verify(() => mockGetTenantUseCase('tenant-456')).called(1);
expect(userStateService.currentTenant, mockTenant);
expect(userStateService.hasTenantData, true);
});

test('does not load tenant data when user has no tenantId', () async {
// Arrange
final mockUser = createMockUser(tenantId: null);

// Act
await userStateService.updateUser(mockUser);

// Assert
verifyNever(() => mockGetTenantUseCase(any()));
expect(userStateService.currentTenant, isNull);
});

test('does not reload tenant data if tenantId unchanged', () async {
// Arrange
final mockUser1 = createMockUser(tenantId: 'tenant-123');
final mockUser2 = createMockUser(id: 'user-456', tenantId: 'tenant-123');
final mockTenant = createMockTenant();

when(() => mockGetTenantUseCase('tenant-123'))
    .thenAnswer((_) async => Right(mockTenant));

// Act
await userStateService.updateUser(mockUser1);
await userStateService.updateUser(mockUser2);

// Assert - should only be called once
verify(() => mockGetTenantUseCase('tenant-123')).called(1);
});

test('notifies listeners when user is updated', () async {
// Arrange
final mockUser = createMockUser();
bool notified = false;

when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Right(createMockTenant()));

userStateService.addListener(() {
notified = true;
});

// Act
await userStateService.updateUser(mockUser);

// Assert
expect(notified, true);
});
});

group('UserStateService - clearUser', () {
test('clears user state and tenant data', () async {
// Arrange
final mockUser = createMockUser();
final mockTenant = createMockTenant();

when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Right(mockTenant));

await userStateService.updateUser(mockUser);
expect(userStateService.isAuthenticated, true);

// Act
userStateService.clearUser();

// Assert
expect(userStateService.currentUser, isNull);
expect(userStateService.currentTenant, isNull);
expect(userStateService.isAuthenticated, false);
});

test('notifies listeners when user is cleared', () async {
// Arrange
final mockUser = createMockUser();
when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Right(createMockTenant()));

await userStateService.updateUser(mockUser);

bool notified = false;
userStateService.addListener(() {
notified = true;
});

// Act
userStateService.clearUser();

// Assert
expect(notified, true);
});
});

group('UserStateService - Permissions', () {
test('canCreatePapers returns true for teacher', () async {
// Arrange
final mockUser = createMockUser(role: UserRole.teacher);

when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Right(createMockTenant()));

await userStateService.updateUser(mockUser);

// Act & Assert
expect(userStateService.canCreatePapers(), true);
});

test('canCreatePapers returns true for admin', () async {
// Arrange
final mockUser = createMockUser(role: UserRole.admin);

when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Right(createMockTenant()));

await userStateService.updateUser(mockUser);

// Act & Assert
expect(userStateService.canCreatePapers(), true);
});

test('canCreatePapers returns false for blocked user', () async {
// Arrange
final mockUser = createMockUser(role: UserRole.blocked);

when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Right(createMockTenant()));

await userStateService.updateUser(mockUser);

// Act & Assert
expect(userStateService.canCreatePapers(), false);
});

test('canApprovePapers returns true only for admin', () async {
  // Test admin
  final adminUser = createMockUser(role: UserRole.admin);
  when(() => mockGetTenantUseCase(any()))
      .thenAnswer((_) async => Right(createMockTenant()));

  await userStateService.updateUser(adminUser);
  expect(userStateService.canApprovePapers(), true);

  // Test teacher - reconfigure mock for second user
  final teacherUser = createMockUser(id: 'user-456', role: UserRole.teacher);
  when(() => mockGetTenantUseCase(any()))
      .thenAnswer((_) async => Right(createMockTenant()));

  await userStateService.updateUser(teacherUser);
  expect(userStateService.canApprovePapers(), false);
});

test('canEditPaper returns true for paper owner', () async {
// Arrange
final mockUser = createMockUser(id: 'user-123');

when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Right(createMockTenant()));

await userStateService.updateUser(mockUser);

// Act & Assert
expect(userStateService.canEditPaper('user-123'), true);
expect(userStateService.canEditPaper('other-user'), false);
});

test('canEditPaper returns true for admin even if not owner', () async {
// Arrange
final adminUser = createMockUser(id: 'admin-123', role: UserRole.admin);

when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Right(createMockTenant()));

await userStateService.updateUser(adminUser);

// Act & Assert
expect(userStateService.canEditPaper('other-user'), true);
});
});

group('UserStateService - Tenant Management', () {
test('schoolName returns tenant displayName when available', () async {
// Arrange
final mockUser = createMockUser();
final mockTenant = createMockTenant(name: 'My Awesome School');

when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Right(mockTenant));

await userStateService.updateUser(mockUser);

// Act & Assert
expect(userStateService.schoolName, 'My Awesome School');
});

test('schoolName returns fallback when tenant not loaded', () {
// Assert
expect(userStateService.schoolName, 'School');
});

test('handles tenant loading errors gracefully', () async {
// Arrange
final mockUser = createMockUser();

when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Left(AuthFailure('Tenant not found')));

// Act
await userStateService.updateUser(mockUser);

// Assert
expect(userStateService.tenantLoadError, 'Tenant not found');
expect(userStateService.hasTenantData, false);
});

test('reloadTenantData refreshes tenant information', () async {
// Arrange
final mockUser = createMockUser(tenantId: 'tenant-123');
final oldTenant = createMockTenant(name: 'Old School');
final newTenant = createMockTenant(name: 'New School');

when(() => mockGetTenantUseCase('tenant-123'))
    .thenAnswer((_) async => Right(oldTenant));

await userStateService.updateUser(mockUser);
expect(userStateService.schoolName, 'Old School');

// Update mock to return new tenant
when(() => mockGetTenantUseCase('tenant-123'))
    .thenAnswer((_) async => Right(newTenant));

// Act
await userStateService.reloadTenantData();

// Assert
expect(userStateService.schoolName, 'New School');
verify(() => mockGetTenantUseCase('tenant-123')).called(2);
});
});

group('UserStateService - Academic Year', () {
test('calculates correct academic year for July (start of year)', () {
// Arrange
fakeClock = FakeClock(DateTime(2024, 7, 1)); // July 1, 2024

userStateService = UserStateService(
mockLogger,
mockGetTenantUseCase,
mockAuthUseCase,
fakeClock,
);

// Act & Assert
expect(userStateService.currentAcademicYear, '2024-2025');
});

test('calculates correct academic year for June (end of year)', () {
// Arrange
fakeClock = FakeClock(DateTime(2024, 6, 30)); // June 30, 2024

userStateService = UserStateService(
mockLogger,
mockGetTenantUseCase,
mockAuthUseCase,
fakeClock,
);

// Act & Assert
expect(userStateService.currentAcademicYear, '2023-2024');
});

test('calculates correct academic year for December', () {
// Arrange
fakeClock = FakeClock(DateTime(2024, 12, 15)); // December 15, 2024

userStateService = UserStateService(
mockLogger,
mockGetTenantUseCase,
mockAuthUseCase,
fakeClock,
);

// Act & Assert
expect(userStateService.currentAcademicYear, '2024-2025');
});
});

group('UserStateService - Permission Refresh', () {
  test('periodic permission refresh updates user state', () async {
    // Arrange
    final initialUser = createMockUser(id: 'user-123', role: UserRole.teacher, tenantId: 'tenant-123');

    when(() => mockGetTenantUseCase(any()))
        .thenAnswer((_) async => Right(createMockTenant()));

    await userStateService.updateUser(initialUser);
    debugPrint('Initial role: ${userStateService.currentRole}');
    expect(userStateService.currentRole, UserRole.teacher);

    // Create a DIFFERENT user object with different timestamp to ensure != comparison
    await Future.delayed(Duration(milliseconds: 10));
    final updatedUser = createMockUser(id: 'user-123', role: UserRole.admin, tenantId: 'tenant-123');

    debugPrint('Initial user: $initialUser');
    debugPrint('Updated user: $updatedUser');
    debugPrint('Are they equal? ${initialUser == updatedUser}');

    // Setup mock to return updated user
    when(() => mockAuthUseCase.getCurrentUser())
        .thenAnswer((_) async => Right(updatedUser));

    // Act
    await userStateService.forcePermissionRefresh();

    debugPrint('Final role: ${userStateService.currentRole}');

    // Assert
    verify(() => mockAuthUseCase.getCurrentUser()).called(1);
    expect(userStateService.currentRole, UserRole.admin);
  });

test('permission refresh handles user deactivation', () async {
// Arrange
final activeUser = createMockUser(isActive: true);
final deactivatedUser = createMockUser(isActive: false);

when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Right(createMockTenant()));
when(() => mockAuthUseCase.getCurrentUser())
    .thenAnswer((_) async => Right(deactivatedUser));

await userStateService.updateUser(activeUser);
expect(userStateService.isAuthenticated, true);

// Act
await userStateService.forcePermissionRefresh();

// Assert
expect(userStateService.isAuthenticated, false);
expect(userStateService.currentUser, isNull);
});

test('permission refresh clears user when deleted', () async {
// Arrange
final mockUser = createMockUser();

when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Right(createMockTenant()));
when(() => mockAuthUseCase.getCurrentUser())
    .thenAnswer((_) async => const Right(null));

await userStateService.updateUser(mockUser);
expect(userStateService.isAuthenticated, true);

// Act
await userStateService.forcePermissionRefresh();

// Assert
expect(userStateService.isAuthenticated, false);
expect(userStateService.currentUser, isNull);
});
});

group('UserStateService - getUserInfo', () {
test('returns complete user information when authenticated', () async {
// Arrange
final mockUser = createMockUser(
id: 'user-123',
email: 'test@example.com',
fullName: 'Test User',
role: UserRole.teacher,
);
final mockTenant = createMockTenant(name: 'Test School');

when(() => mockGetTenantUseCase(any()))
    .thenAnswer((_) async => Right(mockTenant));

await userStateService.updateUser(mockUser);

// Act
final userInfo = userStateService.getUserInfo();

// Assert
expect(userInfo['is_authenticated'], true);
expect(userInfo['user_id'], 'user-123');
expect(userInfo['email'], 'test@example.com');
expect(userInfo['full_name'], 'Test User');
expect(userInfo['user_role'], 'teacher');
expect(userInfo['tenant_info']['tenant_name'], 'Test School');
expect(userInfo['permissions']['can_create_papers'], true);
});

test('returns error when not authenticated', () {
// Act
final userInfo = userStateService.getUserInfo();

// Assert
expect(userInfo['is_authenticated'], false);
expect(userInfo['error'], 'No user authenticated');
});
});
}