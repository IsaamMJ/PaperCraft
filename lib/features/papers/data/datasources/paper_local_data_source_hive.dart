// features/question_papers/data/datasources/paper_local_data_source_hive.dart
import 'dart:async';
import 'dart:convert';
import 'package:papercraft/features/papers/data/datasources/paper_local_data_source.dart';

import '../../../../core/domain/interfaces/i_logger.dart';
import '../../../../core/infrastructure/database/hive_database_helper.dart';
import '../../domain/entities/question_entity.dart';
import '../models/question_paper_model.dart';
import '../../../catalog/domain/entities/exam_type_entity.dart';
import '../../domain/entities/paper_status.dart';

class PaperLocalDataSourceHive implements PaperLocalDataSource {
  final HiveDatabaseHelper _databaseHelper;
  final ILogger _logger;

  Map<String, List<Map<String, dynamic>>>? _questionsByPaper;
  Map<String, List<Map<String, dynamic>>>? _subQuestionsByQuestion;
  DateTime? _lastIndexBuildTime;
  static const Duration _indexCacheTimeout = Duration(minutes: 5);

  final Map<String, Future<void>> _operations = {};

  PaperLocalDataSourceHive(this._databaseHelper, this._logger);

  void _buildIndexes() {
    if (_questionsByPaper != null &&
        _subQuestionsByQuestion != null &&
        _lastIndexBuildTime != null &&
        DateTime.now().difference(_lastIndexBuildTime!) < _indexCacheTimeout) {
      return;
    }

    _logger.debug('Building question indexes', category: LogCategory.storage);

    final startTime = DateTime.now();
    _questionsByPaper = <String, List<Map<String, dynamic>>>{};
    _subQuestionsByQuestion = <String, List<Map<String, dynamic>>>{};

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

    int totalSubQuestions = 0;
    for (final entry in _databaseHelper.subQuestions.toMap().entries) {
      final subQuestionMap = entry.value;
      final questionKey = subQuestionMap['question_key'] as String;

      _subQuestionsByQuestion!.putIfAbsent(questionKey, () => []).add({
        'key': entry.key,
        ...subQuestionMap,
      });
      totalSubQuestions++;
    }

    _lastIndexBuildTime = DateTime.now();
    final buildDuration = DateTime.now().difference(startTime);

    _logger.debug('Question indexes built', category: LogCategory.storage, context: {
      'totalQuestions': totalQuestions,
      'totalSubQuestions': totalSubQuestions,
      'buildTimeMs': buildDuration.inMilliseconds,
    });
  }

  void _invalidateIndexes() {
    _questionsByPaper = null;
    _subQuestionsByQuestion = null;
    _lastIndexBuildTime = null;
  }

