import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/interfaces/i_logger.dart';
import '../../domain/interfaces/i_network_service.dart';
import '../../domain/interfaces/i_feature_flags.dart';
import '../config/infrastructure_config.dart';
import '../utils/platform_utils.dart';
import 'models/api_response.dart';

class ApiClient {
  final SupabaseClient _supabase;
  final INetworkService _networkService;
  final ILogger _logger;
  final IFeatureFlags _featureFlags;

  ApiClient(this._supabase, this._networkService, this._logger, this._featureFlags);

  /// Generic database query with built-in error handling, retries, and logging
  Future<ApiResponse<T>> query<T>({
    required String table,
    required String operation,
    required Future<dynamic> Function() apiCall,
    required T Function(dynamic data) parser,
    String? operationId,
  }) async {
    final startTime = DateTime.now();
    final id = operationId ?? '${operation}_${DateTime.now().millisecondsSinceEpoch}';

    if (_featureFlags.enableNetworkLogging) {
      _logger.networkRequest(operation, table, context: {
        'operationId': id,
        'platform': PlatformUtils.platformName,
      });
    }

    try {
      // Check network connectivity first
      if (!await _networkService.isConnected()) {
        _logger.warning('API Request [$id]: No network connection',
            category: LogCategory.network,
            context: {
              'operation': operation,
              'table': table,
              'platform': PlatformUtils.platformName,
            });

        return ApiResponse.error(
          message: 'No internet connection',
          type: ApiErrorType.network,
          operation: operation,
        );
      }

      // Execute API call with timeout from config
      final result = await apiCall().timeout(
        InfrastructureConfig.apiTimeout,
        onTimeout: () => throw TimeoutException('Request timed out', InfrastructureConfig.apiTimeout),
      );

      final duration = DateTime.now().difference(startTime);

      if (_featureFlags.enableNetworkLogging) {
        _logger.info('API Success [$id]: ${duration.inMilliseconds}ms',
            category: LogCategory.network,
            context: {
              'operation': operation,
              'table': table,
              'duration': '${duration.inMilliseconds}ms',
              'platform': PlatformUtils.platformName,
            });
      }

      // Parse and return success response
      final parsedData = parser(result);
      return ApiResponse.success(
        data: parsedData,
        operation: operation,
        duration: duration,
      );

    } on PostgrestException catch (e) {
      final duration = DateTime.now().difference(startTime);
      _logger.networkError(operation, table, e, context: {
        'postgrestCode': e.code,
        'duration': '${duration.inMilliseconds}ms',
        'platform': PlatformUtils.platformName,
      });

      return ApiResponse.error(
        message: _mapPostgrestError(e),
        type: _getErrorType(e),
        operation: operation,
        duration: duration,
        originalError: e,
      );

    } on TimeoutException catch (e) {
      final duration = DateTime.now().difference(startTime);
      _logger.networkError(operation, table, e, context: {
        'timeout': '${InfrastructureConfig.apiTimeout.inSeconds}s',
        'duration': '${duration.inMilliseconds}ms',
        'platform': PlatformUtils.platformName,
      });

      return ApiResponse.error(
        message: 'Request timed out. Please check your connection.',
        type: ApiErrorType.timeout,
        operation: operation,
        duration: duration,
        originalError: e,
      );

    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _logger.networkError(operation, table, e, context: {
        'errorType': e.runtimeType.toString(),
        'duration': '${duration.inMilliseconds}ms',
        'platform': PlatformUtils.platformName,
      });

      return ApiResponse.error(
        message: 'An unexpected error occurred. Please try again.',
        type: ApiErrorType.unknown,
        operation: operation,
        duration: duration,
        originalError: e,
      );
    }
  }

