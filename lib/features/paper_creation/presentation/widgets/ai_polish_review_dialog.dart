import 'package:flutter/material.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../../catalog/domain/entities/paper_section_entity.dart';
import '../../../paper_workflow/domain/entities/question_entity.dart';

/// Dialog showing AI polishing changes with undo options
class AIPolishReviewDialog extends StatefulWidget {
  final Map<String, List<Question>> originalQuestions;
  final Map<String, List<Question>> polishedQuestions;
  final List<PaperSectionEntity> paperSections;

  const AIPolishReviewDialog({
    super.key,
    required this.originalQuestions,
    required this.polishedQuestions,
    required this.paperSections,
  });

  @override
  State<AIPolishReviewDialog> createState() => _AIPolishReviewDialogState();
}

class _AIPolishReviewDialogState extends State<AIPolishReviewDialog> {
  // Track which questions have been reverted to original
  final Set<String> _revertedQuestions = {};

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusXLarge),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(UIConstants.radiusXLarge),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_fix_high, color: AppColors.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'AI Polished Your Questions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: AppColors.success, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '${stats['changedCount']} question${stats['changedCount'] != 1 ? 's' : ''} improved',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Questions list with diff
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _buildQuestionItems().length,
                itemBuilder: (context, index) => _buildQuestionItems()[index],
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _undoAll,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Undo All'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _acceptChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Accept All Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildQuestionItems() {
    final items = <Widget>[];
    int globalIndex = 0;

    for (var section in widget.paperSections) {
      final sectionName = section.name;
      final originalList = widget.originalQuestions[sectionName] ?? [];
      final polishedList = widget.polishedQuestions[sectionName] ?? [];

      // Section header
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            sectionName,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      );

      // Questions in this section
      for (int i = 0; i < polishedList.length; i++) {
        final original = i < originalList.length ? originalList[i] : null;
        final polished = polishedList[i];
        final questionKey = '$sectionName-$i';
        final isReverted = _revertedQuestions.contains(questionKey);
        final hasChanges = original != null && original.text != polished.text;

        items.add(
          _buildQuestionCard(
            questionNumber: globalIndex + 1,
            original: original,
            polished: polished,
            questionKey: questionKey,
            isReverted: isReverted,
            hasChanges: hasChanges,
          ),
        );
        globalIndex++;
      }
    }

    return items;
  }

  Widget _buildQuestionCard({
    required int questionNumber,
    required Question? original,
    required Question polished,
    required String questionKey,
    required bool isReverted,
    required bool hasChanges,
  }) {
    if (!hasChanges) {
      // No changes - show simple card
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Text(
              'Q$questionNumber.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                polished.text,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            Icon(Icons.check_circle, color: Colors.grey.shade400, size: 20),
          ],
        ),
      );
    }

    // Has changes - show diff card
    final displayText = isReverted ? original!.text : polished.text;
    final changes = polished.polishChanges ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReverted
            ? Colors.orange.shade50
            : AppColors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(
          color: isReverted ? Colors.orange.shade200 : AppColors.success.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number and undo button
          Row(
            children: [
              Text(
                'Q$questionNumber.',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (isReverted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'REVERTED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => _toggleRevert(questionKey),
                icon: Icon(
                  isReverted ? Icons.redo : Icons.undo,
                  size: 16,
                ),
                label: Text(isReverted ? 'Reapply' : 'Undo'),
                style: TextButton.styleFrom(
                  foregroundColor: isReverted ? AppColors.primary : Colors.orange.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Original text (if not reverted)
          if (!isReverted && original != null) ...[
            Text(
              'Original:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              original.text,
              style: TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Current text
          Text(
            isReverted ? 'Original:' : 'Polished:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isReverted ? Colors.orange.shade700 : AppColors.success,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            displayText,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),

          // Changes summary
          if (!isReverted && changes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Changes:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...changes.map((change) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '• $change',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Map<String, int> _calculateStats() {
    int totalQuestions = 0;
    int changedCount = 0;

    for (var section in widget.paperSections) {
      final originalList = widget.originalQuestions[section.name] ?? [];
      final polishedList = widget.polishedQuestions[section.name] ?? [];

      totalQuestions += polishedList.length;

      for (int i = 0; i < polishedList.length; i++) {
        final original = i < originalList.length ? originalList[i] : null;
        final polished = polishedList[i];
        if (original != null && original.text != polished.text) {
          changedCount++;
        }
      }
    }

    return {
      'total': totalQuestions,
      'changedCount': changedCount,
    };
  }

  void _toggleRevert(String questionKey) {
    setState(() {
      if (_revertedQuestions.contains(questionKey)) {
        _revertedQuestions.remove(questionKey);
      } else {
        _revertedQuestions.add(questionKey);
      }
    });
  }

  void _undoAll() {
    // Revert all changed questions
    setState(() {
      for (var section in widget.paperSections) {
        final originalList = widget.originalQuestions[section.name] ?? [];
        final polishedList = widget.polishedQuestions[section.name] ?? [];

        for (int i = 0; i < polishedList.length; i++) {
          final original = i < originalList.length ? originalList[i] : null;
          final polished = polishedList[i];
          if (original != null && original.text != polished.text) {
            _revertedQuestions.add('${section.name}-$i');
          }
        }
      }
    });
  }

  void _acceptChanges() {
    // Build final question map with reverted questions using original text
    final finalQuestions = <String, List<Question>>{};

    for (var section in widget.paperSections) {
      final sectionName = section.name;
      final originalList = widget.originalQuestions[sectionName] ?? [];
      final polishedList = widget.polishedQuestions[sectionName] ?? [];
      final finalList = <Question>[];

      for (int i = 0; i < polishedList.length; i++) {
        final questionKey = '$sectionName-$i';
        if (_revertedQuestions.contains(questionKey) && i < originalList.length) {
          // Use original
          finalList.add(originalList[i]);
        } else {
          // Use polished
          finalList.add(polishedList[i]);
        }
      }

      finalQuestions[sectionName] = finalList;
    }

    Navigator.pop(context, finalQuestions);
  }
}
