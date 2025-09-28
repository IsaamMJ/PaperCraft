// features/question_papers/data/datasources/subject_data_source.dart
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../../../../core/infrastructure/network/models/api_response.dart';
import '../models/subject_model.dart';

abstract class SubjectDataSource {
  Future<List<SubjectModel>> getSubjects(String tenantId);
  Future<SubjectModel?> getSubjectById(String id);
}

class SubjectDataSourceImpl implements SubjectDataSource {
  final ApiClient _apiClient;
  final ILogger _logger;
  static const String _tableName = 'subjects';

  SubjectDataSourceImpl(this._apiClient, this._logger);

  @override
  Future<List<SubjectModel>> getSubjects(String tenantId) async {
    try {
      _logger.debug('Fetching subjects from Supabase', category: LogCategory.storage, context: {
        'tenantId': tenantId,
        'operation': 'get_subjects',
      });

      final response = await _apiClient.select<SubjectModel>(
        table: _tableName,
        fromJson: (json) => SubjectModel.fromJson(json),
        filters: {
          'tenant_id': tenantId,
          'is_active': true,
        },
        orderBy: 'name',
        ascending: true,
      );

      if (response.isSuccess) {
        _logger.info('Subjects fetched successfully from Supabase',
            category: LogCategory.storage,
            context: {
              'tenantId': tenantId,
              'subjectsCount': response.data!.length,
              'operation': 'get_subjects',
            }
        );
        return response.data!;
      } else {
        _logger.error('Failed to fetch subjects from Supabase',
          category: LogCategory.storage,
          error: Exception('API Error: ${response.message}'),
          context: {
            'tenantId': tenantId,
            'apiErrorType': response.errorType?.toString(),
            'apiMessage': response.message,
            'operation': 'get_subjects',
          },
        );
        throw Exception(response.message ?? 'Failed to get subjects');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch subjects from Supabase',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {
          'tenantId': tenantId,
          'errorType': e.runtimeType.toString(),
          'operation': 'get_subjects',
        },
      );
      rethrow;
    }
  }

  @override
  Future<SubjectModel?> getSubjectById(String id) async {
    try {
      _logger.debug('Fetching subject by ID from Supabase', category: LogCategory.storage, context: {
        'subjectId': id,
        'operation': 'get_subject_by_id',
      });

      final response = await _apiClient.selectSingle<SubjectModel>(
        table: _tableName,
        fromJson: (json) => SubjectModel.fromJson(json),
        filters: {'id': id},
      );

      if (response.isSuccess) {
        if (response.data != null) {
          _logger.debug('Subject found in Supabase', category: LogCategory.storage, context: {
            'subjectId': id,
            'subjectName': response.data!.name,
            'operation': 'get_subject_by_id',
          });
        } else {
          _logger.debug('Subject not found in Supabase', category: LogCategory.storage, context: {
            'subjectId': id,
            'reason': 'not_exists',
            'operation': 'get_subject_by_id',
          });
        }
        return response.data;
      } else {
        // For not found errors, return null instead of throwing
        if (response.errorType == ApiErrorType.notFound) {
          _logger.debug('Subject not found in Supabase', category: LogCategory.storage, context: {
            'subjectId': id,
            'reason': 'api_not_found',
            'operation': 'get_subject_by_id',
          });
          return null;
        }

        _logger.error('Failed to fetch subject by ID from Supabase',
          category: LogCategory.storage,
          error: Exception('API Error: ${response.message}'),
          context: {
            'subjectId': id,
            'apiErrorType': response.errorType?.toString(),
            'apiMessage': response.message,
            'operation': 'get_subject_by_id',
          },
        );
        throw Exception(response.message ?? 'Failed to get subject by ID');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch subject by ID from Supabase',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {
          'subjectId': id,
          'errorType': e.runtimeType.toString(),
          'operation': 'get_subject_by_id',
        },
      );
      rethrow;
    }
  }
}