import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/exam_calendar_bloc.dart';
import '../bloc/exam_calendar_event.dart';
import '../bloc/exam_calendar_state.dart';
import '../../domain/entities/exam_calendar.dart';

/// Page to view and manage exam calendars
///
/// Allows admins to:
/// - View yearly exam calendar (June Monthly, September Quarterly, etc.)
/// - Create new calendar entries
/// - Delete calendar entries
class ExamCalendarListPage extends StatefulWidget {
  final String tenantId;
  final String academicYear;

  const ExamCalendarListPage({
    Key? key,
    required this.tenantId,
    required this.academicYear,
  }) : super(key: key);

  @override
  State<ExamCalendarListPage> createState() => _ExamCalendarListPageState();
}

class _ExamCalendarListPageState extends State<ExamCalendarListPage> {
  late TextEditingController _examNameController;
  late TextEditingController _examTypeController;
  late TextEditingController _monthNumberController;
  late TextEditingController _displayOrderController;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _deadlineDate;
  Set<int> _selectedGrades = {}; // Grade selection
  late TextEditingController _marks1To5Controller;
  late TextEditingController _marks6To12Controller;

  @override
  void initState() {
    super.initState();

    _examNameController = TextEditingController();
    _examTypeController = TextEditingController();
    _monthNumberController = TextEditingController();
    _displayOrderController = TextEditingController(text: '1');
    _marks1To5Controller = TextEditingController();
    _marks6To12Controller = TextEditingController();

    // Load calendars on init
    context.read<ExamCalendarBloc>().add(
          LoadExamCalendarsEvent(
            tenantId: widget.tenantId,
            academicYear: widget.academicYear,
          ),
        );
  }

