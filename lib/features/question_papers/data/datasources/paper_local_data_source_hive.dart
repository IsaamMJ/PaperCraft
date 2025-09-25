// features/question_papers/data/datasources/paper_local_data_source_hive.dart
import 'dart:async';
import 'dart:convert';
import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/database/hive_database_helper.dart';
import '../models/question_paper_model.dart';
import '../../domain/entities/question_entity.dart';
import '../../domain/entities/exam_type_entity.dart';
import '../../domain/entities/paper_status.dart';
import 'paper_local_data_source.dart';

class PaperLocalDataSourceHive implements PaperLocalDataSource {
  final HiveDatabaseHelper _databaseHelper;
  final ILogger _logger;
  // Cache for indexed data to avoid rebuilding on every call
  Map<String, List<Map<String, dynamic>>>? _questionsByPaper;
  Map<String, List<Map<String, dynamic>>>? _subQuestionsByQuestion;
  DateTime? _lastIndexBuildTime;
  static const Duration _indexCacheTimeout = Duration(minutes: 5);

  // Concurrent access protection
  final Map<String, Future<void>> _operations = {};
  static final Map<String, bool> _operationLocks = {};

  PaperLocalDataSourceHive(this._databaseHelper, this._logger);

  void _buildIndexes() {
    // Check if indexes are still valid (within cache timeout)
    if (_questionsByPaper != null &&
        _subQuestionsByQuestion != null &&
        _lastIndexBuildTime != null &&
        DateTime.now().difference(_lastIndexBuildTime!) < _indexCacheTimeout) {
      return; // Use existing cache
    }

    _logger.debug('Building question indexes for better performance',
        category: LogCategory.storage);

    final startTime = DateTime.now();

    _questionsByPaper = <String, List<Map<String, dynamic>>>{};
    _subQuestionsByQuestion = <String, List<Map<String, dynamic>>>{};

    // Index questions by paper_id - O(n)
    int totalQuestions = 0;
    for (final entry in _databaseHelper.questions.toMap().entries) {
      final questionMap = entry.value;
      final paperId = questionMap['paper_id'] as String;

      _questionsByPaper!.putIfAbsent(paperId, () => []).add({
        'key': entry.key,
        ...questionMap,
      });
      totalQuestions++;
    }

    // Index sub-questions by question_key - O(m)
    int totalSubQuestions = 0;
    for (final entry in _databaseHelper.subQuestions.toMap().entries) {
      final subQuestionMap = entry.value;
      final questionKey = subQuestionMap['question_key'] as String;

      _subQuestionsByQuestion!.putIfAbsent(questionKey, () => []).add(subQuestionMap);
      totalSubQuestions++;
    }

    _lastIndexBuildTime = DateTime.now();
    final buildDuration = DateTime.now().difference(startTime);

    _logger.debug('Question indexes built successfully',
        category: LogCategory.storage,
        context: {
          'totalQuestions': totalQuestions,
          'totalSubQuestions': totalSubQuestions,
          'uniquePapers': _questionsByPaper!.length,
          'buildTimeMs': buildDuration.inMilliseconds,
        });
  }

  /// Call this when data changes to invalidate cache
  void _invalidateIndexes() {
    _questionsByPaper = null;
    _subQuestionsByQuestion = null;
    _lastIndexBuildTime = null;
    _logger.debug('Question indexes invalidated', category: LogCategory.storage);
  }

  /// Synchronizes operations for a specific paper to prevent concurrent access issues
  Future<T> _synchronizeOperation<T>(String paperId, Future<T> Function() operation) async {
    final key = 'paper_$paperId';

    // Wait for any existing operation on this paper
    final existingOperation = _operations[key];
    if (existingOperation != null) {
      try {
        await existingOperation;
      } catch (e) {
        // Ignore errors from previous operations
        _logger.debug('Previous operation failed, continuing with new operation',
            category: LogCategory.storage,
            context: {'paperId': paperId, 'error': e.toString()}
        );
      }
    }

    // Create and track the new operation
    final completer = Completer<void>();
    _operations[key] = completer.future;

    try {
      final result = await operation();
      completer.complete();
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      // Clean up completed operation
      if (_operations[key] == completer.future) {
        _operations.remove(key);
      }
    }
  }

