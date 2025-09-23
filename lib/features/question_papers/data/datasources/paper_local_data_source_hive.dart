// features/question_papers/data/datasources/paper_local_data_source_hive.dart
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

  PaperLocalDataSourceHive(this._databaseHelper, this._logger);

  @override
  Future<void> saveDraft(QuestionPaperModel paper) async {
    try {
      _logger.paperAction('save_draft_started', paper.id, context: {
        'title': paper.title,
        'subject': paper.subject,
        'questionCount': _getTotalQuestionCount(paper.questions),
        'examType': paper.examType,
        'gradeLevel': paper.gradeLevel,
        'selectedSections': paper.selectedSections,
      });

      // Save to question_papers box
      await _databaseHelper.questionPapers.put(paper.id, _paperToMap(paper));

      // Save questions with paper_id as key prefix
      await _saveQuestions(paper.id, paper.questions);

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

  @override
  Future<List<QuestionPaperModel>> getDrafts() async {
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

      // Delete paper
      await _databaseHelper.questionPapers.delete(id);

      // Delete associated questions
      final deletedQuestionCount = await _deleteQuestions(id);

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

      // Delete papers and their questions
      for (final id in draftIds) {
        await _databaseHelper.questionPapers.delete(id);
        totalQuestionsDeleted += await _deleteQuestions(id);
      }

      _logger.info('All draft papers cleared successfully from Hive', category: LogCategory.storage, context: {
        'deletedPapers': draftIds.length,
        'deletedQuestions': totalQuestionsDeleted,
        'gradeStats': gradeStats,
        'paperTitles': draftTitles.take(5).toList(), // Log first 5 titles
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

      final allDrafts = await getDrafts();
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
      // Get all question keys for this paper
      final questionKeysToDelete = <String>[];
      final subQuestionKeysToDelete = <String>[];

      for (final entry in _databaseHelper.questions.toMap().entries) {
        final questionMap = entry.value;
        if (questionMap['paper_id'] == paperId) {
          questionKeysToDelete.add(entry.key);
        }
      }

      // Get sub-question keys
      for (final questionKey in questionKeysToDelete) {
        for (final entry in _databaseHelper.subQuestions.toMap().entries) {
          final subQuestionMap = entry.value;
          if (subQuestionMap['question_key'] == questionKey) {
            subQuestionKeysToDelete.add(entry.key);
          }
        }
      }

      // Delete sub-questions first
      for (final key in subQuestionKeysToDelete) {
        await _databaseHelper.subQuestions.delete(key);
      }

      // Delete questions
      for (final key in questionKeysToDelete) {
        await _databaseHelper.questions.delete(key);
      }

      final totalDeleted = questionKeysToDelete.length + subQuestionKeysToDelete.length;

      _logger.debug('Questions deleted from Hive', category: LogCategory.storage, context: {
        'paperId': paperId,
        'deletedQuestions': questionKeysToDelete.length,
        'deletedSubQuestions': subQuestionKeysToDelete.length,
        'totalDeleted': totalDeleted,
      });

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
      // Build questions map
      final questionsMap = <String, List<Question>>{};

      // Get all questions for this paper
      for (final entry in _databaseHelper.questions.toMap().entries) {
        final questionMap = entry.value;
        if (questionMap['paper_id'] == paperId) {
          final questionKey = entry.key;
          final sectionName = questionMap['section_name'] as String;

          // Get sub-questions for this question
          final subQuestions = <SubQuestion>[];
          for (final subEntry in _databaseHelper.subQuestions.toMap().entries) {
            final subQuestionMap = subEntry.value;
            if (subQuestionMap['question_key'] == questionKey) {
              subQuestions.add(SubQuestion(
                text: subQuestionMap['text'] as String,
                marks: subQuestionMap['marks'] as int,
              ));
            }
          }

          final question = Question(
            text: questionMap['question_text'] as String,
            type: questionMap['question_type'] as String,
            marks: questionMap['marks'] as int,
            isOptional: questionMap['is_optional'] as bool,
            correctAnswer: questionMap['correct_answer'] as String?,
            options: questionMap['options'] != null
                ? List<String>.from(jsonDecode(questionMap['options'] as String))
                : null,
            subQuestions: subQuestions,
          );

          questionsMap.putIfAbsent(sectionName, () => []).add(question);
        }
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
        gradeLevel: gradeLevel, // NEW FIELD
        selectedSections: selectedSections, // NEW FIELD
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

      _logger.debug('Paper built from Hive data', category: LogCategory.storage, context: {
        'paperId': paperId,
        'title': paper.title,
        'gradeLevel': paper.gradeLevel,
        'selectedSections': paper.selectedSections,
        'questionCount': _getTotalQuestionCount(questionsMap),
        'sections': questionsMap.keys.toList(),
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
}