  @override
  void dispose() {
    _examNameController.dispose();
    _examTypeController.dispose();
    _monthNumberController.dispose();
    _displayOrderController.dispose();
    _marks1To5Controller.dispose();
    _marks6To12Controller.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, ValueChanged<DateTime> onDateSelected) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  void _showCreateDialog() {
    _examNameController.clear();
    _examTypeController.clear();
    _monthNumberController.clear();
    _displayOrderController.text = '1';
    _startDate = null;
    _endDate = null;
    _deadlineDate = null;
    _selectedGrades = {}; // Reset grade selection
    _marks1To5Controller.text = ''; // Reset marks
    _marks6To12Controller.text = '';

    print('✅ CREATE EXAM DIALOG OPENED - Fill marks and select grades below');

    // IMPORTANT: Capture the BLoC BEFORE showing dialog to avoid provider scope issues
    final bloc = context.read<ExamCalendarBloc>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Exam Calendar Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _examNameController,
                  decoration: const InputDecoration(
                    labelText: 'Exam Name',
                    hintText: 'e.g., June Monthly Test',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _examTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Exam Type',
                    hintText: 'e.g., monthlyTest, quarterlyTest',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _monthNumberController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Month Number',
                    hintText: '1-12',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                // Start date picker
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text(
                    _startDate != null
                        ? DateFormat('MMM d, yyyy').format(_startDate!)
                        : 'Select date',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context, (date) {
                    setState(() => _startDate = date);
                  }),
                ),
                const SizedBox(height: 8),
                // End date picker
                ListTile(
                  title: const Text('End Date'),
                  subtitle: Text(
                    _endDate != null
                        ? DateFormat('MMM d, yyyy').format(_endDate!)
                        : 'Select date',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context, (date) {
                    setState(() => _endDate = date);
                  }),
                ),
                const SizedBox(height: 8),
                // Deadline date picker
                ListTile(
                  title: const Text('Paper Deadline (Optional)'),
                  subtitle: Text(
                    _deadlineDate != null
                        ? DateFormat('MMM d, yyyy').format(_deadlineDate!)
                        : 'Select date',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () => _selectDate(context, (date) {
                    setState(() => _deadlineDate = date);
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _displayOrderController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Display Order',
                    hintText: '1, 2, 3...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                // Grade Selection
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '✅ SELECT GRADES (OPTIONAL)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(12, (index) {
                          final gradeNumber = index + 1;
                          final isSelected = _selectedGrades.contains(gradeNumber);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedGrades.remove(gradeNumber);
                                } else {
                                  _selectedGrades.add(gradeNumber);
                                }
                              });
                              print('Grade $gradeNumber - Selected: ${_selectedGrades.contains(gradeNumber)}');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected ? Colors.blue : Colors.grey,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                'Grade $gradeNumber',
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      if (_selectedGrades.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Selected Grades: ${_selectedGrades.toList()..sort()}',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Marks Configuration Section - Only show if grades are selected
                if (_selectedGrades.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📊 MARKS CONFIGURATION',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                        ),
                        const SizedBox(height: 16),
                        // Show Grades 1-5 marks field only if grades 1-5 are selected
                        if (_selectedGrades.any((g) => g <= 5))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextField(
                              controller: _marks1To5Controller,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Grades 1-5: Total Marks',
                                hintText: 'e.g., 25',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        // Show Grades 6-12 marks field only if grades 6-12 are selected
                        if (_selectedGrades.any((g) => g >= 6))
                          TextField(
                            controller: _marks6To12Controller,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Grades 6-12: Total Marks',
                              hintText: 'e.g., 50',
                              border: OutlineInputBorder(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {

                if (_examNameController.text.isEmpty) {
                }
                if (_examTypeController.text.isEmpty) {
                }
                if (_monthNumberController.text.isEmpty) {
                }
                if (_startDate == null) {
                }
                if (_endDate == null) {
                }

                if (_examNameController.text.isEmpty ||
                    _examTypeController.text.isEmpty ||
                    _monthNumberController.text.isEmpty ||
                    _startDate == null ||
                    _endDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all required fields')),
                  );
                  return;
                }

                try {
                  print('📝 Creating Exam Calendar:');
                  print('   Name: ${_examNameController.text}');
                  print('   Type: ${_examTypeController.text}');
                  print('   Grades 1-5 Marks: ${_marks1To5Controller.text}');
                  print('   Grades 6-12 Marks: ${_marks6To12Controller.text}');
                  print('   Selected Grades: ${_selectedGrades.toList()..sort()}');

                  // Build marks configuration from the input fields
                  Map<String, dynamic>? marksConfig;
                  if (_selectedGrades.isNotEmpty) {
                    marksConfig = {
                      'selected_grades': _selectedGrades.toList()..sort(),
                    };

                    // Add marks for grades 1-5 if applicable
                    if (_selectedGrades.any((g) => g <= 5) && _marks1To5Controller.text.isNotEmpty) {
                      final marks1To5 = int.tryParse(_marks1To5Controller.text);
                      if (marks1To5 != null) {
                        marksConfig['grades_1_to_5_marks'] = marks1To5;
                        print('   ✅ Grades 1-5 marks: $marks1To5');
                      }
                    }

                    // Add marks for grades 6-12 if applicable
                    if (_selectedGrades.any((g) => g >= 6) && _marks6To12Controller.text.isNotEmpty) {
                      final marks6To12 = int.tryParse(_marks6To12Controller.text);
                      if (marks6To12 != null) {
                        marksConfig['grades_6_to_12_marks'] = marks6To12;
                        print('   ✅ Grades 6-12 marks: $marks6To12');
                      }
                    }

                    print('   📊 Marks config to store: $marksConfig');
                  }

                  final event = CreateExamCalendarEvent(
                    tenantId: widget.tenantId,
                    examName: _examNameController.text.trim(),
                    examType: _examTypeController.text.trim(),
                    monthNumber: int.tryParse(_monthNumberController.text) ?? 1,
                    plannedStartDate: _startDate!,
                    plannedEndDate: _endDate!,
                    paperSubmissionDeadline: _deadlineDate,
                    displayOrder: int.tryParse(_displayOrderController.text) ?? 1,
                    marksConfig: marksConfig,
                  );

                  bloc.add(event);

                  Navigator.pop(context);
                } catch (e, stackTrace) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(String calendarId) {
    print('🗑️ Delete confirmation dialog opened for: $calendarId');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Calendar Entry?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              print('🗑️ Deleting calendar: $calendarId');
              context.read<ExamCalendarBloc>().add(
                    DeleteExamCalendarEvent(calendarId: calendarId),
                  );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exam Calendar - ${widget.academicYear}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ExamCalendarBloc>().add(
                    RefreshExamCalendarsEvent(
                      tenantId: widget.tenantId,
                      academicYear: widget.academicYear,
                    ),
                  );
            },
          ),
        ],
      ),
      body: BlocListener<ExamCalendarBloc, ExamCalendarState>(
        listener: (context, state) {
          if (state is ExamCalendarCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${state.calendar.examName} added to calendar'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is ExamCalendarCreationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is ExamCalendarDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Calendar entry deleted'),
                backgroundColor: Colors.green,
              ),
            );
            // Reload the calendar list to reflect the deletion
            context.read<ExamCalendarBloc>().add(
              LoadExamCalendarsEvent(
                tenantId: widget.tenantId,
                academicYear: widget.academicYear,
              ),
            );
          } else if (state is ExamCalendarDeletionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<ExamCalendarBloc, ExamCalendarState>(
          builder: (context, state) {
            // Loading state
            if (state is ExamCalendarLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Empty state
            if (state is ExamCalendarEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.calendar_month,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No exams scheduled',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Exam'),
                    ),
                  ],
                ),
              );
            }

            // Error state
            if (state is ExamCalendarError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<ExamCalendarBloc>().add(
                              RefreshExamCalendarsEvent(
                                tenantId: widget.tenantId,
                                academicYear: widget.academicYear,
                              ),
                            );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            // Loaded state
            if (state is ExamCalendarLoaded) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Exam'),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: state.calendars.length,
                      itemBuilder: (context, index) {
                        final calendar = state.calendars[index];
                        return _ExamCalendarCard(
                          calendar: calendar,
                          onDelete: () => _showDeleteConfirmation(calendar.id),
                        );
                      },
                    ),
                  ),
                ],
              );
            }

            return const Center(
              child: Text('Loading...'),
            );
          },
        ),
      ),
    );
  }
}

