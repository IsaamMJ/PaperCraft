// features/catalog/presentation/widgets/pattern_selector_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/teacher_pattern_entity.dart';
import '../../domain/entities/paper_section_entity.dart';
import '../bloc/teacher_pattern_bloc.dart';
import '../bloc/teacher_pattern_event.dart';
import '../bloc/teacher_pattern_state.dart';

/// Widget for selecting a saved pattern
class PatternSelectorWidget extends StatefulWidget {
  final String teacherId;
  final String subjectId;
  final ValueChanged<List<PaperSectionEntity>> onPatternSelected;
  final VoidCallback? onCreateNewPattern; // Callback when "Create new pattern" is selected

  const PatternSelectorWidget({
    Key? key,
    required this.teacherId,
    required this.subjectId,
    required this.onPatternSelected,
    this.onCreateNewPattern,
  }) : super(key: key);

  @override
  State<PatternSelectorWidget> createState() => _PatternSelectorWidgetState();
}

class _PatternSelectorWidgetState extends State<PatternSelectorWidget> {
  bool _hasLoadedPatterns = false;

  @override
  void initState() {
    super.initState();
    // Load patterns once when widget is created
    _loadPatterns();
  }

  @override
  void didUpdateWidget(PatternSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload patterns if subject changed
    if (oldWidget.subjectId != widget.subjectId) {
      _hasLoadedPatterns = false;
      _loadPatterns();
    }
  }

  void _loadPatterns() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasLoadedPatterns) {
        context.read<TeacherPatternBloc>().add(
          LoadTeacherPatterns(
            teacherId: widget.teacherId,
            subjectId: widget.subjectId,
          ),
        );
        _hasLoadedPatterns = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeacherPatternBloc, TeacherPatternState>(
      builder: (context, state) {
        if (state is TeacherPatternLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (state is TeacherPatternError) {
          return Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.message,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is TeacherPatternLoaded) {
          if (state.patterns.isEmpty) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No saved patterns yet. Create your first paper to save a pattern!',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Use Previous Pattern',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Select a previously used pattern or create a new one',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TeacherPatternEntity>(
                    decoration: const InputDecoration(
                      labelText: 'Select Pattern',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pattern),
                    ),
                    isExpanded: true,
                    value: state.selectedPattern,
                    items: [
                      const DropdownMenuItem<TeacherPatternEntity>(
                        value: null,
                        child: Text('Create new pattern...'),
                      ),
                      ...state.patterns.map((pattern) {
                        // Simplified dropdown item - just show name
                        return DropdownMenuItem<TeacherPatternEntity>(
                          value: pattern,
                          child: Text(
                            pattern.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (pattern) {
                      if (pattern != null) {
                        widget.onPatternSelected(pattern.sections);
                        context.read<TeacherPatternBloc>().add(
                              SelectPattern(pattern),
                            );
                        // Show feedback to user
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text('Pattern loaded: ${pattern.name}'),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green.shade700,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      } else {
                        widget.onPatternSelected([]);
                        context.read<TeacherPatternBloc>().add(
                              const SelectPattern(null),
                            );
                        // Notify parent that "Create new pattern" was selected
                        widget.onCreateNewPattern?.call();
                        // Show feedback for clearing pattern
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Creating new pattern'),
                            backgroundColor: Colors.blue.shade700,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  // Active pattern indicator
                  if (state.selectedPattern != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Using: ${state.selectedPattern!.name}',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (state.selectedPattern!.isFrequentlyUsed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Frequent',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        // Initial state - show loading or empty state
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}
