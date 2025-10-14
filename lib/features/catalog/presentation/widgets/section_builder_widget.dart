// features/catalog/presentation/widgets/section_builder_widget.dart
import 'package:flutter/material.dart';
import '../../domain/entities/paper_section_entity.dart';
import 'section_card.dart';
import 'add_edit_section_dialog.dart';

/// Widget for building/editing paper sections dynamically
class SectionBuilderWidget extends StatefulWidget {
  final List<PaperSectionEntity> initialSections;
  final ValueChanged<List<PaperSectionEntity>> onSectionsChanged;
  final bool readOnly;

  const SectionBuilderWidget({
    Key? key,
    required this.initialSections,
    required this.onSectionsChanged,
    this.readOnly = false,
  }) : super(key: key);

  @override
  State<SectionBuilderWidget> createState() => _SectionBuilderWidgetState();
}

class _SectionBuilderWidgetState extends State<SectionBuilderWidget> {
  late List<PaperSectionEntity> sections;

  @override
  void initState() {
    super.initState();
    sections = List.from(widget.initialSections);
  }

  @override
  void didUpdateWidget(SectionBuilderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update sections if initialSections changed from parent
    // Use list length and identity comparison to detect changes
    if (widget.initialSections.length != oldWidget.initialSections.length ||
        !identical(widget.initialSections, oldWidget.initialSections)) {
      setState(() {
        sections = List.from(widget.initialSections);
      });
    }
  }

  void _addSection() async {
    final newSection = await showDialog<PaperSectionEntity>(
      context: context,
      builder: (context) => const AddEditSectionDialog(),
    );

    if (newSection != null) {
      setState(() {
        sections.add(newSection);
      });
      widget.onSectionsChanged(sections);
    }
  }

  void _editSection(int index) async {
    final editedSection = await showDialog<PaperSectionEntity>(
      context: context,
      builder: (context) => AddEditSectionDialog(
        section: sections[index],
      ),
    );

    if (editedSection != null) {
      setState(() {
        sections[index] = editedSection;
      });
      widget.onSectionsChanged(sections);
    }
  }

  void _deleteSection(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section?'),
        content: Text(
          'Are you sure you want to delete "${sections[index].name}"?\n\n'
          'This will remove the section and you\'ll need to recreate it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        sections.removeAt(index);
      });
      widget.onSectionsChanged(sections);
    }
  }

  void _moveUp(int index) {
    if (index > 0) {
      setState(() {
        final temp = sections[index];
        sections[index] = sections[index - 1];
        sections[index - 1] = temp;
      });
      widget.onSectionsChanged(sections);

      // Visual feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved "${sections[index - 1].name}" up'),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _moveDown(int index) {
    if (index < sections.length - 1) {
      setState(() {
        final temp = sections[index];
        sections[index] = sections[index + 1];
        sections[index + 1] = temp;
      });
      widget.onSectionsChanged(sections);

      // Visual feedback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved "${sections[index + 1].name}" down'),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  int get totalQuestions => sections.fold(0, (sum, s) => sum + s.questions);
  int get totalMarks => sections.fold(0, (sum, s) => sum + s.totalMarks);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with totals
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Paper Structure',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$totalQuestions questions • $totalMarks marks',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Sections list
        if (sections.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.note_add_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No sections added yet',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add sections to define your paper structure',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                  ),
                ],
              ),
            ),
          )
        else
          AnimatedList(
            key: Key('sections_${sections.length}'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            initialItemCount: sections.length,
            itemBuilder: (context, index, animation) {
              if (index >= sections.length) return const SizedBox.shrink();
              return SlideTransition(
                position: animation.drive(
                  Tween(
                    begin: const Offset(0.3, 0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOut)),
                ),
                child: FadeTransition(
                  opacity: animation,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SectionCard(
                      section: sections[index],
                      sectionNumber: index + 1,
                      onEdit: widget.readOnly ? null : () => _editSection(index),
                      onDelete: widget.readOnly ? null : () => _deleteSection(index),
                      onMoveUp: widget.readOnly || index == 0 ? null : () => _moveUp(index),
                      onMoveDown: widget.readOnly || index == sections.length - 1
                          ? null
                          : () => _moveDown(index),
                    ),
                  ),
                ),
              );
            },
          ),

        // Add section button
        if (!widget.readOnly)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: OutlinedButton.icon(
              onPressed: _addSection,
              icon: const Icon(Icons.add),
              label: const Text('Add Section'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
      ],
    );
  }
}
