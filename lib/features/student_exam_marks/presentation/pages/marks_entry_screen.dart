import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../domain/entities/student_mark_entry_dto.dart';
import '../bloc/marks_entry_bloc.dart';
import '../bloc/marks_entry_event.dart';
import '../bloc/marks_entry_state.dart';

class MarksEntryScreen extends StatefulWidget {
  final String examTimetableEntryId;
  final String teacherId;
  final String? examName;
  final String? subjectName;
  final String? gradeName;
  final String? section;

  const MarksEntryScreen({
    super.key,
    required this.examTimetableEntryId,
    required this.teacherId,
    this.examName,
    this.subjectName,
    this.gradeName,
    this.section,
  });

  @override
  State<MarksEntryScreen> createState() => _MarksEntryScreenState();
}

class _MarksEntryScreenState extends State<MarksEntryScreen> {
  late List<StudentMarkEntryDto> _editableMarks;
  bool _hasChanges = false;
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, FocusNode> _focusNodes = {};
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _editableMarks = [];
    _scrollController = ScrollController();
    // Load marks when screen initializes
    context.read<MarksEntryBloc>().add(
          LoadMarksForTimetableEvent(
            examTimetableEntryId: widget.examTimetableEntryId,
          ),
        );
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    // Dispose all focus nodes
    for (var focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  TextEditingController _getController(int index, double initialValue) {
    if (!_controllers.containsKey(index)) {
      _controllers[index] = TextEditingController(
        text: initialValue > 0 ? initialValue.toString() : '',
      );
    }
    return _controllers[index]!;
  }

  FocusNode _getFocusNode(int index) {
    if (!_focusNodes.containsKey(index)) {
      _focusNodes[index] = FocusNode();
    }
    return _focusNodes[index]!;
  }

  void _moveToNextStudent(int currentIndex) {
    if (currentIndex < _editableMarks.length - 1) {
      final nextIndex = currentIndex + 1;
      _focusNodes[nextIndex]?.requestFocus();

      // Scroll to the next student if needed
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          (nextIndex * 90.0), // Approximate height of each row
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Enter Student Marks'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocListener<MarksEntryBloc, MarksEntryState>(
        listener: _handleBlocStateChanges,
        child: BlocBuilder<MarksEntryBloc, MarksEntryState>(
          builder: (context, state) {
            if (state is MarksEntryLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is MarksEntryError) {
              return _buildErrorView(state);
            }

            if (state is MarksEntryLoaded) {
              _editableMarks = state.editableMarks;
              return _buildMarksEntryView(state);
            }

            return const Center(child: Text('Unknown state'));
          },
        ),
      ),
    );
  }

