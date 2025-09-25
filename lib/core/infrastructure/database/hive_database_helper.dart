// core/infrastructure/database/hive_database_helper.dart
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/interfaces/i_logger.dart';
import '../../domain/interfaces/i_feature_flags.dart';
import '../config/database_config.dart';
import '../utils/platform_utils.dart';

class HiveDatabaseHelper {
  final ILogger _logger;
  final IFeatureFlags _featureFlags;

  // Use DatabaseConfig for box names to make them configurable
  static String get questionPapersBox => DatabaseConfig.hiveDatabaseBoxes['questionPapers'] ?? 'question_papers';
  static String get questionsBox => DatabaseConfig.hiveDatabaseBoxes['questions'] ?? 'questions';
  static String get subQuestionsBox => DatabaseConfig.hiveDatabaseBoxes['subQuestions'] ?? 'sub_questions';

  bool _initialized = false;

  HiveDatabaseHelper(this._logger, this._featureFlags);

  Future<void> initialize() async {
    if (_initialized) {
      if (_featureFlags.enableDebugLogging) {
        _logger.debug('Hive database already initialized', category: LogCategory.storage, context: {
          'alreadyInitialized': true,
          'boxCount': 3,
        });
      }
      return;
    }

    final initStartTime = DateTime.now();

    _logger.info('Starting Hive database initialization', category: LogCategory.storage, context: {
      'platform': PlatformUtils.platformName,
      'boxes': [questionPapersBox, questionsBox, subQuestionsBox],
      'startTime': initStartTime.toIso8601String(),
      ...PlatformUtils.platformContext,
    });

    try {
      // Initialize Hive
      if (_featureFlags.enableDebugLogging) {
        _logger.debug('Initializing Hive Flutter', category: LogCategory.storage);
      }
      await Hive.initFlutter();

      if (_featureFlags.enableDebugLogging) {
        _logger.debug('Hive Flutter initialized, opening boxes', category: LogCategory.storage);
      }

      // Open boxes with individual logging
      if (_featureFlags.enableDebugLogging) {
        _logger.debug('Opening question papers box', category: LogCategory.storage);
      }
      await Hive.openBox(questionPapersBox);

      if (_featureFlags.enableDebugLogging) {
        _logger.debug('Opening questions box', category: LogCategory.storage);
      }
      await Hive.openBox(questionsBox);

      if (_featureFlags.enableDebugLogging) {
        _logger.debug('Opening sub-questions box', category: LogCategory.storage);
      }
      await Hive.openBox(subQuestionsBox);

      _initialized = true;

      final initDuration = DateTime.now().difference(initStartTime);
      final dbInfo = await getDatabaseInfo();

      _logger.info('Hive database initialized successfully', category: LogCategory.storage, context: {
        'initDuration': '${initDuration.inMilliseconds}ms',
        'platform': PlatformUtils.platformName,
        'boxesOpened': 3,
        'existingData': {
          'questionPapers': dbInfo['question_papers_count'],
          'questions': dbInfo['questions_count'],
          'subQuestions': dbInfo['sub_questions_count'],
        },
        'completedAt': DateTime.now().toIso8601String(),
        ...PlatformUtils.platformContext,
      });

    } catch (e, stackTrace) {
      final initDuration = DateTime.now().difference(initStartTime);

      _logger.critical('Failed to initialize Hive database',
          error: e,
          stackTrace: stackTrace,
          category: LogCategory.storage,
          context: {
            'failedAfter': '${initDuration.inMilliseconds}ms',
            'platform': PlatformUtils.platformName,
            'errorType': e.runtimeType.toString(),
            'criticalFailure': true,
            ...PlatformUtils.platformContext,
          }
      );

      rethrow;
    }
  }