  /// Synchronizes global operations (like clearAllDrafts) to prevent conflicts
  Future<T> _synchronizeGlobalOperation<T>(Future<T> Function() operation) async {
    const key = 'global_operation';

    // Wait for any existing global operation
    final existingOperation = _operations[key];
    if (existingOperation != null) {
      try {
        await existingOperation;
      } catch (e) {
        _logger.debug('Previous global operation failed, continuing with new operation',
            category: LogCategory.storage,
            context: {'error': e.toString()}
        );
      }
    }

    // Create and track the new operation
    final completer = Completer<void>();
    _operations[key] = completer.future;

    try {
      final result = await operation();
      completer.complete();
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      // Clean up completed operation
      if (_operations[key] == completer.future) {
        _operations.remove(key);
      }
    }
  }

  @override
  Future<void> saveDraft(QuestionPaperModel paper) async {
    return _synchronizeOperation(paper.id, () => _saveDraftInternal(paper));
  }

  Future<void> _saveDraftInternal(QuestionPaperModel paper) async {
    try {
      _logger.paperAction('save_draft_started', paper.id, context: {
        'title': paper.title,
        'subject': paper.subject,
        'questionCount': _getTotalQuestionCount(paper.questions),
        'examType': paper.examType,
        'gradeLevel': paper.gradeLevel,
        'selectedSections': paper.selectedSections,
      });

      // Use safe transaction for atomic operations
      await _safeTransaction(() async {
        // Save to question_papers box
        await _databaseHelper.questionPapers.put(paper.id, _paperToMap(paper));

        // Save questions with paper_id as key prefix
        await _saveQuestions(paper.id, paper.questions);
      });

      // Invalidate indexes after data changes
      _invalidateIndexes();

      _logger.paperAction('save_draft_success', paper.id, context: {
        'title': paper.title,
        'questionCount': _getTotalQuestionCount(paper.questions),
        'gradeLevel': paper.gradeLevel,
        'sectionsCount': paper.selectedSections.length,
        'storageType': 'hive_local',
      });
    } catch (e, stackTrace) {
      _logger.paperError('save_draft', paper.id, e, context: {
        'title': paper.title,
        'subject': paper.subject,
        'gradeLevel': paper.gradeLevel,
        'storageType': 'hive_local',
        'errorType': e.runtimeType.toString(),
        'stackTrace': stackTrace.toString(),
      });
      rethrow;
    }
  }

