// features/paper_workflow/domain/services/paper_display_service.dart
import '../../../catalog/domain/repositories/subject_repository.dart';
import '../../../catalog/domain/repositories/grade_repository.dart';
import '../entities/question_paper_entity.dart';
import '../../../../core/domain/interfaces/i_logger.dart';

/// Service to enrich papers with display names from catalog
class PaperDisplayService {
  final SubjectRepository _subjectRepository;
  final GradeRepository _gradeRepository;
  final ILogger _logger;

  // Cache for lookups
  final Map<String, String> _subjectCache = {};
  final Map<String, Map<String, dynamic>> _gradeCache = {};

  PaperDisplayService(
      this._subjectRepository,
      this._gradeRepository,
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

      // Load data in parallel
      await Future.wait([
        _loadSubjects(subjectIds),
        _loadGrades(gradeIds),
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

  QuestionPaperEntity _enrichSinglePaper(QuestionPaperEntity paper) {
    final subject = _subjectCache[paper.subjectId];
    final gradeData = _gradeCache[paper.gradeId];

    return paper.copyWith(
      subject: subject,
      grade: gradeData?['displayName'], // 'Grade X'
      gradeLevel: gradeData?['gradeNumber'], // X as int
      selectedSections: null,
    );
  }

  /// Clear all caches
  void clearCache() {
    _subjectCache.clear();
    _gradeCache.clear();
  }
}