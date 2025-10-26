// lib/features/paper_creation/presentation/dialogs/submission_feedback_dialog.dart
import 'package:flutter/material.dart';
import '../../../../core/presentation/constants/app_colors.dart';

/// Dialog showing submission progress with loading and success states
class SubmissionFeedbackDialog extends StatefulWidget {
  final VoidCallback onComplete;

  const SubmissionFeedbackDialog({
    Key? key,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<SubmissionFeedbackDialog> createState() => _SubmissionFeedbackDialogState();
}

class _SubmissionFeedbackDialogState extends State<SubmissionFeedbackDialog>
    with TickerProviderStateMixin {
  late AnimationController _spinnerController;
  late AnimationController _successController;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _spinnerController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _successController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Show loading for 1.5 seconds, then switch to success
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _showSuccess = true);
        _spinnerController.stop();
        _successController.forward();

        // Show success for 1.5 seconds, then complete
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            widget.onComplete();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _spinnerController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissing dialog
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_showSuccess) ...[
                // Loading spinner
                SizedBox(
                  height: 60,
                  width: 60,
                  child: RotationTransition(
                    turns: _spinnerController,
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Submitting Paper...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please wait while we submit your paper',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ] else ...[
                // Success checkmark with scale animation
                ScaleTransition(
                  scale: Tween<double>(begin: 0, end: 1).animate(
                    CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
                  ),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.check_circle,
                        size: 60,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Paper Submitted!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your paper has been submitted successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Redirecting to home...',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
