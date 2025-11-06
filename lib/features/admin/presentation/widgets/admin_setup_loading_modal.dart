import 'dart:math';

import 'package:flutter/material.dart';

/// Beautiful and smooth loading modal for admin setup completion
class AdminSetupLoadingModal extends StatefulWidget {
  final String message;

  const AdminSetupLoadingModal({
    super.key,
    this.message = 'Completing setup...',
  });

  @override
  State<AdminSetupLoadingModal> createState() => _AdminSetupLoadingModalState();
}

class _AdminSetupLoadingModalState extends State<AdminSetupLoadingModal>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    // Rotation animation for the spinner
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Pulse animation for the background circle
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    // Scale animation for the icon
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87.withAlpha(102),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(77, 33, 150, 243),
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
                // Animated background circle with pulse effect
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Pulse background
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1.0)
                          .animate(_pulseController),
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color.fromARGB(26, 33, 150, 243),
                        ),
                      ),
                    ),
                    // Inner circle
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.shade400,
                            Colors.blue.shade600,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(102, 33, 150, 243),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rotating spinner
                          RotationTransition(
                            turns: _rotationController,
                            child: Container(
                              width: 95,
                              height: 95,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color.fromARGB(77, 255, 255, 255),
                                  width: 3,
                                ),
                                gradient: const SweepGradient(
                                  colors: [
                                    Color.fromARGB(204, 255, 255, 255),
                                    Color.fromARGB(26, 255, 255, 255),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Center icon with scale animation
                          ScaleTransition(
                            scale: Tween<double>(begin: 0.8, end: 1.0)
                                .animate(_scaleController),
                            child: const Icon(
                              Icons.school,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Status message
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Loading dots animation
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final offset = sin(
                          (_pulseController.value * pi * 2) - (index * pi / 3),
                        );
                        final opacity = (offset + 1) / 2;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Opacity(
                            opacity: 0.3 + (opacity * 0.7),
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.shade400,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Helpful text
                Text(
                  'Please wait while we set up your school...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
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
