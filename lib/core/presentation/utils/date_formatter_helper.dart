// core/presentation/utils/date_formatter_helper.dart

/// Consistent date formatting helper for the entire app
/// Uses relative dates for recent items, absolute dates for older ones
class DateFormatterHelper {
  /// Format date consistently across the app
  /// - Today: "Today"
  /// - Yesterday: "Yesterday"
  /// - Last 7 days: "2 days ago"
  /// - Last month: "2 weeks ago"
  /// - Older: "14/10/2025"
  static String formatRelative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final compareDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(compareDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else if (difference < 30) {
      final weeks = (difference / 7).floor();
      return '$weeks week${weeks > 1 ? 's' : ''} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  /// Format time with date (for notifications, detailed views)
  /// Examples: "Today at 2:30 PM", "Yesterday at 10:15 AM", "2 days ago"
  static String formatRelativeWithTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final compareDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final difference = today.difference(compareDate).inDays;

    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : (dateTime.hour == 0 ? 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';

    if (difference == 0) {
      return 'Today at $timeStr';
    } else if (difference == 1) {
      return 'Yesterday at $timeStr';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return formatRelative(dateTime);
    }
  }
}