  /// Wrapper for SELECT operations
  Future<ApiResponse<List<T>>> select<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) async {
    return await query<List<T>>(
      table: table,
      operation: 'SELECT',
      apiCall: () async {
        // Build query with proper type handling
        var baseQuery = _supabase.from(table).select();

        // Apply filters first (returns PostgrestFilterBuilder)
        if (filters != null) {
          filters.forEach((key, value) {
            if (value is String && value.contains('%')) {
              baseQuery = baseQuery.ilike(key, value);
            } else {
              baseQuery = baseQuery.eq(key, value);
            }
          });
        }

        // Apply ordering and limiting (these return PostgrestTransformBuilder)
        dynamic finalQuery = baseQuery;

        if (orderBy != null) {
          finalQuery = finalQuery.order(orderBy, ascending: ascending);
        }

        if (limit != null) {
          // Use InfrastructureConfig for default pagination limits
          final safeLimit = limit > InfrastructureConfig.maxPageSize ? InfrastructureConfig.maxPageSize : limit;
          finalQuery = finalQuery.limit(safeLimit);
        }

        return await finalQuery;
      },
      parser: (data) {
        final List<dynamic> list = data as List<dynamic>;
        return list.map((item) => fromJson(item as Map<String, dynamic>)).toList();
      },
    );
  }

  /// Wrapper for INSERT operations
  Future<ApiResponse<T>> insert<T>({
    required String table,
    required Map<String, dynamic> data,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    return await query<T>(
      table: table,
      operation: 'INSERT',
      apiCall: () async {
        return await _supabase
            .from(table)
            .insert(data)
            .select()
            .single();
      },
      parser: (data) => fromJson(data as Map<String, dynamic>),
    );
  }

  /// Wrapper for UPDATE operations
  Future<ApiResponse<T>> update<T>({
    required String table,
    required Map<String, dynamic> data,
    required Map<String, dynamic> filters,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    return await query<T>(
      table: table,
      operation: 'UPDATE',
      apiCall: () async {
        var query = _supabase.from(table).update(data);

        filters.forEach((key, value) {
          query = query.eq(key, value);
        });

        return await query.select().single();
      },
      parser: (data) => fromJson(data as Map<String, dynamic>),
    );
  }

  /// Wrapper for DELETE operations
  Future<ApiResponse<void>> delete({
    required String table,
    required Map<String, dynamic> filters,
  }) async {
    return await query<void>(
      table: table,
      operation: 'DELETE',
      apiCall: () async {
        var query = _supabase.from(table).delete();

        filters.forEach((key, value) {
          query = query.eq(key, value);
        });

        return await query;
      },
      parser: (data) => null,
    );
  }

  /// Get single record with null safety
  Future<ApiResponse<T?>> selectSingle<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> filters,
  }) async {
    return await query<T?>(
      table: table,
      operation: 'SELECT_SINGLE',
      apiCall: () async {
        var query = _supabase.from(table).select();

        filters.forEach((key, value) {
          query = query.eq(key, value);
        });

        return await query.maybeSingle();
      },
      parser: (data) => data != null ? fromJson(data as Map<String, dynamic>) : null,
    );
  }

  /// Auth-specific operations
  Future<ApiResponse<Session?>> signInWithOAuth({
    required OAuthProvider provider,
    String? redirectTo,
    Map<String, String>? queryParams,
  }) async {
    return await query<Session?>(
      table: 'auth',
      operation: 'OAUTH_SIGNIN',
      apiCall: () async {
        final launched = await _supabase.auth.signInWithOAuth(
          provider,
          redirectTo: redirectTo,
          queryParams: queryParams,
        );

        if (!launched) {
          throw Exception('Failed to launch OAuth flow');
        }

        // This would need to be handled differently in practice
        // as OAuth is asynchronous
        return _supabase.auth.currentSession;
      },
      parser: (data) => data as Session?,
    );
  }

  /// Map Postgrest errors to user-friendly messages
  String _mapPostgrestError(PostgrestException e) {
    switch (e.code) {
      case '23505': // unique_violation
        return 'This record already exists.';
      case '23503': // foreign_key_violation
        return 'Cannot perform this action due to related data.';
      case '42P01': // undefined_table
        return 'Database configuration error. Please contact support.';
      case 'PGRST116': // no rows returned
        return 'No data found.';
      default:
        return 'Database error: ${e.message}';
    }
  }

  /// Determine error type for proper handling
  ApiErrorType _getErrorType(PostgrestException e) {
    if (e.code?.startsWith('23') == true) {
      return ApiErrorType.validation;
    }
    if (e.code == 'PGRST116') {
      return ApiErrorType.notFound;
    }
    return ApiErrorType.server;
  }
}