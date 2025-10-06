// core/presentation/utils/date_utils.dart

/// Centralized date formatting utilities for the application
class AppDateUtils {
  // Private constructor to prevent instantiation
  AppDateUtils._();

  /// Format date as DD/MM/YYYY
  /// Example: 15/3/2024
  static String formatShortDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Format date with leading zeros: DD/MM/YYYY
  /// Example: 15/03/2024
  static String formatShortDatePadded(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  /// Format date as "Jan 15, 2024"
  static String formatMediumDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Format date as "January 15, 2024"
  static String formatLongDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Format time as HH:MM AM/PM
  /// Example: 2:30 PM
  static String formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  /// Format date and time: "Jan 15, 2024 at 2:30 PM"
  static String formatDateTime(DateTime date) {
    return '${formatMediumDate(date)} at ${formatTime(date)}';
  }
}