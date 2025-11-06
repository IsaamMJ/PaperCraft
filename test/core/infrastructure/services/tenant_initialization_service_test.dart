import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:papercraft/core/domain/interfaces/i_logger.dart';
import 'package:papercraft/core/infrastructure/services/tenant_initialization_service_impl.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockPostgresQueryBuilder extends Mock {
  MockPostgresQueryBuilder select(String value) => this;
  MockPostgresQueryBuilder eq(String key, dynamic value) => this;
  MockPostgresQueryBuilder limit(int value) => this;
  Future<dynamic> single() => Future.value({'is_initialized': true});
}

class MockRealtimeListenResponse extends Mock {}

class MockILogger extends Mock implements ILogger {}

void main() {
  group('TenantInitializationService', () {
    late MockSupabaseClient mockSupabaseClient;
    late MockILogger mockLogger;
    late TenantInitializationServiceImpl service;

    setUp(() {
      mockSupabaseClient = MockSupabaseClient();
      mockLogger = MockILogger();
      service = TenantInitializationServiceImpl(
        supabaseClient: mockSupabaseClient,
        logger: mockLogger,
      );
    });

    test('returns true when tenant is initialized', () async {
      // Arrange
      final tenantId = '123e4567-e89b-12d3-a456-426614174000';
      when(() => mockSupabaseClient.from('tenants'))
          .thenReturn(MockPostgresQueryBuilder());

      // Act
      final result = await service.isTenantInitialized(tenantId);

      // Assert
      expect(result, isTrue);
      verify(() => mockLogger.debug(
        any(),
        category: any(named: 'category'),
        context: any(named: 'context'),
      )).called(greaterThanOrEqualTo(1));
    });

    test('caches initialization status after first query', () async {
      // Arrange
      final tenantId = '123e4567-e89b-12d3-a456-426614174000';
      when(() => mockSupabaseClient.from('tenants'))
          .thenReturn(MockPostgresQueryBuilder());

      // Act
      await service.isTenantInitialized(tenantId);
      final secondResult = await service.isTenantInitialized(tenantId);

      // Assert
      expect(secondResult, isTrue);
      // Should only query once due to caching
      verify(() => mockSupabaseClient.from('tenants')).called(1);
    });

    test('clears all cached entries', () async {
      // Arrange
      final tenantId1 = '123e4567-e89b-12d3-a456-426614174000';
      final tenantId2 = '223e4567-e89b-12d3-a456-426614174000';

      when(() => mockSupabaseClient.from('tenants'))
          .thenReturn(MockPostgresQueryBuilder());

      // Act
      await service.isTenantInitialized(tenantId1);
      await service.isTenantInitialized(tenantId2);
      service.clearCache();

      // Reset mock to track new calls
      reset(mockSupabaseClient);
      when(() => mockSupabaseClient.from('tenants'))
          .thenReturn(MockPostgresQueryBuilder());

      await service.isTenantInitialized(tenantId1);

      // Assert - should query again after cache clear
      verify(() => mockSupabaseClient.from('tenants')).called(1);
    });

    test('clears cache for specific tenant', () async {
      // Arrange
      final tenantId1 = '123e4567-e89b-12d3-a456-426614174000';
      final tenantId2 = '223e4567-e89b-12d3-a456-426614174000';

      when(() => mockSupabaseClient.from('tenants'))
          .thenReturn(MockPostgresQueryBuilder());

      // Act
      await service.isTenantInitialized(tenantId1);
      await service.isTenantInitialized(tenantId2);
      service.clearCacheForTenant(tenantId1);

      // Reset mock
      reset(mockSupabaseClient);
      when(() => mockSupabaseClient.from('tenants'))
          .thenReturn(MockPostgresQueryBuilder());

      await service.isTenantInitialized(tenantId1);

      // Assert - should query again for cleared tenant
      verify(() => mockSupabaseClient.from('tenants')).called(1);
    });

    test('returns false on PostgreSQL error', () async {
      // Arrange
      final tenantId = '123e4567-e89b-12d3-a456-426614174000';
      final queryBuilder = MockPostgresQueryBuilder();

      when(() => queryBuilder.single()).thenThrow(
        PostgrestException(
          message: 'new row violates row-level security policy',
          code: '42501',
          details: 'table: "tenants"',
        ),
      );
      when(() => mockSupabaseClient.from('tenants')).thenReturn(queryBuilder);

      // Act
      final result = await service.isTenantInitialized(tenantId);

      // Assert
      expect(result, isFalse);
      verify(() => mockLogger.warning(
        any(),
        category: any(named: 'category'),
        context: any(named: 'context'),
      )).called(1);
    });

    test('returns false on timeout', () async {
      // Arrange
      final tenantId = '123e4567-e89b-12d3-a456-426614174000';
      final queryBuilder = MockPostgresQueryBuilder();

      when(() => queryBuilder.single()).thenThrow(
        TimeoutException('Timeout', const Duration(seconds: 5)),
      );
      when(() => mockSupabaseClient.from('tenants')).thenReturn(queryBuilder);

      // Act
      final result = await service.isTenantInitialized(tenantId);

      // Assert
      expect(result, isFalse);
      verify(() => mockLogger.warning(
        any(),
        category: any(named: 'category'),
        context: any(named: 'context'),
      )).called(1);
    });

    test('returns false on unexpected error', () async {
      // Arrange
      final tenantId = '123e4567-e89b-12d3-a456-426614174000';
      final queryBuilder = MockPostgresQueryBuilder();

      when(() => queryBuilder.single()).thenThrow(Exception('Network error'));
      when(() => mockSupabaseClient.from('tenants')).thenReturn(queryBuilder);

      // Act
      final result = await service.isTenantInitialized(tenantId);

      // Assert
      expect(result, isFalse);
      verify(() => mockLogger.error(
        any(),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        category: any(named: 'category'),
        context: any(named: 'context'),
      )).called(1);
    });

    test('logs debug messages for cache hits', () async {
      // Arrange
      final tenantId = '123e4567-e89b-12d3-a456-426614174000';
      when(() => mockSupabaseClient.from('tenants'))
          .thenReturn(MockPostgresQueryBuilder());

      // Act
      await service.isTenantInitialized(tenantId);
      // Clear logs from first call
      clearInteractions(mockLogger);

      await service.isTenantInitialized(tenantId);

      // Assert - should log cache hit
      verify(() => mockLogger.debug(
        'Returning cached tenant initialization status',
        category: any(named: 'category'),
        context: any(named: 'context'),
      )).called(1);
    });

    test('handles null is_initialized value as false', () async {
      // Arrange
      final tenantId = '123e4567-e89b-12d3-a456-426614174000';
      final queryBuilder = MockPostgresQueryBuilder();

      when(() => queryBuilder.single()).thenAnswer((_) async => {'is_initialized': null});
      when(() => mockSupabaseClient.from('tenants')).thenReturn(queryBuilder);

      // Act
      final result = await service.isTenantInitialized(tenantId);

      // Assert
      expect(result, isFalse);
    });
  });
}
