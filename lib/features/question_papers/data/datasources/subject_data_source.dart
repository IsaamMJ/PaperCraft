// features/question_papers/data/datasources/subject_data_source.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../models/subject_model.dart';

abstract class SubjectDataSource {
  Future<List<SubjectModel>> getSubjects(String tenantId);
  Future<List<SubjectModel>> getSubjectsByGrade(String tenantId, int grade);
  Future<SubjectModel?> getSubjectById(String id);
}

class SubjectDataSourceImpl implements SubjectDataSource {
  final SupabaseClient _supabase;
  final ILogger _logger;

  SubjectDataSourceImpl(this._supabase, this._logger);

  @override
  Future<List<SubjectModel>> getSubjects(String tenantId) async {
    try {
      _logger.debug('Fetching subjects with catalog', category: LogCategory.storage, context: {
        'tenantId': tenantId,
      });

      final response = await _supabase
          .from('subjects')
          .select('''
            id,
            tenant_id,
            catalog_subject_id,
            is_active,
            created_at,
            subject_catalog!inner(
              name,
              description,
              min_grade,
              max_grade
            )
          ''')
          .eq('tenant_id', tenantId)
          .eq('is_active', true)
          .eq('subject_catalog.is_active', true);

      _logger.info('Subjects fetched with catalog data',
        category: LogCategory.storage,
        context: {
          'tenantId': tenantId,
          'count': response.length,
        },
      );

      return _parseSubjectResponse(response);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch subjects',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {'tenantId': tenantId},
      );
      rethrow;
    }
  }

  @override
  Future<List<SubjectModel>> getSubjectsByGrade(String tenantId, int grade) async {
    try {
      _logger.debug('Fetching subjects for grade', category: LogCategory.storage, context: {
        'tenantId': tenantId,
        'grade': grade,
      });

      final response = await _supabase
          .from('subjects')
          .select('''
            id,
            tenant_id,
            catalog_subject_id,
            is_active,
            created_at,
            subject_catalog!inner(
              name,
              description,
              min_grade,
              max_grade
            )
          ''')
          .eq('tenant_id', tenantId)
          .eq('is_active', true)
          .eq('subject_catalog.is_active', true)
          .lte('subject_catalog.min_grade', grade)
          .gte('subject_catalog.max_grade', grade);

      _logger.debug('Subjects by grade fetched',
        category: LogCategory.storage,
        context: {
          'tenantId': tenantId,
          'grade': grade,
          'count': response.length,
        },
      );

      return _parseSubjectResponse(response);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch subjects by grade',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {
          'tenantId': tenantId,
          'grade': grade,
        },
      );
      rethrow;
    }
  }

  @override
  Future<SubjectModel?> getSubjectById(String id) async {
    try {
      _logger.debug('Fetching subject by ID', category: LogCategory.storage, context: {
        'subjectId': id,
      });

      final response = await _supabase
          .from('subjects')
          .select('''
            id,
            tenant_id,
            catalog_subject_id,
            is_active,
            created_at,
            subject_catalog!inner(
              name,
              description,
              min_grade,
              max_grade
            )
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        _logger.debug('Subject not found', category: LogCategory.storage, context: {
          'subjectId': id,
        });
        return null;
      }

      final flattened = _flattenSubjectData(response);
      return SubjectModel.fromJson(flattened);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch subject by ID',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {'subjectId': id},
      );
      rethrow;
    }
  }

  /// Parse list response and flatten nested subject_catalog data
  List<SubjectModel> _parseSubjectResponse(List<dynamic> response) {
    return response.map((item) {
      final flattened = _flattenSubjectData(item);
      return SubjectModel.fromJson(flattened);
    }).toList();
  }

  /// Flatten nested subject_catalog data into single level map
  Map<String, dynamic> _flattenSubjectData(dynamic item) {
    final catalog = item['subject_catalog'] as Map<String, dynamic>;

    return {
      'id': item['id'],
      'tenant_id': item['tenant_id'],
      'catalog_subject_id': item['catalog_subject_id'],
      'is_active': item['is_active'],
      'created_at': item['created_at'],
      'name': catalog['name'],
      'description': catalog['description'],
      'min_grade': catalog['min_grade'],
      'max_grade': catalog['max_grade'],
    };
  }
}