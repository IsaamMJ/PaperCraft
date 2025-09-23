import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../models/grade_model.dart';

abstract class GradeDataSource {
  Future<List<GradeModel>> getGrades(String tenantId);
  Future<List<GradeModel>> getGradesByLevel(String tenantId, int level);
  Future<List<int>> getAvailableGradeLevels(String tenantId);
  Future<List<String>> getSectionsByGradeLevel(String tenantId, int level);
}

class GradeDataSourceImpl implements GradeDataSource {
  final ApiClient _apiClient;
  final ILogger _logger;
  static const String _tableName = 'grades';

  GradeDataSourceImpl(this._apiClient, this._logger);

  @override
  Future<List<GradeModel>> getGrades(String tenantId) async {
    try {
      _logger.debug('Fetching grades from Supabase', category: LogCategory.storage, context: {
        'tenantId': tenantId,
      });

      final response = await _apiClient.select<GradeModel>(
        table: _tableName,
        fromJson: (json) => GradeModel.fromJson(json),
        filters: {
          'tenant_id': tenantId,
          'is_active': true,
        },
        orderBy: 'level, section',
        ascending: true,
      );

      if (response.isSuccess) {
        _logger.info('Grades fetched successfully from Supabase',
            category: LogCategory.storage,
            context: {
              'tenantId': tenantId,
              'gradesCount': response.data!.length,
            }
        );
        return response.data!;
      } else {
        _logger.error('Failed to fetch grades from Supabase',
          category: LogCategory.storage,
          error: Exception('API Error: ${response.message}'),
          context: {
            'tenantId': tenantId,
            'apiErrorType': response.errorType?.toString(),
            'apiMessage': response.message,
          },
        );
        throw Exception(response.message ?? 'Failed to get grades');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch grades from Supabase',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {
          'tenantId': tenantId,
          'errorType': e.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }

  @override
  Future<List<GradeModel>> getGradesByLevel(String tenantId, int level) async {
    try {
      _logger.debug('Fetching grades by level from Supabase', category: LogCategory.storage, context: {
        'tenantId': tenantId,
        'level': level,
      });

      final response = await _apiClient.select<GradeModel>(
        table: _tableName,
        fromJson: (json) => GradeModel.fromJson(json),
        filters: {
          'tenant_id': tenantId,
          'level': level,
          'is_active': true,
        },
        orderBy: 'section',
        ascending: true,
      );

      if (response.isSuccess) {
        _logger.debug('Grades by level fetched successfully',
            category: LogCategory.storage,
            context: {
              'tenantId': tenantId,
              'level': level,
              'gradesCount': response.data!.length,
            }
        );
        return response.data!;
      } else {
        _logger.error('Failed to fetch grades by level',
          category: LogCategory.storage,
          error: Exception('API Error: ${response.message}'),
          context: {
            'tenantId': tenantId,
            'level': level,
            'apiErrorType': response.errorType?.toString(),
            'apiMessage': response.message,
          },
        );
        throw Exception(response.message ?? 'Failed to get grades by level');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch grades by level',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {
          'tenantId': tenantId,
          'level': level,
          'errorType': e.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }

  @override
  Future<List<int>> getAvailableGradeLevels(String tenantId) async {
    try {
      _logger.debug('Fetching available grade levels', category: LogCategory.storage, context: {
        'tenantId': tenantId,
      });

      // Fetch all grades first, then extract levels
      final response = await _apiClient.select<GradeModel>(
        table: _tableName,
        fromJson: (json) => GradeModel.fromJson(json),
        filters: {
          'tenant_id': tenantId,
          'is_active': true,
        },
        orderBy: 'level',
        ascending: true,
      );

      if (response.isSuccess) {
        // Extract unique levels from grades
        final levels = response.data!
            .map((grade) => grade.level)
            .toSet()
            .toList()
          ..sort();

        _logger.debug('Available grade levels fetched',
            category: LogCategory.storage,
            context: {
              'tenantId': tenantId,
              'levels': levels,
            }
        );

        return levels;
      } else {
        throw Exception(response.message ?? 'Failed to get grade levels');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch grade levels',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {
          'tenantId': tenantId,
          'errorType': e.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }

  @override
  Future<List<String>> getSectionsByGradeLevel(String tenantId, int level) async {
    try {
      _logger.debug('Fetching sections by grade level', category: LogCategory.storage, context: {
        'tenantId': tenantId,
        'level': level,
      });

      // Fetch grades for specific level, then extract sections
      final response = await _apiClient.select<GradeModel>(
        table: _tableName,
        fromJson: (json) => GradeModel.fromJson(json),
        filters: {
          'tenant_id': tenantId,
          'level': level,
          'is_active': true,
        },
        orderBy: 'section',
        ascending: true,
      );

      if (response.isSuccess) {
        // Extract non-null sections and sort them
        final sections = response.data!
            .map((grade) => grade.section)
            .where((section) => section != null && section!.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();

        _logger.debug('Sections by grade level fetched',
            category: LogCategory.storage,
            context: {
              'tenantId': tenantId,
              'level': level,
              'sections': sections,
            }
        );

        return sections;
      } else {
        throw Exception(response.message ?? 'Failed to get sections');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch sections by grade level',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {
          'tenantId': tenantId,
          'level': level,
          'errorType': e.runtimeType.toString(),
        },
      );
      rethrow;
    }
  }
}
