// features/catalog/presentation/widgets/section_card.dart
import 'package:flutter/material.dart';
import '../../domain/entities/paper_section_entity.dart';

/// Card widget to display a single paper section
class SectionCard extends StatelessWidget {
  final PaperSectionEntity section;
  final int sectionNumber;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const SectionCard({
    Key? key,
    required this.section,
    required this.sectionNumber,
    this.onEdit,
    this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  }) : super(key: key);

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'multiple_choice':
        return Icons.radio_button_checked;
      case 'short_answer':
        return Icons.short_text;
      case 'fill_in_blanks':
      case 'fill_blanks': // Support legacy type
        return Icons.edit_note;
      case 'true_false':
        return Icons.toggle_on;
      case 'match_following':
        return Icons.compare_arrows;
      case 'word_forms':
        return Icons.transform;
      case 'missing_letters':
        return Icons.abc;
      default:
        return Icons.question_answer;
    }
  }

  String _formatType(String type) {
    switch (type) {
      case 'multiple_choice':
        return 'MCQ';
      case 'short_answer':
        return 'Short Answer';
      case 'fill_in_blanks':
      case 'fill_blanks': // Support legacy type
        return 'Fill Blanks';
      case 'true_false':
        return 'True/False';
      case 'match_following':
        return 'Match Following';
      case 'word_forms':
        return 'Word Forms';
      case 'missing_letters':
        return 'Missing Letters';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActions = onEdit != null || onDelete != null || onMoveUp != null || onMoveDown != null;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Section number badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$sectionNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Section name
                Expanded(
                  child: Text(
                    section.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),

                // Action buttons
                if (hasActions)
                  Row(
                    children: [
                      if (onMoveUp != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 20),
                          onPressed: onMoveUp,
                          tooltip: 'Move up',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (onMoveDown != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 20),
                          onPressed: onMoveDown,
                          tooltip: 'Move down',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (onEdit != null)
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: onEdit,
                          tooltip: 'Edit',
                        ),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: onDelete,
                          tooltip: 'Delete',
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Section details
            Row(
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getTypeIcon(section.type),
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatType(section.type),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Questions/Pairs count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.format_list_numbered,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        section.type == 'match_following'
                            ? '${section.questions} pair${section.questions > 1 ? 's' : ''}'
                            : '${section.questions} question${section.questions > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Marks
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.grade,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        section.fullSummary,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
