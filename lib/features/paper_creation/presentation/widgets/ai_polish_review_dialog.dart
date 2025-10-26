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

  // Track manually edited questions
  final Map<String, Question> _editedQuestions = {};

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
                color: AppColors.primary10,
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
                      color: AppColors.success10,
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
                    color: AppColors.black08,
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
            sectionName: sectionName,
            questionIndex: i,
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
    required String sectionName,
    required int questionIndex,
  }) {
    if (!hasChanges) {
      // No changes - show simple card with edit option
      final isEdited = _editedQuestions.containsKey(questionKey);
      final displayQuestion = isEdited ? _editedQuestions[questionKey]! : polished;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isEdited ? AppColors.primary05 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          border: Border.all(
            color: isEdited ? AppColors.primary30 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Q$questionNumber.',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isEdited ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayQuestion.text,
                    style: TextStyle(
                      color: isEdited ? AppColors.textPrimary : AppColors.textSecondary,
                      fontWeight: isEdited ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
                if (isEdited)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'EDITED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  Icon(Icons.check_circle, color: Colors.grey.shade400, size: 20),
              ],
            ),
            if (isEdited) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => _editQuestion(questionKey, sectionName, questionIndex, displayQuestion),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ] else
              SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _editQuestion(questionKey, sectionName, questionIndex, displayQuestion),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    // Has changes - show diff card
    final isEdited = _editedQuestions.containsKey(questionKey);
    final displayQuestion = isEdited
        ? _editedQuestions[questionKey]!
        : (isReverted ? original! : polished);
    final displayText = displayQuestion.text;
    final changes = polished.polishChanges ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReverted
            ? Colors.orange.shade50
            : AppColors.success05,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(
          color: isReverted ? AppColors.warning : AppColors.success10,
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
              if (isEdited)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'EDITED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                )
              else if (isReverted)
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
                onPressed: () => _editQuestion(questionKey, sectionName, questionIndex, displayQuestion),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(width: 4),
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
            isEdited ? 'Edited:' : (isReverted ? 'Original:' : 'Polished:'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isEdited ? AppColors.primary : (isReverted ? Colors.orange.shade700 : AppColors.success),
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

          // Show subquestions if present
          if (displayQuestion.subQuestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary05,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sub-questions:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...displayQuestion.subQuestions.asMap().entries.map((entry) {
                    final label = String.fromCharCode(97 + entry.key);
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '$label) ${entry.value.text}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

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

  Future<void> _editQuestion(String questionKey, String sectionName, int questionIndex, Question currentQuestion) async {
    final edited = await showDialog<String>(
      context: context,
      builder: (context) => _EditQuestionDialog(initialText: currentQuestion.text),
    );

    if (edited != null && edited.isNotEmpty && edited != currentQuestion.text && mounted) {
      setState(() {
        _editedQuestions[questionKey] = currentQuestion.copyWith(text: edited);
        // Remove from reverted when edited
        _revertedQuestions.remove(questionKey);
      });
    }
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
        if (_editedQuestions.containsKey(questionKey)) {
          // Use manually edited version
          finalList.add(_editedQuestions[questionKey]!);
        } else if (_revertedQuestions.contains(questionKey) && i < originalList.length) {
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

/// Separate stateful dialog for editing questions to properly manage controller lifecycle
class _EditQuestionDialog extends StatefulWidget {
  final String initialText;

  const _EditQuestionDialog({required this.initialText});

  @override
  State<_EditQuestionDialog> createState() => _EditQuestionDialogState();
}

class _EditQuestionDialogState extends State<_EditQuestionDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Question'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Question Text',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
