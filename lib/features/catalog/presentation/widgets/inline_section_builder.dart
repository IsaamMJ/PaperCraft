// features/catalog/presentation/widgets/inline_section_builder.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/ai/services/paper_parse_service.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../domain/entities/paper_section_entity.dart';

/// Inline section builder that replaces dialog-based section building
/// with quick-add chips and editable inline cards.
class InlineSectionBuilder extends StatefulWidget {
  final List<PaperSectionEntity> initialSections;
  final ValueChanged<List<PaperSectionEntity>> onSectionsChanged;
  final bool readOnly;

  const InlineSectionBuilder({
    Key? key,
    required this.initialSections,
    required this.onSectionsChanged,
    this.readOnly = false,
  }) : super(key: key);

  @override
  State<InlineSectionBuilder> createState() => _InlineSectionBuilderState();
}

/// Internal mutable model for a section being edited inline.
class _SectionDraft {
  final String type;
  String name;
  final TextEditingController questionsController;
  final TextEditingController marksController;
  bool isEditingName;

  _SectionDraft({
    required this.type,
    required this.name,
    String questionsText = '',
    String marksText = '',
    this.isEditingName = false,
  })  : questionsController = TextEditingController(text: questionsText),
        marksController = TextEditingController(text: marksText);

  void dispose() {
    questionsController.dispose();
    marksController.dispose();
  }

  int get questions => int.tryParse(questionsController.text) ?? 0;
  double get marksPerQuestion => double.tryParse(marksController.text) ?? 0.0;
  double get totalMarks => questions * marksPerQuestion;

  PaperSectionEntity toEntity() => PaperSectionEntity(
        name: name,
        type: type,
        questions: questions,
        marksPerQuestion: marksPerQuestion,
        useSharedWordBank: false,
        sharedWordBank: const [],
      );
}

class _InlineSectionBuilderState extends State<InlineSectionBuilder> {
  final List<_SectionDraft> _drafts = [];
  bool _showWalkthrough = false;
  int _walkthroughStep = 0;
  bool _isParsing = false;

  // Chip definitions with icons, smart defaults, and colors.
  static const List<Map<String, dynamic>> _chipDefs = [
    {
      'label': 'MCQ',
      'type': 'multiple_choice',
      'default': 'Choose the correct answer',
      'icon': Icons.radio_button_checked,
      'defaultQuestions': '5',
      'defaultMarks': '1',
    },
    {
      'label': 'Fill Blanks',
      'type': 'fill_in_blanks',
      'default': 'Fill in the blanks',
      'icon': Icons.space_bar,
      'defaultQuestions': '5',
      'defaultMarks': '1',
    },
    {
      'label': 'Short Answer',
      'type': 'short_answer',
      'default': 'Answer the following',
      'icon': Icons.short_text,
      'defaultQuestions': '5',
      'defaultMarks': '2',
    },
    {
      'label': 'True / False',
      'type': 'true_false',
      'default': 'State true or false',
      'icon': Icons.check_circle_outline,
      'defaultQuestions': '5',
      'defaultMarks': '1',
    },
    {
      'label': 'Match',
      'type': 'match_following',
      'default': 'Match the following',
      'icon': Icons.compare_arrows,
      'defaultQuestions': '5',
      'defaultMarks': '1',
    },
    {
      'label': 'Missing Letters',
      'type': 'missing_letters',
      'default': 'Fill in the missing letters',
      'icon': Icons.text_fields,
      'defaultQuestions': '5',
      'defaultMarks': '1',
    },
    {
      'label': 'Word Forms',
      'type': 'word_forms',
      'default': 'Write word forms',
      'icon': Icons.abc,
      'defaultQuestions': '5',
      'defaultMarks': '1',
    },
  ];

  static const String _walkthroughPrefKey = 'section_builder_walkthrough_seen';

  @override
  void initState() {
    super.initState();
    _loadFromSections(widget.initialSections);
    _checkWalkthrough();
  }

