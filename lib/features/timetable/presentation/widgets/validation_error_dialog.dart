import 'package:flutter/material.dart';

import '../utils/error_handler.dart';

/// Dialog for displaying validation errors
///
/// Shows validation errors in an organized, grouped format
/// with actionable feedback for the user.
class ValidationErrorDialog extends StatelessWidget {
  final List<String> errors;
  final VoidCallback onDismiss;

  const ValidationErrorDialog({
    required this.errors,
    required this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final groupedErrors = ValidationErrorFormatter.groupErrors(errors);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red[400],
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: const Text('Validation Errors'),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (errors.length == 1)
              _buildSingleErrorView(context)
            else
              _buildGroupedErrorsView(context, groupedErrors),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please correct the errors above before proceeding.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.blue[700],
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onDismiss();
          },
          child: const Text('Got It'),
        ),
      ],
    );
  }

  /// Build view for single error
  Widget _buildSingleErrorView(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.circle,
          size: 8,
          color: Colors.red[400],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            errors.first,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  /// Build view for grouped errors
  Widget _buildGroupedErrorsView(
    BuildContext context,
    Map<String, List<String>> grouped,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category header
            Text(
              entry.key,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
            ),
            const SizedBox(height: 8),
            // Error items
            ...entry.value.map((error) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 6,
                      color: Colors.red[400],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        error,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        );
      }).toList(),
    );
  }

  /// Show validation error dialog
  static void show(
    BuildContext context, {
    required List<String> errors,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      builder: (context) => ValidationErrorDialog(
        errors: errors,
        onDismiss: onDismiss ?? () {},
      ),
    );
  }
}

/// Snackbar extension for validation errors
extension ValidationErrorSnackBar on BuildContext {
  void showValidationError(List<String> errors) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(
          errors.length == 1
              ? errors.first
              : '${errors.length} validation errors found',
        ),
        backgroundColor: Colors.red[400],
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            ValidationErrorDialog.show(this, errors: errors);
          },
        ),
      ),
    );
  }

  void showErrorMessage(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
      ),
    );
  }

  void showSuccessMessage(String message) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[400],
      ),
    );
  }
}
