import 'package:flutter/material.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../catalog/domain/entities/teacher_class.dart';

/// Classes Card Section widget - displays teacher's assigned classes
///
/// Shows all grades and sections the teacher teaches in attractive cards
/// with gradient colors that vary by grade number
class ClassesCardSection extends StatelessWidget {
  final List<TeacherClass> classes;
  final VoidCallback? onClassTap;

  const ClassesCardSection({
    Key? key,
    required this.classes,
    this.onClassTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Your Classes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: classes.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final teacherClass = classes[index];
              return _buildClassCard(context, teacherClass);
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildClassCard(BuildContext context, TeacherClass teacherClass) {
    // Generate gradient colors based on grade number
    final colors = _getGradeColors(teacherClass.gradeNumber);

    return GestureDetector(
      onTap: onClassTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: colors[0].withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onClassTap,
            borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Grade and Section Header
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grade ${teacherClass.gradeNumber}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Section ${teacherClass.sectionName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  // Subject Names (Truncated if needed)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: teacherClass.subjectNames
                            .take(3) // Show max 3 subjects
                            .map((subject) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            _abbreviateSubject(subject),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                            .toList(),
                      ),
                    ),
                  ),

                  // Show "more" indicator if more than 3 subjects
                  if (teacherClass.subjectNames.length > 3)
                    Text(
                      '+${teacherClass.subjectNames.length - 3} more',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Abbreviate subject names to fit in cards
  /// e.g., "Mathematics" -> "Math", "English Language" -> "Eng. Lang."
  String _abbreviateSubject(String subject) {
    final abbreviations = {
      'mathematics': 'Math',
      'english': 'English',
      'science': 'Science',
      'social studies': 'Social Studies',
      'history': 'History',
      'geography': 'Geography',
      'computer science': 'CS',
      'physical education': 'PE',
      'hindi': 'Hindi',
      'bengali': 'Bengali',
      'sanskrit': 'Sanskrit',
    };

    final lower = subject.toLowerCase();
    return abbreviations[lower] ?? subject;
  }

  /// Get gradient colors based on grade number
  /// Creates visually distinct colors for different grades
  List<Color> _getGradeColors(int gradeNumber) {
    // Use modulo to cycle through color schemes
    final colorIndex = (gradeNumber - 1) % 6;

    switch (colorIndex) {
      case 0:
        return [const Color(0xFF6366F1), const Color(0xFF4F46E5)]; // Indigo
      case 1:
        return [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]; // Blue
      case 2:
        return [const Color(0xFF10B981), const Color(0xFF059669)]; // Emerald
      case 3:
        return [const Color(0xFFF59E0B), const Color(0xFFD97706)]; // Amber
      case 4:
        return [const Color(0xFFEF4444), const Color(0xFFDC2626)]; // Red
      case 5:
        return [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)]; // Violet
      default:
        return [const Color(0xFF6366F1), const Color(0xFF4F46E5)];
    }
  }
}
