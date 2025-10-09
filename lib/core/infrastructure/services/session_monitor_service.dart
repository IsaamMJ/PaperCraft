import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/interfaces/i_logger.dart';

class SessionMonitorService {
  final ILogger _logger;
  Timer? _warningTimer;
  Timer? _expiryTimer;
  VoidCallback? _onSessionExpiring;
  VoidCallback? _onSessionExpired;

  static const _sessionDuration = Duration(hours: 1);
  static const _warningBeforeExpiry = Duration(minutes: 5);

  SessionMonitorService(this._logger);

  void startMonitoring({
    VoidCallback? onSessionExpiring,
    VoidCallback? onSessionExpired,
  }) {
    _onSessionExpiring = onSessionExpiring;
    _onSessionExpired = onSessionExpired;

    _warningTimer?.cancel();
    _expiryTimer?.cancel();

    // Set warning timer
    _warningTimer = Timer(_sessionDuration - _warningBeforeExpiry, () {
      _logger.warning('Session expiring soon', category: LogCategory.system);
      _onSessionExpiring?.call();
    });

    // Set expiry timer
    _expiryTimer = Timer(_sessionDuration, () {
      _logger.warning('Session expired', category: LogCategory.system);
      _onSessionExpired?.call();
    });

    _logger.info('Session monitoring started', category: LogCategory.system);
  }

  void resetTimer() {
    startMonitoring(
      onSessionExpiring: _onSessionExpiring,
      onSessionExpired: _onSessionExpired,
    );
  }

  void stopMonitoring() {
    _warningTimer?.cancel();
    _expiryTimer?.cancel();
    _logger.info('Session monitoring stopped', category: LogCategory.system);
  }

  void dispose() {
    stopMonitoring();
  }
}

class SessionWarningDialog extends StatelessWidget {
  final VoidCallback onExtendSession;

  const SessionWarningDialog({super.key, required this.onExtendSession});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Session Expiring Soon'),
        ],
      ),
      content: const Text(
        'Your session will expire in 5 minutes. Any unsaved changes will be lost. Would you like to extend your session?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Dismiss'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onExtendSession();
          },
          child: const Text('Extend Session'),
        ),
      ],
    );
  }
}