class _ExamCalendarCard extends StatelessWidget {
  final ExamCalendar calendar;
  final VoidCallback onDelete;

  const _ExamCalendarCard({
    required this.calendar,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM d');
    final monthFormatter = DateFormat('MMMM');
    final isUpcoming = calendar.isUpcoming;
    final isPastDeadline = calendar.isPastDeadline;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        calendar.examName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              calendar.examType,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple.shade700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${monthFormatter.format(calendar.plannedStartDate)})',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 0),
            const SizedBox(height: 12),

            // Date range with icons
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  '${dateFormatter.format(calendar.plannedStartDate)} - ${dateFormatter.format(calendar.plannedEndDate)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Deadline info
            if (calendar.paperSubmissionDeadline != null)
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Deadline: ${dateFormatter.format(calendar.paperSubmissionDeadline!)}',
                    style: const TextStyle(fontSize: 13, color: Colors.orange),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            // Status indicators
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isUpcoming)
                  Chip(
                    label: const Text('📅 Upcoming'),
                    backgroundColor: Colors.blue.shade100,
                    labelStyle: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                    side: BorderSide(color: Colors.blue.shade300),
                  ),
                if (isPastDeadline)
                  Chip(
                    label: const Text('⚠️ Past Deadline'),
                    backgroundColor: Colors.orange.shade100,
                    labelStyle: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                    side: BorderSide(color: Colors.orange.shade300),
                  ),
                if (calendar.daysUntilDeadline != null && !isPastDeadline)
                  Chip(
                    label: Text('⏱️ ${calendar.daysUntilDeadline} days left'),
                    backgroundColor: Colors.green.shade100,
                    labelStyle: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500),
                    side: BorderSide(color: Colors.green.shade300),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
