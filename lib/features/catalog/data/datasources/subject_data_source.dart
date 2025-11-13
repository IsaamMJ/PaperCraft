// features/catalog/data/datasources/subject_data_source.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/cache/cache_service.dart';
import '../models/subject_catalog_model.dart';
import '../models/subject_model.dart';

abstract class SubjectDataSource {
  Future<List<SubjectCatalogModel>> getSubjectCatalog();
  Future<List<SubjectModel>> getSubjects(String tenantId);
  Future<List<SubjectModel>> getSubjectsByGrade(String tenantId, int grade);
  Future<SubjectModel?> getSubjectById(String id);
  Future<SubjectModel> createSubject(SubjectModel subject);
  Future<SubjectModel> updateSubject(SubjectModel subject);
  Future<void> deleteSubject(String id);
  Future<List<SubjectModel>> getAssignedSubjects(
      String tenantId,
      String teacherId,
      String academicYear,
      );
  Future<List<SubjectCatalogModel>> getSubjectsByGradeAndSection(
      String tenantId,
      String gradeId,
      String section,
      );
}

class SubjectDataSourceImpl implements SubjectDataSource {
  final SupabaseClient _supabase;
  final ILogger _logger;
  final CacheService _cache;

  // Cache key prefixes
  static const String _cacheKeySubjectCatalog = 'subject_catalog';
  static const String _cacheKeySubjects = 'subjects_';
  static const String _cacheKeyAssignedSubjects = 'assigned_subjects_';

  SubjectDataSourceImpl(this._supabase, this._logger, this._cache);