  Future<T> _synchronizeOperation<T>(String paperId, Future<T> Function() operation) async {
    final key = 'paper_$paperId';
    final existingOperation = _operations[key];

    if (existingOperation != null) {
      try {
        await existingOperation;
      } catch (e) {
        _logger.debug('Previous operation failed', category: LogCategory.storage);
      }
    }

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
      if (_operations[key] == completer.future) {
        _operations.remove(key);
      }
    }
  }

  Future<T> _synchronizeGlobalOperation<T>(Future<T> Function() operation) async {
    const key = 'global_operation';
    final existingOperation = _operations[key];

    if (existingOperation != null) {
      try {
        await existingOperation;
      } catch (e) {
        _logger.debug('Previous global operation failed', category: LogCategory.storage);
      }
    }

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
        'subjectId': paper.subjectId,
        'gradeId': paper.gradeId,
        'questionCount': _getTotalQuestionCount(paper.questions),
      });

      await _safeTransaction(() async {
        await _databaseHelper.questionPapers.put(paper.id, _paperToMap(paper));
        await _saveQuestions(paper.id, paper.questions);
      });

      _invalidateIndexes();

      _logger.paperAction('save_draft_success', paper.id, context: {
        'title': paper.title,
        'questionCount': _getTotalQuestionCount(paper.questions),
      });
    } catch (e, stackTrace) {
      _logger.paperError('save_draft', paper.id, e);
      rethrow;
    }
  }

  Future<void> _safeTransaction(Function transaction) async {
    try {
      await transaction();
    } catch (e) {
      _logger.warning('Transaction failed', category: LogCategory.storage);
      try {
        await _databaseHelper.questionPapers.compact();
        await _databaseHelper.questions.compact();
        await _databaseHelper.subQuestions.compact();
      } catch (rollbackError) {
        _logger.error('Rollback failed', category: LogCategory.storage, error: rollbackError);
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
      _logger.debug('Fetching drafts from Hive', category: LogCategory.storage);

      final paperMaps = _databaseHelper.questionPapers.values
          .where((paperMap) => paperMap['status'] == 'draft')
          .toList();

      final List<QuestionPaperModel> papers = [];

      for (final paperMap in paperMaps) {
        try {
          final paper = await _buildPaperFromMap(paperMap);
          papers.add(paper);
        } catch (e) {
          _logger.warning('Skipping corrupted draft', category: LogCategory.storage, context: {
            'paperId': paperMap['id']?.toString() ?? 'unknown',
            'error': e.toString(),
          });
          continue;
        }
      }

      papers.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

      _logger.info('Fetched drafts from Hive', category: LogCategory.storage, context: {
        'successfullyLoaded': papers.length,
        'corrupted': paperMaps.length - papers.length,
      });

      return papers;
    } catch (e, stackTrace) {
      _logger.error('Failed to get drafts', category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<QuestionPaperModel?> getDraftById(String id) async {
    return _synchronizeOperation(id, () => _getDraftByIdInternal(id));
  }

  Future<QuestionPaperModel?> _getDraftByIdInternal(String id) async {
    try {
      final paperMap = _databaseHelper.questionPapers.get(id);

      if (paperMap == null) {
        return null;
      }

      if (paperMap['status'] != 'draft') {
        return null;
      }

      return await _buildPaperFromMap(paperMap);
    } catch (e, stackTrace) {
      _logger.error('Failed to get draft by ID', category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<void> deleteDraft(String id) async {
    return _synchronizeOperation(id, () => _deleteDraftInternal(id));
  }

  Future<void> _deleteDraftInternal(String id) async {
    try {
      final paperMap = _databaseHelper.questionPapers.get(id);
      final title = paperMap?['title'] ?? 'unknown';

      _logger.paperAction('delete_draft_started', id, context: {'title': title});

      int deletedQuestionCount = 0;
      await _safeTransaction(() async {
        deletedQuestionCount = await _deleteQuestions(id);
        await _databaseHelper.questionPapers.delete(id);
      });

      _invalidateIndexes();

      _logger.paperAction('delete_draft_success', id, context: {
        'title': title,
        'deletedQuestions': deletedQuestionCount,
      });
    } catch (e, stackTrace) {
      _logger.paperError('delete_draft', id, e);
      rethrow;
    }
  }

  @override
  Future<void> clearAllDrafts() async {
    return _synchronizeGlobalOperation(() => _clearAllDraftsInternal());
  }

  Future<void> _clearAllDraftsInternal() async {
    try {
      _logger.info('Clearing all drafts', category: LogCategory.storage);

      final draftIds = <String>[];

      for (final entry in _databaseHelper.questionPapers.toMap().entries) {
        final paperMap = entry.value;
        if (paperMap['status'] == 'draft') {
          draftIds.add(entry.key);
        }
      }

      if (draftIds.isEmpty) {
        _logger.info('No drafts to clear', category: LogCategory.storage);
        return;
      }

      int totalQuestionsDeleted = 0;

      await _safeTransaction(() async {
        for (final id in draftIds) {
          totalQuestionsDeleted += await _deleteQuestions(id);
          await _databaseHelper.questionPapers.delete(id);
        }
      });

      _invalidateIndexes();

      _logger.info('All drafts cleared', category: LogCategory.storage, context: {
        'deletedPapers': draftIds.length,
        'deletedQuestions': totalQuestionsDeleted,
      });
    } catch (e, stackTrace) {
      _logger.error('Failed to clear drafts', category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  @override
  Future<List<QuestionPaperModel>> searchDrafts({
    String? subject,
    String? title,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    return _synchronizeGlobalOperation(() => _searchDraftsInternal(
      subject: subject,
      title: title,
      fromDate: fromDate,
      toDate: toDate,
    ));
  }

  Future<List<QuestionPaperModel>> _searchDraftsInternal({
    String? subject,
    String? title,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final allDrafts = await _getDraftsInternal();
      List<QuestionPaperModel> filteredDrafts = allDrafts;

      // Note: We can't filter by subject name anymore since we only have subjectId
      // This would need to be done at repository layer with subject lookup

      if (title != null && title.isNotEmpty) {
        filteredDrafts = filteredDrafts
            .where((paper) => paper.title.toLowerCase().contains(title.toLowerCase()))
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

      return filteredDrafts;
    } catch (e, stackTrace) {
      _logger.error('Failed to search drafts', category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Private helper methods

  Map<String, dynamic> _paperToMap(QuestionPaperModel paper) {
    return <String, dynamic>{
      'id': paper.id,
      'title': paper.title,
      'subject_id': paper.subjectId,
      'grade_id': paper.gradeId,
      'exam_type_id': paper.examTypeId,
      'academic_year': paper.academicYear,
      'created_by': paper.createdBy,
      'created_at': paper.createdAt.millisecondsSinceEpoch,
      'modified_at': paper.modifiedAt.millisecondsSinceEpoch,
      'status': paper.status.value,
      'exam_type_entity': jsonEncode(paper.examTypeEntity.toJson()),
      'exam_date': paper.examDate?.millisecondsSinceEpoch,
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
    } catch (e, stackTrace) {
      _logger.error('Failed to save questions', category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<int> _deleteQuestions(String paperId) async {
    try {
      _buildIndexes();

      final questionKeysToDelete = <String>[];
      final subQuestionKeysToDelete = <String>[];

      if (_questionsByPaper != null && _subQuestionsByQuestion != null) {
        final paperQuestions = _questionsByPaper![paperId] ?? [];

        for (final questionData in paperQuestions) {
          final questionKey = questionData['key'] as String;
          questionKeysToDelete.add(questionKey);

          final subQuestions = _subQuestionsByQuestion![questionKey] ?? [];
          for (final subQuestionData in subQuestions) {
            final subQuestionKey = subQuestionData['key'] as String;
            subQuestionKeysToDelete.add(subQuestionKey);
          }
        }
      } else {
        for (final entry in _databaseHelper.questions.toMap().entries) {
          final questionMap = entry.value;
          if (questionMap['paper_id'] == paperId) {
            questionKeysToDelete.add(entry.key);
          }
        }

        for (final questionKey in questionKeysToDelete) {
          for (final entry in _databaseHelper.subQuestions.toMap().entries) {
            final subQuestionMap = entry.value;
            if (subQuestionMap['question_key'] == questionKey) {
              subQuestionKeysToDelete.add(entry.key);
            }
          }
        }
      }

      for (final key in subQuestionKeysToDelete) {
        await _databaseHelper.subQuestions.delete(key);
      }

      for (final key in questionKeysToDelete) {
        await _databaseHelper.questions.delete(key);
      }

      return questionKeysToDelete.length;
    } catch (e, stackTrace) {
      _logger.error('Failed to delete questions', category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<QuestionPaperModel> _buildPaperFromMap(Map<String, dynamic> paperMap) async {
    final paperId = paperMap['id'] as String;

    try {
      _buildIndexes();

      final questionsMap = <String, List<Question>>{};
      final paperQuestions = _questionsByPaper![paperId] ?? [];

      for (final questionData in paperQuestions) {
        final questionKey = questionData['key'];
        final sectionName = questionData['section_name'] as String;

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

      final examTypeEntityJson = jsonDecode(paperMap['exam_type_entity'] as String);
      final examTypeEntity = ExamTypeEntity.fromJson(examTypeEntityJson);

      final paper = QuestionPaperModel(
        id: paperMap['id'] as String,
        title: paperMap['title'] as String,
        subjectId: paperMap['subject_id'] as String,
        gradeId: paperMap['grade_id'] as String,
        examTypeId: paperMap['exam_type_id'] as String,
        academicYear: paperMap['academic_year'] as String,
        createdBy: paperMap['created_by'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(paperMap['created_at'] as int),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(paperMap['modified_at'] as int),
        status: PaperStatus.fromString(paperMap['status'] as String),
        examTypeEntity: examTypeEntity,
        questions: questionsMap,
        examDate: paperMap['exam_date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(paperMap['exam_date'] as int)
            : null,
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

      return paper;
    } catch (e, stackTrace) {
      _logger.error('Failed to build paper from Hive', category: LogCategory.storage, error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  int _getTotalQuestionCount(Map<String, List<Question>> questionsMap) {
    return questionsMap.values.fold(0, (total, questions) => total + questions.length);
  }

  void dispose() {
    _operations.clear();
    _invalidateIndexes();
  }
}