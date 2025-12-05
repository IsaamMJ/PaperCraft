import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../bloc/exam_calendar_bloc.dart';
import '../bloc/exam_calendar_event.dart';
import '../bloc/exam_calendar_state.dart';
import '../../domain/entities/exam_calendar.dart';
import '../../../../core/presentation/constants/app_colors.dart';

/// Page to view and manage exam calendars
///
/// Allows admins to:
/// - View yearly exam calendar organized by status (Upcoming, Ongoing, Past)
/// - Create new calendar entries
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
  late TextEditingController _monthNumberController;
  late TextEditingController _displayOrderController;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _deadlineDate;
  Set<int> _selectedGrades = {}; // Grade selection
  late TextEditingController _marks1To5Controller;
  late TextEditingController _marks6To12Controller;
  String? _selectedExamType; // Exam type selection

  final List<String> _examTypes = [
    'monthlyTest',
    'halfYearlyTest',
    'quarterlyTest',
    'finalExam',
    'dailyTest',
  ];

  @override
  void initState() {
    super.initState();

    _examNameController = TextEditingController();
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
    _monthNumberController.clear();
    _displayOrderController.text = '1';
    _startDate = null;
    _endDate = null;
    _deadlineDate = null;
    _selectedGrades = {}; // Reset grade selection
    _marks1To5Controller.text = ''; // Reset marks
    _marks6To12Controller.text = '';
    _selectedExamType = null; // Reset exam type selection


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
                DropdownButtonFormField<String>(
                  value: _selectedExamType,
                  decoration: const InputDecoration(
                    labelText: 'Exam Type',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('Select exam type'),
                  items: _examTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedExamType = value);
                  },
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Exam type is required';
                    }
                    return null;
                  },
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

                if (_examNameController.text.isEmpty ||
                    _selectedExamType == null ||
                    _monthNumberController.text.isEmpty ||
                    _startDate == null ||
                    _endDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in all required fields')),
                  );
                  return;
                }

                try {

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
                      }
                    }

                    // Add marks for grades 6-12 if applicable
                    if (_selectedGrades.any((g) => g >= 6) && _marks6To12Controller.text.isNotEmpty) {
                      final marks6To12 = int.tryParse(_marks6To12Controller.text);
                      if (marks6To12 != null) {
                        marksConfig['grades_6_to_12_marks'] = marks6To12;
                      }
                    }

                  }

                  final event = CreateExamCalendarEvent(
                    tenantId: widget.tenantId,
                    examName: _examNameController.text.trim(),
                    examType: _selectedExamType!,
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


  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
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
              final upcomingExams = state.calendars.where((c) => c.isUpcoming && !c.isPastDeadline).toList();
              final ongoingExams = state.calendars.where((c) => !c.isUpcoming && !c.isPastDeadline).toList();
              final pastExams = state.calendars.where((c) => c.isPastDeadline).toList();

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
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        if (upcomingExams.isNotEmpty) ...[
                          _buildSectionHeader('Upcoming', AppColors.success),
                          ...upcomingExams.map((c) => _ExamCalendarCard(calendar: c)),
                          const SizedBox(height: 24),
                        ],
                        if (ongoingExams.isNotEmpty) ...[
                          _buildSectionHeader('Ongoing', AppColors.warning),
                          ...ongoingExams.map((c) => _ExamCalendarCard(calendar: c)),
                          const SizedBox(height: 24),
                        ],
                        if (pastExams.isNotEmpty) ...[
                          _buildSectionHeader('Past', AppColors.error),
                          ...pastExams.map((c) => _ExamCalendarCard(calendar: c)),
                        ],
                      ],
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

  const _ExamCalendarCard({
    required this.calendar,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM d');
    final daysTilDeadline = calendar.daysUntilDeadline ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black04,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and type
            Row(
              children: [
                Expanded(
                  child: Text(
                    calendar.examName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    calendar.examType,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Date range and deadline
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${dateFormatter.format(calendar.plannedStartDate)} - ${dateFormatter.format(calendar.plannedEndDate)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (calendar.paperSubmissionDeadline != null)
                  Text(
                    'Deadline: ${dateFormatter.format(calendar.paperSubmissionDeadline!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Days left indicator
            if (daysTilDeadline > 0)
              Text(
                '$daysTilDeadline days remaining',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