  Box get questionPapers {
    if (!_initialized) {
      _logger.error('Attempting to access questionPapers box before initialization',
          category: LogCategory.storage,
          context: {'operation': 'questionPapers_box_access'});
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return Hive.box(questionPapersBox);
  }

  Box get questions {
    if (!_initialized) {
      _logger.error('Attempting to access questions box before initialization',
          category: LogCategory.storage,
          context: {'operation': 'questions_box_access'});
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return Hive.box(questionsBox);
  }

  Box get subQuestions {
    if (!_initialized) {
      _logger.error('Attempting to access subQuestions box before initialization',
          category: LogCategory.storage,
          context: {'operation': 'subQuestions_box_access'});
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return Hive.box(subQuestionsBox);
  }


  Future<void> close() async {
    _logger.info('Closing Hive database', category: LogCategory.storage, context: {
      'initialized': _initialized,
      'closeTime': DateTime.now().toIso8601String(),
      'platform': PlatformUtils.platformName,
    });

    try {
      if (_initialized && _featureFlags.enableDebugLogging) {
        final dbInfo = await getDatabaseInfo();

        _logger.debug('Database info before close', category: LogCategory.storage, context: {
          'dataBeforeClose': dbInfo,
        });
      }

      await Hive.close();
      _initialized = false;

      _logger.info('Hive database closed successfully', category: LogCategory.storage, context: {
        'closedAt': DateTime.now().toIso8601String(),
        'initialized': false,
        'platform': PlatformUtils.platformName,
      });

    } catch (e, stackTrace) {
      _logger.error('Error closing Hive database',
          error: e,
          stackTrace: stackTrace,
          category: LogCategory.storage,
          context: {
            'errorType': e.runtimeType.toString(),
            'operation': 'database_close',
            'platform': PlatformUtils.platformName,
          }
      );
    }
  }

  Future<void> clearAllData() async {
    _logger.warning('Clearing all Hive data', category: LogCategory.storage, context: {
      'operation': 'clear_all_data',
      'destructive': true,
      'timestamp': DateTime.now().toIso8601String(),
      'platform': PlatformUtils.platformName,
    });

    try {
      final beforeClear = await getDatabaseInfo();

      if (_featureFlags.enableDebugLogging) {
        _logger.debug('Data before clearing', category: LogCategory.storage, context: {
          'dataBeforeClear': beforeClear,
        });
      }

      await questionPapers.clear();
      if (_featureFlags.enableDebugLogging) {
        _logger.debug('Question papers box cleared', category: LogCategory.storage);
      }

      await questions.clear();
      if (_featureFlags.enableDebugLogging) {
        _logger.debug('Questions box cleared', category: LogCategory.storage);
      }

      await subQuestions.clear();
      if (_featureFlags.enableDebugLogging) {
        _logger.debug('Sub-questions box cleared', category: LogCategory.storage);
      }

      final afterClear = await getDatabaseInfo();

      _logger.info('All Hive data cleared successfully', category: LogCategory.storage, context: {
        'dataCleared': {
          'questionPapers': beforeClear['question_papers_count'],
          'questions': beforeClear['questions_count'],
          'subQuestions': beforeClear['sub_questions_count'],
        },
        'dataAfterClear': afterClear,
        'completedAt': DateTime.now().toIso8601String(),
        'platform': PlatformUtils.platformName,
      });

    } catch (e, stackTrace) {
      _logger.error('Failed to clear Hive data',
          error: e,
          stackTrace: stackTrace,
          category: LogCategory.storage,
          context: {
            'errorType': e.runtimeType.toString(),
            'operation': 'clear_all_data',
            'criticalOperation': true,
            'platform': PlatformUtils.platformName,
          }
      );

      rethrow;
    }
  }

  Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      final info = {
        'initialized': _initialized,
        'question_papers_count': _initialized ? questionPapers.length : 0,
        'questions_count': _initialized ? questions.length : 0,
        'sub_questions_count': _initialized ? subQuestions.length : 0,
        'platform': PlatformUtils.platformName,
        'timestamp': DateTime.now().toIso8601String(),
        ...PlatformUtils.platformContext,
      };

      if (_featureFlags.enableDebugLogging) {
        _logger.debug('Database info retrieved', category: LogCategory.storage, context: {
          'databaseInfo': info,
        });
      }

      return info;
    } catch (e, stackTrace) {
      _logger.warning('Error getting database info', category: LogCategory.storage, context: {
        'error': e.toString(),
        'fallbackInfo': {
          'initialized': _initialized,
          'error': 'could_not_get_counts',
        },
        'platform': PlatformUtils.platformName,
      });

      return {
        'initialized': _initialized,
        'question_papers_count': 0,
        'questions_count': 0,
        'sub_questions_count': 0,
        'platform': PlatformUtils.platformName,
        'error': 'could_not_retrieve_info',
        'timestamp': DateTime.now().toIso8601String(),
        ...PlatformUtils.platformContext,
      };
    }
  }

  Future<void> compact() async {
    if (!_initialized) {
      if (_featureFlags.enableDebugLogging) {
        _logger.warning('Cannot compact database - not initialized', category: LogCategory.storage);
      }
      return;
    }

    _logger.info('Starting database compaction', category: LogCategory.storage, context: {
      'operation': 'compact_database',
      'beforeCompact': await getDatabaseInfo(),
    });

    try {
      await questionPapers.compact();
      await questions.compact();
      await subQuestions.compact();

      _logger.info('Database compaction completed', category: LogCategory.storage, context: {
        'operation': 'compact_database',
        'success': true,
        'completedAt': DateTime.now().toIso8601String(),
        'platform': PlatformUtils.platformName,
      });

    } catch (e, stackTrace) {
      _logger.error('Database compaction failed',
          error: e,
          stackTrace: stackTrace,
          category: LogCategory.storage,
          context: {
            'operation': 'compact_database',
            'errorType': e.runtimeType.toString(),
            'platform': PlatformUtils.platformName,
          }
      );
    }
  }

  Future<int> getTotalStorageSize() async {
    if (!_initialized) {
      return 0;
    }

    try {
      // This is an approximation - exact size calculation would require platform-specific code
      final totalEntries = questionPapers.length + questions.length + subQuestions.length;

      if (_featureFlags.enableDebugLogging) {
        _logger.debug('Storage size calculated', category: LogCategory.storage, context: {
          'totalEntries': totalEntries,
          'approximateSize': '${totalEntries * 100}bytes', // Rough estimate
          'platform': PlatformUtils.platformName,
        });
      }

      return totalEntries;
    } catch (e) {
      if (_featureFlags.enableDebugLogging) {
        _logger.warning('Could not calculate storage size', category: LogCategory.storage, context: {
          'error': e.toString(),
          'platform': PlatformUtils.platformName,
        });
      }
      return 0;
    }
  }

  // Getter for initialization status (useful for testing)
  bool get isInitialized => _initialized;
}