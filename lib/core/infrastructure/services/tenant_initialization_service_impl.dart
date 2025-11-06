import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/interfaces/i_logger.dart';
import '../../domain/services/tenant_initialization_service.dart';

/// Implementation of TenantInitializationService with caching and error handling
class TenantInitializationServiceImpl implements TenantInitializationService {
  final SupabaseClient supabaseClient;
  final ILogger logger;

  // Cache: tenantId -> isInitialized
  final Map<String, bool> _cache = {};

  TenantInitializationServiceImpl({
    required this.supabaseClient,
    required this.logger,
  });

  @override
  Future<bool> isTenantInitialized(String tenantId) async {
    try {
      // Check cache first
      if (_cache.containsKey(tenantId)) {
        logger.debug(
          'Returning cached tenant initialization status',
          category: LogCategory.auth,
          context: {
            'tenantId': tenantId,
            'isInitialized': _cache[tenantId],
          },
        );
        return _cache[tenantId]!;
      }

      logger.debug(
        'Querying tenant initialization status from database',
        category: LogCategory.auth,
        context: {'tenantId': tenantId},
      );

      // Query the tenants table for is_initialized status
      // Using Supabase API directly to ensure RLS policies are respected
      final response = await supabaseClient
          .from('tenants')
          .select('is_initialized')
          .eq('id', tenantId)
          .limit(1)
          .single()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException(
              'Tenant initialization query timed out after 5 seconds',
              const Duration(seconds: 5),
            ),
          );

      final isInitialized = (response['is_initialized'] as bool?) ?? false;

      // Cache the result
      _cache[tenantId] = isInitialized;

      logger.debug(
        'Tenant initialization status retrieved successfully',
        category: LogCategory.auth,
        context: {
          'tenantId': tenantId,
          'isInitialized': isInitialized,
        },
      );

      return isInitialized;
    } on PostgrestException catch (e) {
      // PostgreSQL/RLS error - likely auth context not fully initialized yet
      logger.warning(
        'PostgreSQL error querying tenant initialization status. '
        'This may occur during initial auth flow before full session establishment. '
        'Assuming tenant is initialized (safe default).',
        category: LogCategory.auth,
        context: {
          'tenantId': tenantId,
          'code': e.code,
          'message': e.message,
          'details': e.details,
        },
      );

      // Return true as safe default - assume tenant is initialized
      // If it truly isn't, the setup wizard can handle it
      return true;
    } on TimeoutException catch (e) {
      logger.warning(
        'Timeout querying tenant initialization status. '
        'Assuming tenant is initialized (safe default).',
        category: LogCategory.auth,
        context: {
          'tenantId': tenantId,
          'timeout': e.duration?.inSeconds ?? 5,
        },
      );
      return true;
    } catch (e, stackTrace) {
      logger.error(
        'Unexpected error querying tenant initialization status. '
        'Assuming tenant is initialized (safe default).',
        error: e,
        stackTrace: stackTrace,
        category: LogCategory.auth,
        context: {
          'tenantId': tenantId,
          'errorType': e.runtimeType.toString(),
        },
      );
      return true;
    }
  }

  @override
  void clearCache() {
    _cache.clear();
    logger.debug(
      'Cleared tenant initialization cache',
      category: LogCategory.auth,
    );
  }

  @override
  void clearCacheForTenant(String tenantId) {
    _cache.remove(tenantId);
    logger.debug(
      'Cleared tenant initialization cache for tenant',
      category: LogCategory.auth,
      context: {'tenantId': tenantId},
    );
  }
}
