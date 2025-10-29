import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/ui_constants.dart';

class UiHelpers {
  UiHelpers._();

  /// Show success message
  /// Show success message
  static void showSuccessMessage(BuildContext context, String message) {
    _showMessage(context, message, AppColors.success, Icons.check_circle);
  }

  /// Show error message
  static void showErrorMessage(BuildContext context, String message) {
    _showMessage(context, message, AppColors.error, Icons.error);
  }

  /// Show warning message
  static void showWarningMessage(BuildContext context, String message) {
    _showMessage(context, message, AppColors.warning, Icons.warning);
  }

  /// Show info message
  static void showInfoMessage(BuildContext context, String message) {
    _showMessage(context, message, AppColors.primary, Icons.info);
  }

  static void _showMessage(
      BuildContext context,
      String message,
      Color color,
      IconData icon,
      ) {
    try {
      // Clear any previously shown SnackBars to avoid stacking
      ScaffoldMessenger.of(context).clearSnackBars();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: UIConstants.iconMedium),
              SizedBox(width: UIConstants.spacing12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          ),
          margin: EdgeInsets.all(UIConstants.paddingMedium),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // If ScaffoldMessenger fails, fail silently
      // This can happen if the context doesn't have a Scaffold ancestor
    }
  }

  /// Check if device is mobile
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < UIConstants.breakpointMobile;
  }

  /// Check if device is tablet
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= UIConstants.breakpointMobile &&
        width < UIConstants.breakpointDesktop;
  }

  /// Check if device is desktop
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= UIConstants.breakpointDesktop;
  }
}