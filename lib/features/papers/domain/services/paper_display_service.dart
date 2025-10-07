// features/papers/domain/services/paper_display_service.dart
import '../../../catalog/domain/repositories/subject_repository.dart';
import '../../../catalog/domain/repositories/grade_repository.dart';
import '../../../catalog/domain/repositories/exam_type_repository.dart';
import '../entities/question_paper_entity.dart';
import '../../../../core/domain/interfaces/i_logger.dart';

/// Service to enrich papers with display names from catalog
class PaperDisplayService {
  final SubjectRepository _subjectRepository;
  final GradeRepository _gradeRepository;
  final ExamTypeRepository _examTypeRepository;
  final ILogger _logger;

  // Cache for lookups
  final Map<String, String> _subjectCache = {};
  final Map<String, Map<String, dynamic>> _gradeCache = {};
  final Map<String, String> _examTypeCache = {};

  PaperDisplayService(
      this._subjectRepository,
      this._gradeRepository,
      this._examTypeRepository,
      this._logger,
      );

  /// Enrich a single paper with display data
  Future<QuestionPaperEntity> enrichPaper(QuestionPaperEntity paper) async {
    try {
      final enrichedList = await enrichPapers([paper]);
      return enrichedList.first;
    } catch (e) {
      _logger.warning('Failed to enrich paper, returning original',
          category: LogCategory.paper,
          context: {'paperId': paper.id, 'error': e.toString()});
      return paper;
    }
  }

  /// Enrich multiple papers with display data (batch operation)
  Future<List<QuestionPaperEntity>> enrichPapers(
      List<QuestionPaperEntity> papers) async {
    if (papers.isEmpty) return papers;

    try {
      // Collect all unique IDs
      final subjectIds = papers.map((p) => p.subjectId).toSet();
      final gradeIds = papers.map((p) => p.gradeId).toSet();
      final examTypeIds = papers.map((p) => p.examTypeId).toSet();

      // Load data in parallel
      await Future.wait([
        _loadSubjects(subjectIds),
        _loadGrades(gradeIds),
        _loadExamTypes(examTypeIds),
      ]);

      // Enrich all papers
      return papers.map((paper) => _enrichSinglePaper(paper)).toList();
    } catch (e) {
      _logger.error('Failed to enrich papers',
          category: LogCategory.paper, error: e);
      // Return original papers if enrichment fails
      return papers;
    }
  }

  Future<void> _loadSubjects(Set<String> ids) async {
    final uncachedIds = ids.where((id) => !_subjectCache.containsKey(id));
    if (uncachedIds.isEmpty) return;

    try {
      final result = await _subjectRepository.getSubjects();
      result.fold(
            (failure) => _logger.warning('Failed to load subjects',
            category: LogCategory.paper),
            (subjects) {
          for (final subject in subjects) {
            _subjectCache[subject.id] = subject.name;
          }
        },
      );
    } catch (e) {
      _logger.warning('Error loading subjects',
          category: LogCategory.paper, context: {'error': e.toString()});
    }
  }

  Future<void> _loadGrades(Set<String> ids) async {
    final uncachedIds = ids.where((id) => !_gradeCache.containsKey(id));
    if (uncachedIds.isEmpty) return;

    try {
      final result = await _gradeRepository.getGrades();
      result.fold(
            (failure) => _logger.warning('Failed to load grades',
            category: LogCategory.paper),
            (grades) {
          for (final grade in grades) {
            _gradeCache[grade.id] = {
              'displayName': grade.displayName, // 'Grade X'
              'gradeNumber': grade.gradeNumber,  // X
            };
          }
        },
      );
    } catch (e) {
      _logger.warning('Error loading grades',
          category: LogCategory.paper, context: {'error': e.toString()});
    }
  }

  Future<void> _loadExamTypes(Set<String> ids) async {
    final uncachedIds = ids.where((id) => !_examTypeCache.containsKey(id));
    if (uncachedIds.isEmpty) return;

    try {
      final result = await _examTypeRepository.getExamTypes();
      result.fold(
            (failure) => _logger.warning('Failed to load exam types',
            category: LogCategory.paper),
            (examTypes) {
          for (final examType in examTypes) {
            _examTypeCache[examType.id] = examType.name;
          }
        },
      );
    } catch (e) {
      _logger.warning('Error loading exam types',
          category: LogCategory.paper, context: {'error': e.toString()});
    }
  }

  QuestionPaperEntity _enrichSinglePaper(QuestionPaperEntity paper) {
    final subject = _subjectCache[paper.subjectId];
    final gradeData = _gradeCache[paper.gradeId];
    final examType = _examTypeCache[paper.examTypeId];

    return paper.copyWith(
      subject: subject,
      grade: gradeData?['displayName'], // 'Grade X'
      examType: examType,
      gradeLevel: gradeData?['gradeNumber'], // X as int
      // Note: Your GradeEntity doesn't have sections, so we leave it null
      // If you need sections, they should come from somewhere else
      selectedSections: null,
    );
  }

  /// Clear all caches
  void clearCache() {
    _subjectCache.clear();
    _gradeCache.clear();
    _examTypeCache.clear();
  }
}