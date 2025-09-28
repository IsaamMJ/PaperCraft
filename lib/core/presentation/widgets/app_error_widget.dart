// app_error_widget.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routes/app_routes.dart';
import '../constants/app_messages.dart';
import '../constants/ui_constants.dart';

/// Unified error widget for all error scenarios
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.error_outline,
    this.color = Colors.red,
    this.showError = false,
    this.error,
    this.onBackPressed,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final bool showError;
  final Object? error;
  final VoidCallback? onBackPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(UIConstants.largePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: UIConstants.largeIconSize,
                color: color,
              ),
              const SizedBox(height: UIConstants.defaultSpacing),
              Text(
                title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: UIConstants.smallSpacing),
              Text(
                message,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (showError && error != null) ...[
                const SizedBox(height: UIConstants.defaultSpacing),
                Text(
                  '${AppMessages.errorPrefix}${error.toString()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: UIConstants.largeSpacing),
              ElevatedButton.icon(
                onPressed: onBackPressed ?? () => _handleBack(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text(AppMessages.goBack),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go(AppRoutes.home);
    }
  }
}

/// Loading screen widget
class AppLoadingWidget extends StatelessWidget {
  const AppLoadingWidget({
    super.key,
    this.message = AppMessages.loading,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: UIConstants.defaultSpacing),
            Text(message),
          ],
        ),
      ),
    );
  }
}

/// Simple message widget
class AppMessageWidget extends StatelessWidget {
  const AppMessageWidget({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text(message)),
    );
  }
}