// features/question_papers/data/datasources/grade_data_source.dart
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/network/api_client.dart';
import '../models/grade_model.dart';

abstract class GradeDataSource {
  Future<List<GradeModel>> getGrades(String tenantId);
  Future<GradeModel?> getGradeById(String id);
}

class GradeDataSourceImpl implements GradeDataSource {
  final ApiClient _apiClient;
  final ILogger _logger;
  static const String _tableName = 'grades';

  GradeDataSourceImpl(this._apiClient, this._logger);

  @override
  Future<List<GradeModel>> getGrades(String tenantId) async {
    try {
      _logger.debug('Fetching grades', category: LogCategory.storage, context: {
        'tenantId': tenantId,
      });

      final response = await _apiClient.select<GradeModel>(
        table: _tableName,
        fromJson: GradeModel.fromJson,
        filters: {
          'tenant_id': tenantId,
          'is_active': true,
        },
        orderBy: 'grade_number',
        ascending: true,
      );

      if (response.isSuccess) {
        _logger.info('Grades fetched', category: LogCategory.storage, context: {
          'tenantId': tenantId,
          'count': response.data!.length,
        });
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Failed to get grades');
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch grades',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<GradeModel?> getGradeById(String id) async {
    try {
      final response = await _apiClient.selectSingle<GradeModel>(
        table: _tableName,
        fromJson: GradeModel.fromJson,
        filters: {'id': id},
      );

      return response.data;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch grade by ID',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}