  // Enhanced safe transaction with better error handling
  Future<void> _safeTransaction(Function transaction) async {
    try {
      await transaction();
    } catch (e) {
      _logger.warning('Transaction failed, attempting rollback',
          category: LogCategory.storage,
          context: {'error': e.toString()}
      );

      try {
        // Rollback on any failure
        await _databaseHelper.questionPapers.compact();
        await _databaseHelper.questions.compact();
        await _databaseHelper.subQuestions.compact();
      } catch (rollbackError) {
        _logger.error('Rollback failed',
            category: LogCategory.storage,
            error: rollbackError
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> getDrafts() async {
    return _synchronizeGlobalOperation(() => _getDraftsInternal());
  }

  Future<List<QuestionPaperModel>> _getDraftsInternal() async {
    try {
      _logger.debug('Fetching all draft papers from Hive', category: LogCategory.storage);

      final paperMaps = _databaseHelper.questionPapers.values
          .where((paperMap) => paperMap['status'] == 'draft')
          .toList();

      final List<QuestionPaperModel> papers = [];

      for (final paperMap in paperMaps) {
        try {
          final paper = await _buildPaperFromMap(paperMap);
          papers.add(paper);
        } catch (e) {
          _logger.warning('Skipping corrupted draft paper', category: LogCategory.storage, context: {
            'paperId': paperMap['id']?.toString() ?? 'unknown',
            'error': e.toString(),
          });
          continue; // Skip corrupted papers instead of failing entirely
        }
      }

      // Sort by modified date (newest first)
      papers.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

      _logger.info('Fetched ${papers.length} draft papers from Hive', category: LogCategory.storage, context: {
        'totalFound': paperMaps.length,
        'successfullyLoaded': papers.length,
        'corrupted': paperMaps.length - papers.length,
      });

      return papers;
    } catch (e, stackTrace) {
      _logger.error('Failed to get draft papers from Hive',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<QuestionPaperModel?> getDraftById(String id) async {
    return _synchronizeOperation(id, () => _getDraftByIdInternal(id));
  }

  Future<QuestionPaperModel?> _getDraftByIdInternal(String id) async {
    try {
      _logger.debug('Fetching draft paper by ID from Hive', category: LogCategory.storage, context: {
        'paperId': id,
      });

      final paperMap = _databaseHelper.questionPapers.get(id);

      if (paperMap == null) {
        _logger.debug('Draft paper not found in Hive', category: LogCategory.storage, context: {
          'paperId': id,
          'reason': 'not_exists',
        });
        return null;
      }

      if (paperMap['status'] != 'draft') {
        _logger.debug('Paper found but not a draft', category: LogCategory.storage, context: {
          'paperId': id,
          'actualStatus': paperMap['status'],
          'reason': 'wrong_status',
        });
        return null;
      }

      final paper = await _buildPaperFromMap(paperMap);

      _logger.debug('Draft paper found in Hive', category: LogCategory.storage, context: {
        'paperId': id,
        'title': paper.title,
        'gradeLevel': paper.gradeLevel,
        'selectedSections': paper.selectedSections,
        'questionCount': _getTotalQuestionCount(paper.questions),
      });

      return paper;
    } catch (e, stackTrace) {
      _logger.error('Failed to get draft paper by ID from Hive',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {'paperId': id},
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteDraft(String id) async {
    return _synchronizeOperation(id, () => _deleteDraftInternal(id));
  }

  Future<void> _deleteDraftInternal(String id) async {
    try {
      // Get paper info before deletion for logging
      final paperMap = _databaseHelper.questionPapers.get(id);
      final title = paperMap?['title'] ?? 'unknown';
      final gradeLevel = paperMap?['grade_level'];

      _logger.paperAction('delete_draft_started', id, context: {
        'title': title,
        'gradeLevel': gradeLevel,
        'storageType': 'hive_local',
      });

      // Use safe transaction for atomic deletion
      int deletedQuestionCount = 0;
      await _safeTransaction(() async {
        // Delete associated questions first
        deletedQuestionCount = await _deleteQuestions(id);

        // Delete paper
        await _databaseHelper.questionPapers.delete(id);
      });

      // Invalidate indexes after data changes
      _invalidateIndexes();

      _logger.paperAction('delete_draft_success', id, context: {
        'title': title,
        'gradeLevel': gradeLevel,
        'deletedQuestions': deletedQuestionCount,
        'storageType': 'hive_local',
      });
    } catch (e, stackTrace) {
      _logger.paperError('delete_draft', id, e, context: {
        'storageType': 'hive_local',
        'errorType': e.runtimeType.toString(),
        'stackTrace': stackTrace.toString(),
      });
      rethrow;
    }
  }

  @override
  Future<void> clearAllDrafts() async {
    return _synchronizeGlobalOperation(() => _clearAllDraftsInternal());
  }

  Future<void> _clearAllDraftsInternal() async {
    try {
      _logger.info('Clearing all draft papers from Hive', category: LogCategory.storage);

      // Get all draft paper IDs
      final draftIds = <String>[];
      final draftTitles = <String>[];
      final gradeStats = <int, int>{};

      for (final entry in _databaseHelper.questionPapers.toMap().entries) {
        final paperMap = entry.value;
        if (paperMap['status'] == 'draft') {
          draftIds.add(entry.key);
          draftTitles.add(paperMap['title'] ?? 'untitled');

          // Track grade level statistics
          final gradeLevel = paperMap['grade_level'] as int?;
          if (gradeLevel != null) {
            gradeStats[gradeLevel] = (gradeStats[gradeLevel] ?? 0) + 1;
          }
        }
      }

      if (draftIds.isEmpty) {
        _logger.info('No draft papers to clear in Hive', category: LogCategory.storage);
        return;
      }

      int totalQuestionsDeleted = 0;

      // Use safe transaction for atomic bulk deletion
      await _safeTransaction(() async {
        // Delete papers and their questions
        for (final id in draftIds) {
          totalQuestionsDeleted += await _deleteQuestions(id);
          await _databaseHelper.questionPapers.delete(id);
        }
      });

      // Invalidate indexes after bulk deletion
      _invalidateIndexes();

      _logger.info('All draft papers cleared successfully from Hive', category: LogCategory.storage, context: {
        'deletedPapers': draftIds.length,
        'deletedQuestions': totalQuestionsDeleted,
        'gradeStats': gradeStats,
        'paperTitles': draftTitles.take(5).toList(),
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to clear draft papers from Hive',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> searchDrafts({
    String? subject,
    String? title,
    DateTime? fromDate,
    DateTime? toDate,
    int? gradeLevel,
    String? section,
  }) async {
    return _synchronizeGlobalOperation(() => _searchDraftsInternal(
      subject: subject,
      title: title,
      fromDate: fromDate,
      toDate: toDate,
      gradeLevel: gradeLevel,
      section: section,
    ));
  }

  Future<List<QuestionPaperModel>> _searchDraftsInternal({
    String? subject,
    String? title,
    DateTime? fromDate,
    DateTime? toDate,
    int? gradeLevel,
    String? section,
  }) async {
    try {
      _logger.debug('Searching draft papers in Hive with filters', category: LogCategory.storage, context: {
        'hasSubjectFilter': subject != null,
        'hasTitleFilter': title != null,
        'hasFromDateFilter': fromDate != null,
        'hasToDateFilter': toDate != null,
        'hasGradeLevelFilter': gradeLevel != null,
        'hasSectionFilter': section != null,
        'subject': subject,
        'titleQuery': title,
        'gradeLevel': gradeLevel,
        'section': section,
      });

      final allDrafts = await _getDraftsInternal(); // Use internal method to avoid double synchronization
      final initialCount = allDrafts.length;

      List<QuestionPaperModel> filteredDrafts = allDrafts;

      if (subject != null && subject.isNotEmpty) {
        filteredDrafts = filteredDrafts
            .where((paper) => paper.subject.toLowerCase().contains(subject.toLowerCase()))
            .toList();
      }

      if (title != null && title.isNotEmpty) {
        filteredDrafts = filteredDrafts
            .where((paper) => paper.title.toLowerCase().contains(title.toLowerCase()))
            .toList();
      }

      if (gradeLevel != null) {
        filteredDrafts = filteredDrafts
            .where((paper) => paper.gradeLevel == gradeLevel)
            .toList();
      }

      if (section != null && section.isNotEmpty) {
        filteredDrafts = filteredDrafts
            .where((paper) => paper.selectedSections.contains(section))
            .toList();
      }

      if (fromDate != null) {
        filteredDrafts = filteredDrafts
            .where((paper) => paper.modifiedAt.isAfter(fromDate) || paper.modifiedAt.isAtSameMomentAs(fromDate))
            .toList();
      }

      if (toDate != null) {
        filteredDrafts = filteredDrafts
            .where((paper) => paper.modifiedAt.isBefore(toDate) || paper.modifiedAt.isAtSameMomentAs(toDate))
            .toList();
      }

      _logger.info('Search completed for draft papers in Hive', category: LogCategory.storage, context: {
        'initialCount': initialCount,
        'filteredCount': filteredDrafts.length,
        'filters': {
          'subject': subject,
          'title': title,
          'gradeLevel': gradeLevel,
          'section': section,
          'fromDate': fromDate?.toIso8601String(),
          'toDate': toDate?.toIso8601String(),
        },
      });

      return filteredDrafts;
    } catch (e, stackTrace) {
      _logger.error('Failed to search draft papers in Hive',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {
          'searchFilters': {
            'subject': subject,
            'title': title,
            'gradeLevel': gradeLevel,
            'section': section,
            'fromDate': fromDate?.toIso8601String(),
            'toDate': toDate?.toIso8601String(),
          },
        },
      );
      rethrow;
    }
  }

  // Private helper methods

  Map<String, dynamic> _paperToMap(QuestionPaperModel paper) {
    return {
      'id': paper.id,
      'title': paper.title,
      'subject': paper.subject,
      'exam_type': paper.examType,
      'created_by': paper.createdBy,
      'created_at': paper.createdAt.millisecondsSinceEpoch,
      'modified_at': paper.modifiedAt.millisecondsSinceEpoch,
      'status': paper.status.value,
      'exam_type_entity': jsonEncode(paper.examTypeEntity.toJson()),
      'grade_level': paper.gradeLevel, // NEW FIELD
      'selected_sections': jsonEncode(paper.selectedSections), // NEW FIELD
      'tenant_id': paper.tenantId,
      'user_id': paper.userId,
      'submitted_at': paper.submittedAt?.millisecondsSinceEpoch,
      'reviewed_at': paper.reviewedAt?.millisecondsSinceEpoch,
      'reviewed_by': paper.reviewedBy,
      'rejection_reason': paper.rejectionReason,
    };
  }

  Future<void> _saveQuestions(String paperId, Map<String, List<Question>> questionsMap) async {
    try {
      // Clear existing questions for this paper
      await _deleteQuestions(paperId);

      int questionIndex = 0;
      int totalSubQuestions = 0;

      for (final entry in questionsMap.entries) {
        final sectionName = entry.key;
        final questions = entry.value;

        for (final question in questions) {
          final questionKey = '${paperId}_q_$questionIndex';

          final questionMap = {
            'paper_id': paperId,
            'section_name': sectionName,
            'question_text': question.text,
            'question_type': question.type,
            'marks': question.marks,
            'is_optional': question.isOptional,
            'correct_answer': question.correctAnswer,
            'options': question.options != null ? jsonEncode(question.options) : null,
          };

          await _databaseHelper.questions.put(questionKey, questionMap);

          // Save sub-questions
          for (int subIndex = 0; subIndex < question.subQuestions.length; subIndex++) {
            final subQuestion = question.subQuestions[subIndex];
            final subQuestionKey = '${questionKey}_sub_$subIndex';

            final subQuestionMap = {
              'question_key': questionKey,
              'text': subQuestion.text,
              'marks': subQuestion.marks,
            };

            await _databaseHelper.subQuestions.put(subQuestionKey, subQuestionMap);
            totalSubQuestions++;
          }

          questionIndex++;
        }
      }

      _logger.debug('Questions saved to Hive', category: LogCategory.storage, context: {
        'paperId': paperId,
        'totalQuestions': questionIndex,
        'totalSubQuestions': totalSubQuestions,
        'sections': questionsMap.keys.toList(),
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to save questions to Hive',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {'paperId': paperId},
      );
      rethrow;
    }
  }

  Future<int> _deleteQuestions(String paperId) async {
    try {
      // Use indexes if available, otherwise fall back to linear search
      _buildIndexes();

      final questionKeysToDelete = <String>[];
      final subQuestionKeysToDelete = <String>[];

      // Use indexed lookup if available and indexes exist
      if (_questionsByPaper != null && _subQuestionsByQuestion != null) {
        final paperQuestions = _questionsByPaper![paperId] ?? [];

        for (final questionData in paperQuestions) {
          final questionKey = questionData['key'] as String;
          questionKeysToDelete.add(questionKey);

          // Get sub-question keys using index
          final subQuestions = _subQuestionsByQuestion![questionKey] ?? [];
          for (final subQuestionData in subQuestions) {
            // Use the actual key from the sub-question data instead of reconstructing
            final subQuestionKey = subQuestionData['key'] as String;
            subQuestionKeysToDelete.add(subQuestionKey);
          }
        }
      } else {
        // Fallback to linear search if indexes are not available
        for (final entry in _databaseHelper.questions.toMap().entries) {
          final questionMap = entry.value;
          if (questionMap['paper_id'] == paperId) {
            questionKeysToDelete.add(entry.key);
          }
        }

        // Get sub-question keys using linear search
        for (final questionKey in questionKeysToDelete) {
          for (final entry in _databaseHelper.subQuestions.toMap().entries) {
            final subQuestionMap = entry.value;
            if (subQuestionMap['question_key'] == questionKey) {
              subQuestionKeysToDelete.add(entry.key);
            }
          }
        }
      }

      // Delete sub-questions first (to maintain referential integrity)
      for (final key in subQuestionKeysToDelete) {
        await _databaseHelper.subQuestions.delete(key);
      }

      // Delete questions
      for (final key in questionKeysToDelete) {
        await _databaseHelper.questions.delete(key);
      }

      final totalDeleted = questionKeysToDelete.length + subQuestionKeysToDelete.length;

      _logger.debug('Questions deleted from Hive',
          category: LogCategory.storage,
          context: {
            'paperId': paperId,
            'deletedQuestions': questionKeysToDelete.length,
            'deletedSubQuestions': subQuestionKeysToDelete.length,
            'totalDeleted': totalDeleted,
          }
      );

      return questionKeysToDelete.length;
    } catch (e, stackTrace) {
      _logger.error('Failed to delete questions from Hive',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {'paperId': paperId},
      );
      rethrow;
    }
  }

  Future<QuestionPaperModel> _buildPaperFromMap(Map<String, dynamic> paperMap) async {
    final paperId = paperMap['id'] as String;

    try {
      // Ensure indexes are built - this is O(1) if already cached
      _buildIndexes();

      // Build questions map - now O(1) lookup + O(k) where k is questions for this paper
      final questionsMap = <String, List<Question>>{};

      final paperQuestions = _questionsByPaper![paperId] ?? [];

      for (final questionData in paperQuestions) {
        final questionKey = questionData['key'];
        final sectionName = questionData['section_name'] as String;

        // Get sub-questions for this question - O(1) lookup + O(j) where j is sub-questions
        final subQuestionsData = _subQuestionsByQuestion![questionKey] ?? [];
        final subQuestions = subQuestionsData.map((subData) => SubQuestion(
          text: subData['text'] as String,
          marks: subData['marks'] as int,
        )).toList();

        final question = Question(
          text: questionData['question_text'] as String,
          type: questionData['question_type'] as String,
          marks: questionData['marks'] as int,
          isOptional: questionData['is_optional'] as bool,
          correctAnswer: questionData['correct_answer'] as String?,
          options: questionData['options'] != null
              ? List<String>.from(jsonDecode(questionData['options'] as String))
              : null,
          subQuestions: subQuestions,
        );

        questionsMap.putIfAbsent(sectionName, () => []).add(question);
      }

      // Parse exam type entity
      final examTypeEntityJson = jsonDecode(paperMap['exam_type_entity'] as String);
      final examTypeEntity = ExamTypeEntity.fromJson(examTypeEntityJson);

      // Parse grade level and selected sections (NEW FIELDS)
      final gradeLevel = paperMap['grade_level'] as int?;

      List<String> selectedSections = [];
      if (paperMap['selected_sections'] != null) {
        try {
          final sectionsJson = paperMap['selected_sections'] as String;
          selectedSections = List<String>.from(jsonDecode(sectionsJson));
        } catch (e) {
          // Handle legacy data that might not have this field
          selectedSections = [];
        }
      }

      final paper = QuestionPaperModel(
        id: paperMap['id'] as String,
        title: paperMap['title'] as String,
        subject: paperMap['subject'] as String,
        examType: paperMap['exam_type'] as String,
        createdBy: paperMap['created_by'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(paperMap['created_at'] as int),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(paperMap['modified_at'] as int),
        status: PaperStatus.fromString(paperMap['status'] as String),
        examTypeEntity: examTypeEntity,
        gradeLevel: gradeLevel,
        selectedSections: selectedSections,
        questions: questionsMap,
        tenantId: paperMap['tenant_id'] as String?,
        userId: paperMap['user_id'] as String?,
        submittedAt: paperMap['submitted_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(paperMap['submitted_at'] as int)
            : null,
        reviewedAt: paperMap['reviewed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(paperMap['reviewed_at'] as int)
            : null,
        reviewedBy: paperMap['reviewed_by'] as String?,
        rejectionReason: paperMap['rejection_reason'] as String?,
      );

      _logger.debug('Paper built from Hive data (optimized)', category: LogCategory.storage, context: {
        'paperId': paperId,
        'title': paper.title,
        'gradeLevel': paper.gradeLevel,
        'selectedSections': paper.selectedSections,
        'questionCount': _getTotalQuestionCount(questionsMap),
        'sections': questionsMap.keys.toList(),
        'performanceOptimized': true,
      });

      return paper;
    } catch (e, stackTrace) {
      _logger.error('Failed to build paper from Hive data',
        category: LogCategory.storage,
        error: e,
        stackTrace: stackTrace,
        context: {
          'paperId': paperId,
          'paperTitle': paperMap['title'],
        },
      );
      rethrow;
    }
  }

  int _getTotalQuestionCount(Map<String, List<Question>> questionsMap) {
    return questionsMap.values.fold(0, (total, questions) => total + questions.length);
  }

  /// Cleanup method to clear any pending operations (useful for testing or disposal)
  void dispose() {
    _operations.clear();
    _operationLocks.clear();
    _invalidateIndexes(); // Add this line
  }
}