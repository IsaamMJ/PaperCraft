// core/pages/utils/enhanced_date_formatter.dart
import 'package:intl/intl.dart';

/// Enhanced date formatter that properly handles past/future dates and timezones
class EnhancedDateFormatter {
  static const Map<String, String> _dayNames = {
    'Monday': 'Mon',
    'Tuesday': 'Tue',
    'Wednesday': 'Wed',
    'Thursday': 'Thu',
    'Friday': 'Fri',
    'Saturday': 'Sat',
    'Sunday': 'Sun',
  };

  /// Format date with proper past/future handling
  static String formatDate(DateTime date, {
    bool showTime = true,
    bool showRelative = true,
    bool useShortFormat = false,
  }) {
    try {
      final now = DateTime.now();
      final localDate = date.toLocal();
      final localNow = now.toLocal();

      // Calculate difference properly for both past and future
      final difference = localDate.difference(localNow);
      final absDays = difference.inDays.abs();
      final isInFuture = difference.inMilliseconds > 0;

      final timeStr = showTime
          ? ' at ${DateFormat('HH:mm').format(localDate)}'
          : '';

      // Handle relative dates if requested
      if (showRelative) {
        // Same day
        if (absDays == 0) {
          return 'Today$timeStr';
        }

        // Yesterday/Tomorrow
        if (absDays == 1) {
          return isInFuture ? 'Tomorrow$timeStr' : 'Yesterday$timeStr';
        }

        // This week (within 7 days)
        if (absDays < 7) {
          final dayName = useShortFormat
              ? _getShortDayName(localDate)
              : DateFormat('EEEE').format(localDate);

          if (isInFuture) {
            return 'This $dayName$timeStr';
          } else {
            return 'Last $dayName$timeStr';
          }
        }

        // Within this month
        if (absDays < 30 && localDate.month == localNow.month) {
          if (isInFuture) {
            return 'In ${absDays} days$timeStr';
          } else {
            return '${absDays} days ago';
          }
        }
      }

      // Fallback to absolute date format
      return _formatAbsoluteDate(localDate, showTime: showTime, useShortFormat: useShortFormat);

    } catch (e) {
      // Fallback for any parsing errors
      return _formatAbsoluteDate(date, showTime: showTime, useShortFormat: useShortFormat);
    }
  }

  /// Format absolute date (non-relative)
  static String _formatAbsoluteDate(DateTime date, {
    bool showTime = true,
    bool useShortFormat = false
  }) {
    try {
      final localDate = date.toLocal();

      if (useShortFormat) {
        final format = showTime
            ? DateFormat('dd/MM/yy HH:mm')
            : DateFormat('dd/MM/yy');
        return format.format(localDate);
      } else {
        final format = showTime
            ? DateFormat('dd/MM/yyyy HH:mm')
            : DateFormat('dd/MM/yyyy');
        return format.format(localDate);
      }
    } catch (e) {
      return date.toString().split('.')[0]; // Remove microseconds
    }
  }

  /// Get short day name
  static String _getShortDayName(DateTime date) {
    final fullName = DateFormat('EEEE').format(date);
    return _dayNames[fullName] ?? fullName.substring(0, 3);
  }

  /// Format exam date specifically (handles future dates properly)
  static String formatExamDate(DateTime examDate) {
    final now = DateTime.now();
    final difference = examDate.difference(now);
    final dateStr = DateFormat('dd/MM/yyyy').format(examDate);

    if (difference.inDays > 0) {
      // Future exam
      if (difference.inDays == 1) {
        return 'Tomorrow (${dateStr}) at ${DateFormat('HH:mm').format(examDate)}';
      } else if (difference.inDays < 7) {
        return 'In ${difference.inDays} days (${dateStr}) - ${DateFormat('EEEE').format(examDate)}';
      } else if (difference.inDays < 30) {
        return 'In ${difference.inDays} days (${dateStr})';
      } else {
        return dateStr;
      }
    } else if (difference.inDays == 0) {
      // Today
      return 'Today (${dateStr}) at ${DateFormat('HH:mm').format(examDate)}';
    } else {
      // Past exam
      final daysPast = difference.inDays.abs();
      if (daysPast == 1) {
        return 'Yesterday (${dateStr})';
      } else if (daysPast < 7) {
        return '${daysPast} days ago (${dateStr})';
      } else {
        return dateStr;
      }
    }
  }

  /// Format time duration between two dates
  static String formatDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);

    if (duration.inDays > 0) {
      return '${duration.inDays} days';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hours';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minutes';
    } else {
      return 'Just now';
    }
  }

  /// Format relative time (e.g., "2 hours ago", "in 3 days")
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    final isInFuture = difference.inMilliseconds > 0;
    final absDifference = Duration(milliseconds: difference.inMilliseconds.abs());

    if (absDifference.inDays > 0) {
      final days = absDifference.inDays;
      return isInFuture ? 'in $days day${days == 1 ? '' : 's'}' : '$days day${days == 1 ? '' : 's'} ago';
    } else if (absDifference.inHours > 0) {
      final hours = absDifference.inHours;
      return isInFuture ? 'in $hours hour${hours == 1 ? '' : 's'}' : '$hours hour${hours == 1 ? '' : 's'} ago';
    } else if (absDifference.inMinutes > 0) {
      final minutes = absDifference.inMinutes;
      return isInFuture ? 'in $minutes minute${minutes == 1 ? '' : 's'}' : '$minutes minute${minutes == 1 ? '' : 's'} ago';
    } else {
      return 'just now';
    }
  }

  /// Check if a date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Check if a date is in the future
  static bool isFuture(DateTime date) {
    return date.isAfter(DateTime.now());
  }

  /// Check if a date is in the past
  static bool isPast(DateTime date) {
    return date.isBefore(DateTime.now());
  }

  /// Get timezone offset string
  static String getTimezoneOffset() {
    final now = DateTime.now();
    final offset = now.timeZoneOffset;
    final hours = offset.inHours;
    final minutes = (offset.inMinutes % 60).abs();

    final sign = hours >= 0 ? '+' : '-';
    return '$sign${hours.abs().toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Format date with timezone info
  static String formatWithTimezone(DateTime date) {
    final formatted = formatDate(date);
    final timezone = getTimezoneOffset();
    return '$formatted (UTC$timezone)';
  }

  /// Safe date parsing with fallback
  static DateTime? safeParse(dynamic dateValue) {
    try {
      if (dateValue == null) return null;

      if (dateValue is DateTime) {
        return dateValue;
      } else if (dateValue is String) {
        return DateTime.parse(dateValue);
      } else if (dateValue is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Format for different contexts
  static String formatForContext(DateTime date, DateContext context) {
    switch (context) {
      case DateContext.examDate:
        return formatExamDate(date);
      case DateContext.created:
        return formatDate(date, showRelative: true);
      case DateContext.modified:
        return formatRelativeTime(date);
      case DateContext.submitted:
        return formatDate(date, showRelative: true);
      case DateContext.reviewed:
        return formatDate(date, showRelative: true);
      case DateContext.compact:
        return formatDate(date, useShortFormat: true, showTime: false);
      case DateContext.detailed:
        return formatWithTimezone(date);
    }
  }
}

/// Context enum for different date formatting needs
enum DateContext {
  examDate,
  created,
  modified,
  submitted,
  reviewed,
  compact,
  detailed,
}