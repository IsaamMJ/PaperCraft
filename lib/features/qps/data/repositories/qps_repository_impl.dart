// data/repositories/qps_repository_impl.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/subject_entity.dart';
import '../../domain/repositories/qps_repository.dart';

class QpsRepositoryImpl implements QpsRepository {
  final SupabaseClient supabase;
  final String? tenantId; // Optional: for testing/mocking

  QpsRepositoryImpl({
    required this.supabase,
    this.tenantId,
  });

  /// Retrieves tenantId from constructor or SharedPreferences
  Future<String> _getTenantId() async {
    if (tenantId != null && tenantId!.isNotEmpty) return tenantId!;
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('tenant_id');
    if (savedId == null || savedId.isEmpty) {
      throw Exception('Tenant ID not found in SharedPreferences');
    }
    return savedId;
  }

  @override
  Future<List<ExamTypeEntity>> getExamTypes() async {
    final id = await _getTenantId();
    final data = await supabase
        .from('exam_types')
        .select('id, name, sections')
        .eq('tenant_id', id) as List<dynamic>;

    return data
        .map((e) => ExamTypeEntity(
      id: e['id'] as String,
      tenantId: id,
      name: e['name'] as String,
      sections: _parseSections(e['sections']),
    ))
        .toList();
  }

  /// Parse sections JSON to List<ExamSectionEntity>
  List<ExamSectionEntity> _parseSections(dynamic sectionsJson) {
    if (sectionsJson == null) return [];

    try {
      final List<dynamic> sectionsList = sectionsJson as List<dynamic>;
      return sectionsList
          .map((section) => ExamSectionEntity.fromJson(section as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error parsing sections: $e');
      return [];
    }
  }

  @override
  Future<List<SubjectEntity>> getSubjects() async {
    final id = await _getTenantId();
    final data = await supabase
        .from('subjects')
        .select()
        .eq('tenant_id', id) as List<dynamic>;

    return data
        .map((e) => SubjectEntity(
      id: e['id'] as String,
      tenantId: id,
      name: e['name'] as String,
    ))
        .toList();
  }
}