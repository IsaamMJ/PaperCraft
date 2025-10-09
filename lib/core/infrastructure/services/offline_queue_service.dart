import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/interfaces/i_logger.dart';

enum QueuedActionType {
  submitPaper,
  approvePaper,
  rejectPaper,
}

class QueuedAction {
  final String id;
  final QueuedActionType type;
  final Map<String, dynamic> data;
  final DateTime queuedAt;
  int retryCount;
  DateTime? lastRetryAt;

  QueuedAction({
    required this.id,
    required this.type,
    required this.data,
    required this.queuedAt,
    this.retryCount = 0,
    this.lastRetryAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'data': data,
    'queuedAt': queuedAt.millisecondsSinceEpoch,
    'retryCount': retryCount,
    'lastRetryAt': lastRetryAt?.millisecondsSinceEpoch,
  };

  factory QueuedAction.fromJson(Map<String, dynamic> json) => QueuedAction(
    id: json['id'] as String,
    type: QueuedActionType.values.firstWhere((e) => e.name == json['type']),
    data: Map<String, dynamic>.from(json['data'] as Map),
    queuedAt: DateTime.fromMillisecondsSinceEpoch(json['queuedAt'] as int),
    retryCount: json['retryCount'] as int? ?? 0,
    lastRetryAt: json['lastRetryAt'] != null
        ? DateTime.fromMillisecondsSinceEpoch(json['lastRetryAt'] as int)
        : null,
  );
}

class OfflineQueueService {
  static const String _boxName = 'offline_queue';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 30);

  final ILogger _logger;
  Box<Map>? _queueBox;
  Timer? _processingTimer;

  OfflineQueueService(this._logger);

  Future<void> initialize() async {
    try {
      _queueBox = await Hive.openBox<Map>(_boxName);
      _startProcessingQueue();
      _logger.info('Offline queue initialized', category: LogCategory.storage);
    } catch (e, stackTrace) {
      _logger.error('Failed to initialize offline queue',
          category: LogCategory.storage, error: e, stackTrace: stackTrace);
    }
  }

  Future<void> queueAction(QueuedAction action) async {
    try {
      await _queueBox?.put(action.id, action.toJson());
      _logger.info('Action queued', category: LogCategory.storage, context: {
        'actionId': action.id,
        'type': action.type.name,
      });
    } catch (e) {
      _logger.error('Failed to queue action',
          category: LogCategory.storage, error: e);
    }
  }

  Future<void> removeFromQueue(String actionId) async {
    try {
      await _queueBox?.delete(actionId);
      _logger.info('Action removed from queue',
          category: LogCategory.storage, context: {'actionId': actionId});
    } catch (e) {
      _logger.error('Failed to remove action from queue',
          category: LogCategory.storage, error: e);
    }
  }

  List<QueuedAction> getPendingActions() {
    try {
      return _queueBox?.values
          .map((json) => QueuedAction.fromJson(Map<String, dynamic>.from(json)))
          .toList() ?? [];
    } catch (e) {
      _logger.error('Failed to get pending actions',
          category: LogCategory.storage, error: e);
      return [];
    }
  }

  void _startProcessingQueue() {
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(_retryDelay, (_) {
      _processQueue();
    });
  }

  Future<void> _processQueue() async {
    final actions = getPendingActions();

    for (final action in actions) {
      if (action.retryCount >= _maxRetries) {
        _logger.warning('Action exceeded max retries, removing from queue',
            category: LogCategory.storage, context: {'actionId': action.id});
        await removeFromQueue(action.id);
        continue;
      }

      // Check if enough time has passed since last retry
      if (action.lastRetryAt != null) {
        final timeSinceLastRetry = DateTime.now().difference(action.lastRetryAt!);
        if (timeSinceLastRetry < _retryDelay) {
          continue;
        }
      }

      _logger.info('Processing queued action',
          category: LogCategory.storage, context: {
        'actionId': action.id,
        'retryCount': action.retryCount,
      });

      // Retry will be handled by the repository/use case
      // This service just tracks the queue
      action.retryCount++;
      action.lastRetryAt = DateTime.now();
      await _queueBox?.put(action.id, action.toJson());
    }
  }

  int getQueuedCount() => _queueBox?.length ?? 0;

  Future<void> dispose() async {
    _processingTimer?.cancel();
    await _queueBox?.close();
  }
}
