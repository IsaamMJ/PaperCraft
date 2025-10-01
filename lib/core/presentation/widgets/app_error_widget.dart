// app_error_widget.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routes/app_routes.dart';
import '../constants/app_messages.dart';
import '../constants/ui_constants.dart';

/// Unified error widgets for all error scenarios
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
          padding: const EdgeInsets.all(UIConstants.paddingLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: UIConstants.iconHuge,
                color: color,
              ),
              SizedBox(height: UIConstants.spacing16),
              Text(
                title,
                style: TextStyle(fontSize: UIConstants.fontSizeXXLarge, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: UIConstants.spacing8),
              Text(
                message,
                style: TextStyle(fontSize: UIConstants.fontSizeLarge),
                textAlign: TextAlign.center,
              ),
              if (showError && error != null) ...[
                SizedBox(height: UIConstants.spacing16),
                Text(
                  '${AppMessages.errorPrefix}${error.toString()}',
                  style: TextStyle(fontSize: UIConstants.fontSizeSmall, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
              SizedBox(height: UIConstants.spacing24),
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

/// Loading screen widgets
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
            SizedBox(height: UIConstants.spacing16),
            Text(message),
          ],
        ),
      ),
    );
  }
}

/// Simple message widgets
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