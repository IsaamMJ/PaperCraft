import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/interfaces/i_logger.dart';
import '../../domain/interfaces/i_network_service.dart';
import '../../domain/interfaces/i_feature_flags.dart';
import '../config/infrastructure_config.dart';
import '../utils/platform_utils.dart';
import 'models/api_response.dart';
import 'postgres_error_codes.dart';

/// Centralized API client for Supabase database operations
///
/// Features:
/// - Automatic retry with exponential backoff for read operations
/// - Comprehensive error handling with user-friendly messages
/// - Network connectivity checking
/// - Request/response logging (when enabled)
/// - Timeout handling
/// - Type-safe response parsing
///
/// Usage:
/// ```dart
/// final response = await apiClient.select<User>(
///   table: 'users',
///   fromJson: User.fromJson,
///   filters: {'email': 'user@example.com'},
/// );
///
/// if (response.isSuccess) {
///   final users = response.data!;
///   // Handle success
/// } else {
///   // Handle error with response.message
/// }
/// ```
class ApiClient {
  final SupabaseClient _supabase;
  final INetworkService _networkService;
  final ILogger _logger;
  final IFeatureFlags _featureFlags;

  // Retry configuration
  static const int _maxRetries = 2;
  static const Duration _initialRetryDelay = Duration(milliseconds: 500);
  static const double _retryBackoffMultiplier = 2.0;

  ApiClient(this._supabase, this._networkService, this._logger, this._featureFlags);

  /// Generic database query with built-in error handling, retries, and logging
  Future<ApiResponse<T>> query<T>({
    required String table,
    required String operation,
    required Future<dynamic> Function() apiCall,
    required T Function(dynamic data) parser,
    String? operationId,
    bool enableRetry = true,
  }) async {
    final startTime = DateTime.now();
    final id = operationId ?? '${operation}_${DateTime.now().millisecondsSinceEpoch}';

    if (_featureFlags.enableNetworkLogging) {
      _logger.networkRequest(operation, table, context: {
        'operationId': id,
        'platform': PlatformUtils.platformName,
      });
    }

    // Determine if this operation should be retried
    final shouldRetry = enableRetry && _isRetryableOperation(operation);
    final maxAttempts = shouldRetry ? _maxRetries : 1;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Check network connectivity first
        if (!await _networkService.isConnected()) {
          _logger.warning('API Request [$id]: No network connection',
              category: LogCategory.network,
              context: {
                'operation': operation,
                'table': table,
                'attempt': attempt,
                'platform': PlatformUtils.platformName,
              });

          // Don't retry if no network
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
                'attempt': attempt,
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
        final isLastAttempt = attempt >= maxAttempts;

        _logger.networkError(operation, table, e, context: {
          'postgrestCode': e.code,
          'duration': '${duration.inMilliseconds}ms',
          'attempt': '$attempt/$maxAttempts',
          'platform': PlatformUtils.platformName,
        });

        // Don't retry on validation or permission errors
        if (!_isRetryableError(e) || isLastAttempt) {
          return ApiResponse.error(
            message: _mapPostgrestError(e),
            type: _getErrorType(e),
            operation: operation,
            duration: duration,
            originalError: e,
          );
        }

        // Wait before retrying with exponential backoff
        await _waitBeforeRetry(attempt);

      } on TimeoutException catch (e) {
        final duration = DateTime.now().difference(startTime);
        final isLastAttempt = attempt >= maxAttempts;

        _logger.networkError(operation, table, e, context: {
          'timeout': '${InfrastructureConfig.apiTimeout.inSeconds}s',
          'duration': '${duration.inMilliseconds}ms',
          'attempt': '$attempt/$maxAttempts',
          'platform': PlatformUtils.platformName,
        });

        if (isLastAttempt) {
          return ApiResponse.error(
            message: 'Request timed out. Please check your connection.',
            type: ApiErrorType.timeout,
            operation: operation,
            duration: duration,
            originalError: e,
          );
        }

        // Wait before retrying
        await _waitBeforeRetry(attempt);

      } catch (e) {
        final duration = DateTime.now().difference(startTime);
        final isLastAttempt = attempt >= maxAttempts;

        _logger.networkError(operation, table, e, context: {
          'errorType': e.runtimeType.toString(),
          'duration': '${duration.inMilliseconds}ms',
          'attempt': '$attempt/$maxAttempts',
          'platform': PlatformUtils.platformName,
        });

        if (isLastAttempt) {
          return ApiResponse.error(
            message: 'An unexpected error occurred. Please try again.',
            type: ApiErrorType.unknown,
            operation: operation,
            duration: duration,
            originalError: e,
          );
        }

        // Wait before retrying
        await _waitBeforeRetry(attempt);
      }
    }