  @override
  Future<List<SubjectModel>> getAssignedSubjects(
      String tenantId,
      String teacherId,
      String academicYear,
      ) async {
    try {
      // OPTIMIZATION: Check cache first
      final cacheKey = '$_cacheKeyAssignedSubjects${tenantId}_${teacherId}_$academicYear';
      final cachedData = _cache.get<List<SubjectModel>>(cacheKey);
      if (cachedData != null) {
        _logger.debug('Cache HIT: getAssignedSubjects',
            category: LogCategory.storage,
            context: {
              'tenantId': tenantId,
              'teacherId': teacherId,
              'count': cachedData.length
            });
        return cachedData;
      }

      _logger.debug('Fetching assigned subjects for teacher',
          category: LogCategory.storage,
          context: {
            'tenantId': tenantId,
            'teacherId': teacherId,
            'academicYear': academicYear,
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
            subject_name,
            description,
            min_grade,
            max_grade
          ),
          teacher_subject_assignments!inner(
            teacher_id,
            academic_year,
            is_active
          )
        ''')
          .eq('tenant_id', tenantId)
          .eq('teacher_subject_assignments.tenant_id', tenantId)
          .eq('teacher_subject_assignments.teacher_id', teacherId)
          .eq('teacher_subject_assignments.academic_year', academicYear)
          .eq('teacher_subject_assignments.is_active', true)
          .eq('is_active', true)
          .eq('subject_catalog.is_active', true);

      final subjects = _parseSubjectResponse(response);
      // Sort by subject name since we can't order by foreign table columns in the query
      subjects.sort((a, b) => a.name.compareTo(b.name));

      // OPTIMIZATION: Cache the result
      _cache.set(cacheKey, subjects, duration: const Duration(minutes: 10));

      _logger.info('Assigned subjects fetched',
          category: LogCategory.storage,
          context: {
            'tenantId': tenantId,
            'teacherId': teacherId,
            'count': subjects.length,
          });

      return subjects;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch assigned subjects',
          category: LogCategory.storage,
          error: e,
          stackTrace: stackTrace);
      rethrow;
    }
  }


  @override
  Future<List<SubjectCatalogModel>> getSubjectCatalog() async {
    try {
      // OPTIMIZATION: Check cache first (catalog rarely changes)
      final cachedData = _cache.get<List<SubjectCatalogModel>>(_cacheKeySubjectCatalog);
      if (cachedData != null) {
        _logger.debug('Cache HIT: getSubjectCatalog',
            category: LogCategory.storage,
            context: {'count': cachedData.length});
        return cachedData;
      }

      _logger.debug('Fetching subject catalog', category: LogCategory.storage);

      // OPTIMIZATION: Only fetch needed columns
      final response = await _supabase
          .from('subject_catalog')
          .select('id, subject_name, description, min_grade, max_grade, is_active, created_at')
          .eq('is_active', true)
          .order('subject_name');

      final result = (response as List)
          .map((json) => SubjectCatalogModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // OPTIMIZATION: Cache for longer period since catalog rarely changes
      _cache.set(_cacheKeySubjectCatalog, result, duration: const Duration(hours: 1));

      return result;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch subject catalog',
          category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<SubjectModel>> getSubjects(String tenantId) async {
    try {
      // OPTIMIZATION: Check cache first
      final cacheKey = '$_cacheKeySubjects$tenantId';
      final cachedData = _cache.get<List<SubjectModel>>(cacheKey);
      if (cachedData != null) {
        _logger.debug('Cache HIT: getSubjects',
            category: LogCategory.storage,
            context: {'tenantId': tenantId, 'count': cachedData.length});
        return cachedData;
      }

      _logger.debug('Fetching subjects with catalog',
          category: LogCategory.storage, context: {'tenantId': tenantId});

      final response = await _supabase
          .from('subjects')
          .select('''
            id,
            tenant_id,
            catalog_subject_id,
            is_active,
            created_at,
            subject_catalog!inner(
              subject_name,
              description,
              min_grade,
              max_grade
            )
          ''')
          .eq('tenant_id', tenantId)
          .eq('is_active', true)
          .eq('subject_catalog.is_active', true);

      final result = _parseSubjectResponse(response);

      // OPTIMIZATION: Cache the result
      _cache.set(cacheKey, result, duration: const Duration(minutes: 10));

      _logger.info('Subjects fetched with catalog data',
          category: LogCategory.storage,
          context: {'tenantId': tenantId, 'count': result.length});

      return result;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch subjects',
          category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<SubjectModel>> getSubjectsByGrade(String tenantId, int grade) async {
    try {
      _logger.debug('Fetching subjects for grade',
          category: LogCategory.storage,
          context: {'tenantId': tenantId, 'grade': grade});

      final response = await _supabase
          .from('subjects')
          .select('''
            id,
            tenant_id,
            catalog_subject_id,
            is_active,
            created_at,
            subject_catalog!inner(
              subject_name,
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

      return _parseSubjectResponse(response);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch subjects by grade',
          category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<SubjectModel?> getSubjectById(String id) async {
    try {
      final response = await _supabase
          .from('subjects')
          .select('''
            id,
            tenant_id,
            catalog_subject_id,
            is_active,
            created_at,
            subject_catalog!inner(
              subject_name,
              description,
              min_grade,
              max_grade
            )
          ''')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      final flattened = _flattenSubjectData(response);
      return SubjectModel.fromJson(flattened);
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch subject by ID',
          category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<SubjectModel> createSubject(SubjectModel subject) async {
    try {
      _logger.info('Creating subject',
          category: LogCategory.storage,
          context: {
            'catalogSubjectId': subject.catalogSubjectId,
            'tenantId': subject.tenantId,
          });

      final data = {
        'tenant_id': subject.tenantId,
        'catalog_subject_id': subject.catalogSubjectId,
        'is_active': true,
      };

      final response = await _supabase
          .from('subjects')
          .insert(data)
          .select('''
            id,
            tenant_id,
            catalog_subject_id,
            is_active,
            created_at,
            subject_catalog!inner(
              subject_name,
              description,
              min_grade,
              max_grade
            )
          ''')
          .single();

      final flattened = _flattenSubjectData(response);
      return SubjectModel.fromJson(flattened);
    } catch (e, stackTrace) {
      _logger.error('Failed to create subject',
          category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<SubjectModel> updateSubject(SubjectModel subject) async {
    try {
      final data = {'is_active': subject.isActive};

      final response = await _supabase
          .from('subjects')
          .update(data)
          .eq('id', subject.id)
          .select('''
            id,
            tenant_id,
            catalog_subject_id,
            is_active,
            created_at,
            subject_catalog!inner(
              subject_name,
              description,
              min_grade,
              max_grade
            )
          ''')
          .single();

      final flattened = _flattenSubjectData(response);
      return SubjectModel.fromJson(flattened);
    } catch (e, stackTrace) {
      _logger.error('Failed to update subject',
          category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteSubject(String id) async {
    try {
      await _supabase.from('subjects').update({'is_active': false}).eq('id', id);
    } catch (e, stackTrace) {
      _logger.error('Failed to delete subject',
          category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  List<SubjectModel> _parseSubjectResponse(List<dynamic> response) {
    return response.map((item) {
      final flattened = _flattenSubjectData(item);
      return SubjectModel.fromJson(flattened);
    }).toList();
  }

  Map<String, dynamic> _flattenSubjectData(dynamic item) {
    final catalog = item['subject_catalog'] as Map<String, dynamic>;

    return {
      'id': item['id'],
      'tenant_id': item['tenant_id'],
      'catalog_subject_id': item['catalog_subject_id'],
      'is_active': item['is_active'],
      'created_at': item['created_at'],
      'name': catalog['subject_name'], // Map subject_name to name for SubjectModel
      'description': catalog['description'],
      'min_grade': catalog['min_grade'],
      'max_grade': catalog['max_grade'],
    };
  }

  @override
  Future<List<SubjectCatalogModel>> getSubjectsByGradeAndSection(
      String tenantId,
      String gradeId,
      String section,
      ) async {
    try {
      // Cache key includes filter status to avoid stale data
      final cacheKey = 'subjects_${tenantId}_${gradeId}_${section}_offered_true';
      final cachedData = _cache.get<List<SubjectCatalogModel>>(cacheKey);
      if (cachedData != null) {
        _logger.debug('Cache HIT: getSubjectsByGradeAndSection',
            category: LogCategory.storage,
            context: {
              'tenantId': tenantId,
              'gradeId': gradeId,
              'section': section,
              'count': cachedData.length
            });
        return cachedData;
      }

      _logger.debug('Fetching subjects for grade and section',
          category: LogCategory.storage,
          context: {
            'tenantId': tenantId,
            'gradeId': gradeId,
            'section': section,
          });

      // Query grade_section_subject to get subjects offered in this grade+section
      final response = await _supabase
          .from('grade_section_subject')
          .select('''
            subject:subject_id(
              id,
              catalog_subject_id,
              subject_catalog(
                id,
                subject_name,
                description,
                min_grade,
                max_grade,
                is_active
              )
            )
          ''')
          .eq('tenant_id', tenantId)
          .eq('grade_id', gradeId)
          .eq('section', section)
          .eq('is_offered', true)
          .order('display_order');

      final result = (response as List)
          .map((item) {
            final subject = item['subject'];
            if (subject == null) return null;

            final catalog = subject['subject_catalog'];
            if (catalog == null) {
              _logger.warning(
                'Subject has no catalog entry',
                category: LogCategory.storage,
                context: {
                  'subjectId': subject['id'],
                  'catalogSubjectId': subject['catalog_subject_id'],
                },
              );
              return null;
            }

            return SubjectCatalogModel.fromJson({
              ...catalog as Map<String, dynamic>,
              'id': subject['id'],  // Use actual subjects.id, not catalog_subject_id
            });
          })
          .whereType<SubjectCatalogModel>()
          .toList();

      // Cache the result
      _cache.set(cacheKey, result, duration: const Duration(minutes: 10));

      _logger.info('Subjects fetched for grade and section',
          category: LogCategory.storage,
          context: {
            'tenantId': tenantId,
            'gradeId': gradeId,
            'section': section,
            'count': result.length,
          });

      return result;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch subjects by grade and section',
          category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}