  void _handleBlocStateChanges(BuildContext context, MarksEntryState state) {
    debugPrint('=== LISTENER: State changed to: ${state.runtimeType} ===');

    if (state is MarksEntryLoaded) {
      // Silently handle reload after submission/draft
      return;
    } else if (state is MarksSubmitting) {
      debugPrint('Handling MarksSubmitting state: ${state.message}');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              SizedBox(height: UIConstants.spacing16),
              Text(state.message),
            ],
          ),
        ),
      );
    } else if (state is MarksSubmitted) {
      debugPrint('Handling MarksSubmitted state: ${state.message}');
      // Close loading dialog if still open
      try {
        if (Navigator.canPop(context)) Navigator.pop(context);
      } catch (e) {
        debugPrint('Error closing dialog: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Colors.green,
        ),
      );
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && context.mounted) context.pop();
      });
    } else if (state is MarksSavedAsDraft) {
      debugPrint('Handling MarksSavedAsDraft state: ${state.message}');
      // Close loading dialog if still open
      try {
        if (Navigator.canPop(context)) Navigator.pop(context);
      } catch (e) {
        debugPrint('Error closing dialog: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Colors.blue,
        ),
      );
      setState(() => _hasChanges = false);
    } else if (state is MarksEntryError) {
      debugPrint('Handling MarksEntryError state: ${state.message}');
      // Close loading dialog if still open
      try {
        if (Navigator.canPop(context)) Navigator.pop(context);
      } catch (e) {
        debugPrint('Error closing dialog: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.message),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      debugPrint('Unhandled state: ${state.runtimeType}');
    }
  }

  Widget _buildErrorView(MarksEntryError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          SizedBox(height: UIConstants.spacing16),
          Text(
            state.message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          SizedBox(height: UIConstants.spacing24),
          ElevatedButton(
            onPressed: () {
              context.read<MarksEntryBloc>().add(
                    LoadMarksForTimetableEvent(
                      examTimetableEntryId: widget.examTimetableEntryId,
                    ),
                  );
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMarksEntryView(MarksEntryLoaded state) {
    return Column(
      children: [
        // Header with exam details
        _buildExamHeader(),

        // Show submitted status if marks are already submitted
        if (!state.isDraft)
          Container(
            padding: EdgeInsets.all(UIConstants.paddingSmall),
            margin: EdgeInsets.all(UIConstants.paddingSmall),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              border: Border.all(color: Colors.blue),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue, size: 20),
                SizedBox(width: UIConstants.spacing8),
                Expanded(
                  child: Text(
                    'Marks submitted on ${state.marks.isNotEmpty ? (state.marks.first.createdAt != null ? state.marks.first.createdAt.toString().split(' ')[0] : 'N/A') : 'N/A'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.blue[700],
                        ),
                  ),
                ),
              ],
            ),
          ),

        // Marks table
        Expanded(
          child: _buildMarksTable(state),
        ),

        // Action buttons
        _buildActionButtons(state),
      ],
    );
  }

  Widget _buildExamHeader() {
    return Container(
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.examName != null)
            Text(
              widget.examName!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
              ),
            ),
          SizedBox(height: UIConstants.spacing8),
          Row(
            children: [
              if (widget.gradeName != null) ...[
                Text(
                  'Grade: ${widget.gradeName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(width: UIConstants.spacing16),
              ],
              if (widget.subjectName != null) ...[
                Text(
                  'Subject: ${widget.subjectName}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SizedBox(width: UIConstants.spacing16),
              ],
              if (widget.section != null)
                Text(
                  'Section: ${widget.section}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
          SizedBox(height: UIConstants.spacing8),
          Text(
            'Total Students: ${_editableMarks.length}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarksTable(MarksEntryLoaded state) {
    if (_editableMarks.isEmpty) {
      return Center(
        child: Text(
          'No students to mark',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(UIConstants.paddingSmall),
      itemCount: _editableMarks.length,
      itemBuilder: (context, index) => _buildStudentMarkRow(index, state.isDraft),
    );
  }

  Widget _buildStudentMarkRow(int index, bool isDraft) {
    final mark = _editableMarks[index];
    final controller = _getController(index, mark.totalMarks);
    final focusNode = _getFocusNode(index);
    final isReadOnly = !isDraft; // Disable editing if marks are submitted

    return Container(
      margin: EdgeInsets.only(bottom: UIConstants.spacing8),
      padding: EdgeInsets.all(UIConstants.paddingSmall),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Student info
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mark.studentName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: UIConstants.spacing4),
                Text(
                  'Roll: ${mark.studentRollNumber}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: UIConstants.spacing8),

          // Marks input
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !isReadOnly && mark.status == 'present', // Disable if absent or submitted
              readOnly: isReadOnly,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: isReadOnly ? 'Submitted' : (mark.status == 'absent' ? 'N/A' : 'Marks'),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: UIConstants.paddingSmall,
                  vertical: UIConstants.paddingSmall,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                  borderSide: BorderSide(color: AppColors.border),
                ),
              ),
              onChanged: (value) {
                if (!isReadOnly && mark.status == 'present') {
                  final totalMarks = double.tryParse(value) ?? 0.0;
                  context.read<MarksEntryBloc>().add(
                        UpdateStudentMarkEvent(
                          studentIndex: index,
                          totalMarks: totalMarks,
                          status: mark.status,
                          remarks: mark.remarks,
                        ),
                      );
                  setState(() => _hasChanges = true);
                }
              },
              onSubmitted: (value) {
                if (!isReadOnly) {
                  _moveToNextStudent(index);
                }
              },
            ),
          ),

          SizedBox(width: UIConstants.spacing8),

          // Status dropdown
          DropdownButton<String>(
            value: mark.status,
            items: const [
              DropdownMenuItem(value: 'present', child: Text('Present')),
              DropdownMenuItem(value: 'absent', child: Text('Absent')),
            ],
            onChanged: isReadOnly
                ? null
                : (value) {
                    if (value != null) {
                      // Clear marks if changing to absent
                      final marksToSubmit = value == 'absent' ? 0.0 : mark.totalMarks;
                      if (value == 'absent') {
                        controller.clear();
                      }
                      context.read<MarksEntryBloc>().add(
                            UpdateStudentMarkEvent(
                              studentIndex: index,
                              totalMarks: marksToSubmit,
                              status: value,
                              remarks: mark.remarks,
                            ),
                          );
                      setState(() => _hasChanges = true);
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(MarksEntryLoaded state) {
    final isMarksSubmitted = !state.isDraft;

    return Container(
      padding: EdgeInsets.all(UIConstants.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: isMarksSubmitted
          ? Container(
              padding: EdgeInsets.all(UIConstants.paddingMedium),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: UIConstants.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Marks Already Submitted',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                        ),
                        Text(
                          'These marks have been submitted and cannot be edited.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.green[700],
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _hasChanges
                        ? () => _saveMarksAsDraft(state)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                    ),
                    child: const Text('Save as Draft'),
                  ),
                ),
                SizedBox(width: UIConstants.spacing12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _hasChanges
                        ? () => _submitMarks(state)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: const Text('Submit Marks'),
                  ),
                ),
              ],
            ),
    );
  }

  void _saveMarksAsDraft(MarksEntryLoaded state) {
    context.read<MarksEntryBloc>().add(
          SaveMarksAsDraftEvent(
            examTimetableEntryId: widget.examTimetableEntryId,
            marks: _editableMarks,
            teacherId: widget.teacherId,
          ),
        );
  }

  void _submitMarks(MarksEntryLoaded state) {
    debugPrint('=== SUBMIT MARKS CLICKED ===');
    debugPrint('Exam Timetable ID: ${widget.examTimetableEntryId}');
    debugPrint('Teacher ID: ${widget.teacherId}');
    debugPrint('Total Students: ${_editableMarks.length}');
    debugPrint('Exam Name: ${widget.examName}');
    debugPrint('Subject: ${widget.subjectName}');
    debugPrint('Grade: ${widget.gradeName}');
    debugPrint('Section: ${widget.section}');

    // Capture the screen context BEFORE the dialog is shown
    final screenContext = context;

    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit Marks?'),
        content: const Text(
          'Once submitted, marks cannot be edited. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('Submit cancelled by user');
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('Submit confirmed by user');
              debugPrint('Total marks to submit: ${_editableMarks.length}');
              for (int i = 0; i < _editableMarks.length; i++) {
                debugPrint('Student $i: ${_editableMarks[i].studentName} (Roll: ${_editableMarks[i].studentRollNumber}) - Marks: ${_editableMarks[i].totalMarks}, Status: ${_editableMarks[i].status}');
              }
              debugPrint('Adding SubmitMarksEvent to bloc...');
              Navigator.pop(dialogContext);

              // Use the SCREEN context, not the dialog context
              debugPrint('Getting bloc from screen context...');
              final bloc = screenContext.read<MarksEntryBloc>();
              debugPrint('Bloc obtained: $bloc');
              debugPrint('Bloc type: ${bloc.runtimeType}');

              // Create event
              final event = SubmitMarksEvent(
                examTimetableEntryId: widget.examTimetableEntryId,
                marks: _editableMarks,
                teacherId: widget.teacherId,
              );
              debugPrint('Event created: $event');

              // Add to bloc
              debugPrint('Adding event to bloc...');
              bloc.add(event);
              debugPrint('SubmitMarksEvent added to bloc');
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
