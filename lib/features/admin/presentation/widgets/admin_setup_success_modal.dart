import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/routes/app_routes.dart';
import '../../../authentication/presentation/bloc/auth_bloc.dart';
import '../../../authentication/presentation/bloc/auth_state.dart';
import '../../../authentication/presentation/bloc/auth_event.dart';

/// Success modal shown after admin setup completion
class AdminSetupSuccessModal extends StatefulWidget {
  const AdminSetupSuccessModal({super.key});

  @override
  State<AdminSetupSuccessModal> createState() => _AdminSetupSuccessModalState();
}

class _AdminSetupSuccessModalState extends State<AdminSetupSuccessModal>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    // Scale animation for the checkmark
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    // Fade animation for the text
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  /// Navigate to home
  void _navigateToDashboard(BuildContext context) {
    if (context.mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(102),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(77, 76, 175, 80),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated checkmark circle
                ScaleTransition(
                  scale: Tween<double>(begin: 0, end: 1).animate(
                    CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
                  ),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.green.shade400,
                          Colors.green.shade600,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color.fromARGB(102, 76, 175, 80),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 70,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Success message
                FadeTransition(
                  opacity: _fadeController,
                  child: Column(
                    children: [
                      const Text(
                        'Setup Completed!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your school has been set up successfully.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Redirecting you to the dashboard...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Manual navigation button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            _navigateToDashboard(context);
                          },
                          child: const Text(
                            'Go to Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