  Future<void> _checkWalkthrough() async {
    if (widget.readOnly) return;
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_walkthroughPrefKey) ?? false;
    if (!seen && mounted) {
      setState(() => _showWalkthrough = true);
    }
  }

  Future<void> _dismissWalkthrough() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_walkthroughPrefKey, true);
    if (mounted) {
      setState(() {
        _showWalkthrough = false;
        _walkthroughStep = 0;
      });
    }
  }

  void _nextWalkthroughStep() {
    if (_walkthroughStep < 2) {
      setState(() => _walkthroughStep++);
    } else {
      _dismissWalkthrough();
    }
  }

  @override
  void didUpdateWidget(InlineSectionBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if parent pushed new initialSections (e.g., navigating to a different paper)
    if (_drafts.isEmpty && widget.initialSections.isNotEmpty) {
      _loadFromSections(widget.initialSections);
      setState(() {});
    }
    // Reset if parent cleared sections (new paper with no sections yet)
    if (widget.initialSections.isEmpty && oldWidget.initialSections.isNotEmpty) {
      for (final d in _drafts) {
        d.questionsController.removeListener(_onFieldChanged);
        d.marksController.removeListener(_onFieldChanged);
        d.dispose();
      }
      _drafts.clear();
      setState(() {});
    }
  }

  void _loadFromSections(List<PaperSectionEntity> sections) {
    for (final s in sections) {
      final draft = _SectionDraft(
        type: s.type,
        name: s.name,
        questionsText: s.questions > 0 ? s.questions.toString() : '',
        marksText: s.marksPerQuestion > 0 ? s.marksPerQuestion.toString() : '',
      );
      draft.questionsController.addListener(_onFieldChanged);
      draft.marksController.addListener(_onFieldChanged);
      _drafts.add(draft);
    }
  }

  @override
  void dispose() {
    for (final d in _drafts) {
      d.dispose();
    }
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static String _defaultNameForType(String type) {
    for (final chip in _chipDefs) {
      if (chip['type'] == type) return chip['default'] as String;
    }
    return type;
  }

  String _uniqueName(String type) {
    final base = _defaultNameForType(type);
    final existingNames = _drafts.map((d) => d.name.toLowerCase()).toList();
    if (!existingNames.contains(base.toLowerCase())) return base;
    // Use (A), (B), (C) ... (Z) suffixes for duplicates
    for (int i = 0; i < 26; i++) {
      final suffix = String.fromCharCode(65 + i); // A=65, B=66, ...
      final candidate = '$base ($suffix)';
      if (!existingNames.contains(candidate.toLowerCase())) return candidate;
    }
    return '$base (${DateTime.now().millisecondsSinceEpoch})'; // fallback
  }

  static String _shortLabel(String type) {
    switch (type) {
      case 'multiple_choice':
        return 'MCQ';
      case 'fill_in_blanks':
        return 'Fill Blanks';
      case 'short_answer':
        return 'Short Answer';
      case 'true_false':
        return 'True/False';
      case 'match_following':
        return 'Match';
      case 'missing_letters':
        return 'Missing Letters';
      case 'word_forms':
        return 'Word Forms';
      default:
        return type;
    }
  }

  static Color _typeColor(String type) {
    switch (type) {
      case 'multiple_choice':
        return Colors.blue;
      case 'fill_in_blanks':
        return Colors.orange;
      case 'short_answer':
        return Colors.green;
      case 'true_false':
        return Colors.purple;
      case 'match_following':
        return Colors.teal;
      case 'missing_letters':
        return Colors.indigo;
      case 'word_forms':
        return Colors.brown;
      default:
        return AppColors.primary;
    }
  }

  // ── Mutation helpers ─────────────────────────────────────────────────────

  void _addSection(String type) {
    // Find smart defaults for this type
    String defaultQuestions = '5';
    String defaultMarks = '1';
    for (final chip in _chipDefs) {
      if (chip['type'] == type) {
        defaultQuestions = chip['defaultQuestions'] as String;
        defaultMarks = chip['defaultMarks'] as String;
        break;
      }
    }

    final draft = _SectionDraft(
      type: type,
      name: _uniqueName(type),
      questionsText: defaultQuestions,
      marksText: defaultMarks,
    );
    draft.questionsController.addListener(_onFieldChanged);
    draft.marksController.addListener(_onFieldChanged);
    setState(() => _drafts.add(draft));
    _notify();
  }

  void _removeSection(int index) async {
    final name = _drafts[index].name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Section?'),
        content: Text('Remove "$name" from the paper?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final draft = _drafts[index];
      draft.questionsController.removeListener(_onFieldChanged);
      draft.marksController.removeListener(_onFieldChanged);
      draft.dispose();
      setState(() => _drafts.removeAt(index));
      _notify();
    }
  }

  void _onFieldChanged() {
    setState(() {});
    _notify();
  }

  void _notify() {
    widget.onSectionsChanged(_drafts.map((d) => d.toEntity()).toList());
  }

  void _startEditingName(int index) {
    setState(() {
      _drafts[index].isEditingName = true;
    });
  }

  /// Ensure a name is unique among all drafts (excluding the draft at [excludeIndex]).
  String _ensureUniqueName(String name, int excludeIndex) {
    final existingNames = _drafts
        .asMap()
        .entries
        .where((e) => e.key != excludeIndex)
        .map((e) => e.value.name.toLowerCase())
        .toList();
    if (!existingNames.contains(name.toLowerCase())) return name;
    for (int i = 0; i < 26; i++) {
      final suffix = String.fromCharCode(65 + i);
      final candidate = '$name ($suffix)';
      if (!existingNames.contains(candidate.toLowerCase())) return candidate;
    }
    return '$name (${DateTime.now().millisecondsSinceEpoch})';
  }

  void _finishEditingName(int index, String newName) {
    if (newName.trim().isNotEmpty) {
      final safeName = _ensureUniqueName(newName.trim(), index);
      setState(() {
        _drafts[index].name = safeName;
        _drafts[index].isEditingName = false;
      });
      _notify();
    } else {
      setState(() {
        _drafts[index].isEditingName = false;
      });
    }
  }

  // ── AI Paste Paper ─────────────────────────────────────────────────────

  void _showPastePaperDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste Paper Content'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste the full paper text (from WhatsApp, document, etc). AI will auto-detect sections, question types, and marks.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 12,
                minLines: 6,
                decoration: InputDecoration(
                  hintText: 'I) Choose the correct answer: (5 marks)\n1. Question...\n2. Question...\n\nII) Fill in the blanks: (5 marks)\n1. Question...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                _parsePaperText(text);
              }
            },
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Parse with AI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _parsePaperText(String text) async {
    setState(() => _isParsing = true);

    final result = await PaperParseService.parsePaperText(text);

    if (!mounted) return;

    setState(() => _isParsing = false);

    if (result.success && result.sections.isNotEmpty) {
      // Clear existing drafts
      for (final d in _drafts) {
        d.questionsController.removeListener(_onFieldChanged);
        d.marksController.removeListener(_onFieldChanged);
        d.dispose();
      }
      _drafts.clear();

      // Load parsed sections
      _loadFromSections(result.sections);
      setState(() {});
      _notify();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Detected ${result.sections.length} sections. Review and adjust if needed.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Could not parse paper. Try adding sections manually.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  // ── Computed totals ───────────────────────────────────────────────────────

  int get _totalSections => _drafts.length;

  double get _grandTotalMarks =>
      _drafts.fold(0.0, (sum, d) => sum + d.totalMarks);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: UIConstants.spacing12),
        if (!widget.readOnly) ...[
          _buildPastePaperButton(),
          const SizedBox(height: UIConstants.spacing12),
          _buildChips(),
          const SizedBox(height: UIConstants.spacing12),
        ],
        if (_isParsing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Analyzing paper structure...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        if (_drafts.isEmpty) _buildEmptyState() else _buildSectionList(),
        if (_drafts.length > 1 && !widget.readOnly)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.drag_indicator, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  'Hold and drag to reorder sections',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        if (_showWalkthrough) _buildWalkthroughOverlay(),
      ],
    );
  }

  Widget _buildHeader() {
    final totalMarks = _grandTotalMarks;
    final marksText = totalMarks == totalMarks.truncateToDouble()
        ? totalMarks.toInt().toString()
        : totalMarks.toStringAsFixed(1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Paper Structure',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: UIConstants.spacing12,
            vertical: UIConstants.spacing6,
          ),
          decoration: BoxDecoration(
            color: _totalSections > 0 ? AppColors.primary10 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          ),
          child: Text(
            '$_totalSections section${_totalSections == 1 ? '' : 's'} • $marksText mark${totalMarks == 1.0 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _totalSections > 0 ? AppColors.primary : Colors.grey,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildPastePaperButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isParsing ? null : _showPastePaperDialog,
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: const Text('Paste Paper - Auto Detect Sections'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.deepPurple,
          side: BorderSide(color: Colors.deepPurple.withValues(alpha: 0.4)),
          backgroundColor: Colors.deepPurple.withValues(alpha: 0.04),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          ),
        ),
      ),
    );
  }

  Widget _buildChips() {
    return Wrap(
      spacing: UIConstants.spacing8,
      runSpacing: UIConstants.spacing8,
      children: _chipDefs.map((chip) {
        final type = chip['type'] as String;
        final label = chip['label'] as String;
        final icon = chip['icon'] as IconData;
        final color = _typeColor(type);

        return ActionChip(
          avatar: Icon(icon, size: 16, color: color),
          label: Text(
            label,
            style: TextStyle(
              fontSize: UIConstants.fontSizeSmall,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          side: BorderSide(color: color.withValues(alpha: 0.4), width: 1.0),
          backgroundColor: color.withValues(alpha: 0.06),
          onPressed: () => _addSection(type),
          padding: const EdgeInsets.symmetric(
            horizontal: UIConstants.spacing4,
            vertical: 0,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: UIConstants.spacing24, horizontal: UIConstants.spacing16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: Colors.grey.shade200, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.touch_app, size: 40, color: Colors.grey.shade400),
          const SizedBox(height: UIConstants.spacing12),
          Text(
            'Tap a question type above to add a section',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textTertiary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: UIConstants.spacing4),
          Text(
            'Each section will have smart defaults pre-filled',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textTertiary,
                  fontStyle: FontStyle.italic,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _drafts.length,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
              child: child,
            );
          },
          child: child,
        );
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _drafts.removeAt(oldIndex);
          _drafts.insert(newIndex, item);
        });
        _notify();
      },
      itemBuilder: (_, index) => _buildSectionCard(index),
    );
  }

  Widget _buildSectionCard(int index) {
    final draft = _drafts[index];
    final color = _typeColor(draft.type);

    final total = draft.totalMarks;
    final totalText = total == total.truncateToDouble()
        ? total.toInt().toString()
        : total.toStringAsFixed(1);

    return Container(
      key: ValueKey('section_$index'),
      margin: const EdgeInsets.only(bottom: UIConstants.spacing8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header with color accent
          Container(
            color: color.withValues(alpha: 0.08),
            padding: const EdgeInsets.symmetric(
              horizontal: UIConstants.spacing12,
              vertical: UIConstants.spacing8,
            ),
            child: Row(
              children: [
                // Drag handle
                if (!widget.readOnly)
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.drag_indicator, size: 20, color: Colors.grey.shade400),
                    ),
                  ),

                // Section number badge
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: UIConstants.spacing8),

                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _shortLabel(draft.type),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: UIConstants.spacing8),

                // Section title (editable on tap)
                Expanded(
                  child: draft.isEditingName
                      ? _buildNameEditor(index, draft)
                      : GestureDetector(
                          onTap: widget.readOnly ? null : () => _startEditingName(index),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  draft.name,
                                  style: const TextStyle(
                                    fontSize: UIConstants.fontSizeMedium,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!widget.readOnly) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.edit, size: 14, color: Colors.grey.shade400),
                              ],
                            ],
                          ),
                        ),
                ),

                // Remove button
                if (!widget.readOnly)
                  GestureDetector(
                    onTap: () => _removeSection(index),
                    child: const Icon(
                      Icons.close,
                      size: UIConstants.iconMedium,
                      color: AppColors.error,
                    ),
                  ),
              ],
            ),
          ),

          // Card body — two input fields + total
          Padding(
            padding: const EdgeInsets.all(UIConstants.spacing12),
            child: Row(
              children: [
                // Questions field
                Expanded(
                  child: _buildNumberField(
                    controller: draft.questionsController,
                    label: 'Questions',
                    hint: 'e.g. 10',
                    allowDecimal: false,
                    readOnly: widget.readOnly,
                    validator: _validateCount,
                  ),
                ),
                const SizedBox(width: UIConstants.spacing12),

                // Marks each field
                Expanded(
                  child: _buildNumberField(
                    controller: draft.marksController,
                    label: 'Marks each',
                    hint: 'e.g. 2',
                    allowDecimal: true,
                    readOnly: widget.readOnly,
                    validator: _validateMarks,
                  ),
                ),
                const SizedBox(width: UIConstants.spacing12),

                // Total marks badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: total > 0 ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  ),
                  child: Text(
                    '= $totalText',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: total > 0 ? color : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameEditor(int index, _SectionDraft draft) {
    final controller = TextEditingController(text: draft.name);
    return SizedBox(
      height: 32,
      child: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(
          fontSize: UIConstants.fontSizeMedium,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.check, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => _finishEditingName(index, controller.text),
          ),
        ),
        onSubmitted: (value) => _finishEditingName(index, value),
      ),
    );
  }

  Widget _buildWalkthroughOverlay() {
    final steps = [
      {
        'title': 'Step 1: Choose Question Types',
        'description': 'Tap any question type chip above to add a section to your paper. Each section comes with smart defaults pre-filled.',
        'icon': Icons.touch_app,
      },
      {
        'title': 'Step 2: Customize Each Section',
        'description': 'Adjust the number of questions and marks for each section. Tap the section title to rename it.',
        'icon': Icons.tune,
      },
      {
        'title': 'Step 3: Review Total Marks',
        'description': 'Check the total marks at the top right. Drag sections to reorder them. Remove any section with the X button.',
        'icon': Icons.checklist,
      },
    ];

    final step = steps[_walkthroughStep];

    return Container(
      margin: const EdgeInsets.only(top: UIConstants.spacing8),
      padding: const EdgeInsets.all(UIConstants.spacing16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(step['icon'] as IconData, color: AppColors.primary, size: 24),
              const SizedBox(width: UIConstants.spacing8),
              Expanded(
                child: Text(
                  step['title'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              // Step indicator
              Text(
                '${_walkthroughStep + 1}/3',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: UIConstants.spacing8),
          Text(
            step['description'] as String,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: UIConstants.spacing12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _dismissWalkthrough,
                child: Text(
                  'Skip',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(width: UIConstants.spacing8),
              ElevatedButton(
                onPressed: _nextWalkthroughStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                child: Text(_walkthroughStep < 2 ? 'Next' : 'Got it!'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool allowDecimal,
    required bool readOnly,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: allowDecimal
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.number,
      inputFormatters: [
        if (allowDecimal)
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
        else
          FilteringTextInputFormatter.digitsOnly,
      ],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(
          fontSize: UIConstants.fontSizeSmall,
          color: AppColors.textSecondary,
        ),
        hintStyle: const TextStyle(
          fontSize: UIConstants.fontSizeSmall,
          color: AppColors.textTertiary,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: UIConstants.spacing12,
          vertical: UIConstants.spacing8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 10),
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
      ),
    );
  }

  // ── Validators ────────────────────────────────────────────────────────────

  String? _validateCount(String? value) {
    if (value == null || value.isEmpty) return null;
    final n = int.tryParse(value);
    if (n == null || n <= 0) return 'Must be > 0';
    if (n > 100) return 'Max 100';
    return null;
  }

  String? _validateMarks(String? value) {
    if (value == null || value.isEmpty) return null;
    final n = double.tryParse(value);
    if (n == null || n <= 0) return 'Must be > 0';
    if (n > 100) return 'Max 100';
    return null;
  }
}