    // Should never reach here, but return error just in case
    return ApiResponse.error(
      message: 'Maximum retry attempts exceeded',
      type: ApiErrorType.unknown,
      operation: operation,
    );
  }

  /// Check if operation should be retried
  bool _isRetryableOperation(String operation) {
    // Only retry read operations, never retry writes
    return operation == 'SELECT' || operation == 'SELECT_SINGLE';
  }

  /// Check if error is transient and should be retried
  bool _isRetryableError(PostgrestException e) {
    // Don't retry validation, permission, or not found errors
    if (e.code == PostgresErrorCodes.uniqueViolation ||
        e.code == PostgresErrorCodes.foreignKeyViolation ||
        e.code == PostgresErrorCodes.checkViolation ||
        e.code == PostgresErrorCodes.notNullViolation ||
        e.code == PostgresErrorCodes.insufficientPrivilege ||
        e.code == PostgresErrorCodes.rlsPolicyViolation ||
        e.code == PostgresErrorCodes.noRowsReturned) {
      return false;
    }
    // Retry on server errors or unknown transient issues
    return true;
  }

  /// Wait before retry with exponential backoff
  Future<void> _waitBeforeRetry(int attempt) async {
    final delay = _initialRetryDelay *
        (_retryBackoffMultiplier * (attempt - 1));
    await Future.delayed(delay);
  }

  /// Select multiple records from a table
  ///
  /// Supports filtering, ordering, and limiting results.
  /// Automatically retries on transient failures.
  ///
  /// Parameters:
  /// - [table]: Table name to query
  /// - [fromJson]: Function to parse each row into type T
  /// - [filters]: Column filters (supports exact match and ILIKE with %)
  /// - [orderBy]: Column name to order by
  /// - [ascending]: Sort direction (default: true)
  /// - [limit]: Maximum number of rows to return
  ///
  /// Returns: [ApiResponse<List<T>>] with list of parsed objects
  ///
  /// Example:
  /// ```dart
  /// final response = await select<Paper>(
  ///   table: 'question_papers',
  ///   fromJson: Paper.fromJson,
  ///   filters: {'status': 'submitted', 'tenant_id': tenantId},
  ///   orderBy: 'created_at',
  ///   ascending: false,
  ///   limit: 10,
  /// );
  /// ```
  Future<ApiResponse<List<T>>> select<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    Map<String, dynamic>? filters,
    String? orderBy,
    bool ascending = true,
    int? limit,
    String? selectColumns,
  }) async {
    return await query<List<T>>(
      table: table,
      operation: 'SELECT',
      apiCall: () async {
        // Build query with proper type handling
        // OPTIMIZATION: Support column filtering to reduce payload
        var baseQuery = selectColumns != null
            ? _supabase.from(table).select(selectColumns)
            : _supabase.from(table).select();

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

  /// Insert a new record into a table
  ///
  /// Does NOT retry on failure (write operations should not be retried).
  ///
  /// Parameters:
  /// - [table]: Table name
  /// - [data]: Column data to insert
  /// - [fromJson]: Function to parse the inserted row
  ///
  /// Returns: [ApiResponse<T>] with the inserted record
  ///
  /// Example:
  /// ```dart
  /// final response = await insert<Paper>(
  ///   table: 'question_papers',
  ///   data: paper.toJson(),
  ///   fromJson: Paper.fromJson,
  /// );
  /// ```
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

  /// Insert or update a record (upsert) - single database operation
  ///
  /// Performs an upsert (insert if not exists, update if exists) in a single query.
  /// More efficient than checking existence then deciding to insert/update.
  ///
  /// Parameters:
  /// - [table]: Table name
  /// - [data]: Column data to insert/update
  /// - [fromJson]: Function to parse the result
  /// - [onConflict]: Optional column name for conflict resolution (default: 'id')
  ///
  /// Returns: [ApiResponse<T>] with the inserted/updated record
  ///
  /// Example:
  /// ```dart
  /// final response = await upsert<Paper>(
  ///   table: 'question_papers',
  ///   data: paper.toJson(),
  ///   fromJson: Paper.fromJson,
  /// );
  /// ```
  Future<ApiResponse<T>> upsert<T>({
    required String table,
    required Map<String, dynamic> data,
    required T Function(Map<String, dynamic>) fromJson,
    String onConflict = 'id',
  }) async {
    return await query<T>(
      table: table,
      operation: 'UPSERT',
      apiCall: () async {
        return await _supabase
            .from(table)
            .upsert(data, onConflict: onConflict)
            .select()
            .single();
      },
      parser: (data) => fromJson(data as Map<String, dynamic>),
      enableRetry: false, // Don't retry write operations
    );
  }

  /// Batch insert multiple records (more efficient than individual inserts)
  ///
  /// Parameters:
  /// - [table]: Table name
  /// - [dataList]: List of records to insert
  /// - [fromJson]: Function to parse each inserted row
  ///
  /// Returns: [ApiResponse<List<T>>] with all inserted records
  ///
  /// Example:
  /// ```dart
  /// final response = await batchInsert<Paper>(
  ///   table: 'question_papers',
  ///   dataList: papers.map((p) => p.toJson()).toList(),
  ///   fromJson: Paper.fromJson,
  /// );
  /// ```
  Future<ApiResponse<List<T>>> batchInsert<T>({
    required String table,
    required List<Map<String, dynamic>> dataList,
    required T Function(Map<String, dynamic>) fromJson,
  }) async {
    if (dataList.isEmpty) {
      return ApiResponse.success(data: [], operation: 'BATCH_INSERT');
    }

    return await query<List<T>>(
      table: table,
      operation: 'BATCH_INSERT',
      apiCall: () async {
        return await _supabase
            .from(table)
            .insert(dataList)
            .select();
      },
      parser: (data) {
        final List<dynamic> list = data as List<dynamic>;
        return list.map((item) => fromJson(item as Map<String, dynamic>)).toList();
      },
      enableRetry: false, // Don't retry write operations
    );
  }

  /// Batch upsert multiple records (more efficient than individual upserts)
  ///
  /// Parameters:
  /// - [table]: Table name
  /// - [dataList]: List of records to insert/update
  /// - [fromJson]: Function to parse each result
  /// - [onConflict]: Column name for conflict resolution
  ///
  /// Returns: [ApiResponse<List<T>>] with all upserted records
  Future<ApiResponse<List<T>>> batchUpsert<T>({
    required String table,
    required List<Map<String, dynamic>> dataList,
    required T Function(Map<String, dynamic>) fromJson,
    String onConflict = 'id',
  }) async {
    if (dataList.isEmpty) {
      return ApiResponse.success(data: [], operation: 'BATCH_UPSERT');
    }

    return await query<List<T>>(
      table: table,
      operation: 'BATCH_UPSERT',
      apiCall: () async {
        return await _supabase
            .from(table)
            .upsert(dataList, onConflict: onConflict)
            .select();
      },
      parser: (data) {
        final List<dynamic> list = data as List<dynamic>;
        return list.map((item) => fromJson(item as Map<String, dynamic>)).toList();
      },
      enableRetry: false, // Don't retry write operations
    );
  }

  /// Update an existing record in a table
  ///
  /// Does NOT retry on failure (write operations should not be retried).
  ///
  /// Parameters:
  /// - [table]: Table name
  /// - [data]: Column data to update
  /// - [filters]: Filters to identify record(s) to update
  /// - [fromJson]: Function to parse the updated row
  ///
  /// Returns: [ApiResponse<T>] with the updated record
  ///
  /// Example:
  /// ```dart
  /// final response = await update<Paper>(
  ///   table: 'question_papers',
  ///   data: {'status': 'approved'},
  ///   filters: {'id': paperId},
  ///   fromJson: Paper.fromJson,
  /// );
  /// ```
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
      enableRetry: false, // Don't retry write operations
    );
  }

  /// Delete record(s) from a table
  ///
  /// Does NOT retry on failure (write operations should not be retried).
  ///
  /// Parameters:
  /// - [table]: Table name
  /// - [filters]: Filters to identify record(s) to delete
  ///
  /// Returns: [ApiResponse<void>] indicating success/failure
  ///
  /// Example:
  /// ```dart
  /// final response = await delete(
  ///   table: 'question_papers',
  ///   filters: {'id': paperId, 'status': 'draft'},
  /// );
  /// ```
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

  /// Get a single record from a table
  ///
  /// Returns null if no record is found (does not throw error).
  /// Automatically retries on transient failures.
  ///
  /// Parameters:
  /// - [table]: Table name to query
  /// - [fromJson]: Function to parse the row
  /// - [filters]: Filters to identify the record
  ///
  /// Returns: [ApiResponse<T?>] with the record or null
  ///
  /// Example:
  /// ```dart
  /// final response = await selectSingle<Paper>(
  ///   table: 'question_papers',
  ///   fromJson: Paper.fromJson,
  ///   filters: {'id': paperId},
  /// );
  ///
  /// if (response.isSuccess && response.data != null) {
  ///   final paper = response.data!;
  ///   // Handle paper
  /// }
  /// ```
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
      case PostgresErrorCodes.uniqueViolation:
        return PostgresErrorMessages.uniqueViolation;
      case PostgresErrorCodes.foreignKeyViolation:
        return PostgresErrorMessages.foreignKeyViolation;
      case PostgresErrorCodes.checkViolation:
        return PostgresErrorMessages.checkViolation;
      case PostgresErrorCodes.notNullViolation:
        return PostgresErrorMessages.notNullViolation;
      case PostgresErrorCodes.insufficientPrivilege:
        return PostgresErrorMessages.insufficientPrivilege;
      case PostgresErrorCodes.rlsPolicyViolation:
        return PostgresErrorMessages.rlsPolicyViolation;
      case PostgresErrorCodes.undefinedTable:
      case PostgresErrorCodes.undefinedColumn:
        return PostgresErrorMessages.undefinedTable;
      case PostgresErrorCodes.noRowsReturned:
        return PostgresErrorMessages.noRowsReturned;
      default:
        // Include original message for debugging
        return 'Database error: ${e.message}';
    }
  }

  /// Determine error type for proper handling
  ApiErrorType _getErrorType(PostgrestException e) {
    // Validation errors (constraint violations)
    if (e.code == PostgresErrorCodes.uniqueViolation ||
        e.code == PostgresErrorCodes.foreignKeyViolation ||
        e.code == PostgresErrorCodes.checkViolation ||
        e.code == PostgresErrorCodes.notNullViolation) {
      return ApiErrorType.validation;
    }

    // Permission errors
    if (e.code == PostgresErrorCodes.insufficientPrivilege ||
        e.code == PostgresErrorCodes.rlsPolicyViolation ||
        e.code == PostgresErrorCodes.rowLevelSecurityViolation) {
      return ApiErrorType.unauthorized;
    }

    // Not found
    if (e.code == PostgresErrorCodes.noRowsReturned) {
      return ApiErrorType.notFound;
    }

    // Configuration errors
    if (e.code == PostgresErrorCodes.undefinedTable ||
        e.code == PostgresErrorCodes.undefinedColumn) {
      return ApiErrorType.server;
    }

    // Default to server error
    return ApiErrorType.server;
  }
}