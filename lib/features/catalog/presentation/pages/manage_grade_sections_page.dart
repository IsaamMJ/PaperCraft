import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/grade_section_bloc.dart';
import '../bloc/grade_section_event.dart';
import '../bloc/grade_section_state.dart';
import '../bloc/grade_bloc.dart';
import '../../domain/entities/grade_section.dart';
import '../../domain/entities/grade_entity.dart';

/// Page to manage grade sections for a tenant
///
/// Allows admins to:
/// - View all sections (A, B, C) for each grade
/// - Create new sections
/// - Delete sections
class ManageGradeSectionsPage extends StatefulWidget {
  final String tenantId;
  final String? gradeId; // Optional: filter by specific grade

  const ManageGradeSectionsPage({
    Key? key,
    required this.tenantId,
    this.gradeId,
  }) : super(key: key);

  @override
  State<ManageGradeSectionsPage> createState() =>
      _ManageGradeSectionsPageState();
}

class _ManageGradeSectionsPageState extends State<ManageGradeSectionsPage> {
  late TextEditingController _sectionNameController;
  late TextEditingController _gradeIdController;
  late TextEditingController _displayOrderController;
  Map<String, String> gradeIdToNumberMap = {}; // Map gradeId -> grade number

  @override
  void initState() {
    super.initState();
    _sectionNameController = TextEditingController();
    _gradeIdController = TextEditingController();
    _displayOrderController = TextEditingController(text: '1');

    // Load sections on init
    context.read<GradeSectionBloc>().add(
          LoadGradeSectionsEvent(
            tenantId: widget.tenantId,
            gradeId: widget.gradeId,
          ),
        );

    // Load grades to map gradeId to grade numbers
    context.read<GradeBloc>().add(
          const LoadGrades(),
        );

    print('[ManageGradeSectionsPage] Grade Sections page loaded');
  }

  @override
  void dispose() {
    _sectionNameController.dispose();
    _gradeIdController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  void _showCreateDialog() {
    _sectionNameController.clear();
    _gradeIdController.clear();
    _displayOrderController.text = '1';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Grade Section'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _gradeIdController,
                decoration: const InputDecoration(
                  labelText: 'Grade ID',
                  hintText: 'e.g., Grade 5, Grade 6',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _sectionNameController,
                decoration: const InputDecoration(
                  labelText: 'Section Name',
                  hintText: 'e.g., A, B, C',
                  border: OutlineInputBorder(),
                ),
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
              if (_sectionNameController.text.isEmpty ||
                  _gradeIdController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }

              context.read<GradeSectionBloc>().add(
                    CreateGradeSectionEvent(
                      tenantId: widget.tenantId,
                      gradeId: _gradeIdController.text.trim(),
                      sectionName: _sectionNameController.text.trim(),
                      displayOrder: int.tryParse(_displayOrderController.text) ?? 1,
                    ),
                  );

              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String sectionId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section?'),
        content: const Text(
          'This will deactivate the section. It can be reactivated later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<GradeSectionBloc>().add(
                    DeleteGradeSectionEvent(sectionId: sectionId),
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
        title: const Text('Manage Grade Sections'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<GradeSectionBloc>().add(
                    RefreshGradeSectionsEvent(
                      tenantId: widget.tenantId,
                      gradeId: widget.gradeId,
                    ),
                  );
            },
          ),
        ],
      ),
      body: BlocListener<GradeSectionBloc, GradeSectionState>(
        listener: (context, state) {
          if (state is GradeSectionCreated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Section ${state.section.sectionName} created successfully',
                ),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is GradeSectionCreationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is GradeSectionDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Section deleted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is GradeSectionDeletionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<GradeSectionBloc, GradeSectionState>(
          builder: (context, state) {
            // Loading state
            if (state is GradeSectionLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Empty state
            if (state is GradeSectionEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.inbox,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No sections found',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Section'),
                    ),
                  ],
                ),
              );
            }

            // Error state
            if (state is GradeSectionError) {
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
                        context.read<GradeSectionBloc>().add(
                              RefreshGradeSectionsEvent(
                                tenantId: widget.tenantId,
                                gradeId: widget.gradeId,
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

            // Loaded state - GROUP BY GRADE
            if (state is GradeSectionLoaded) {
              // Group sections by gradeId
              final Map<String, List<GradeSection>> sectionsByGrade = {};
              for (final section in state.sections) {
                sectionsByGrade.putIfAbsent(section.gradeId, () => []).add(section);
              }

              // Sort sections within each grade
              for (final list in sectionsByGrade.values) {
                list.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
              }

              // Listen to grades to populate the map
              return BlocListener<GradeBloc, GradeState>(
                listener: (context, gradeState) {
                  if (gradeState is GradesLoaded) {
                    // Build map of gradeId -> grade number
                    gradeIdToNumberMap.clear();
                    for (final grade in gradeState.grades) {
                      gradeIdToNumberMap[grade.id] = 'Grade ${grade.gradeNumber}';
                    }
                    print('[ManageGradeSectionsPage] Loaded ${gradeState.grades.length} grades');
                  }
                },
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: sectionsByGrade.length,
                        itemBuilder: (context, index) {
                          final gradeId = sectionsByGrade.keys.elementAt(index);
                          final sections = sectionsByGrade[gradeId]!;
                          final gradeName = gradeIdToNumberMap[gradeId] ?? 'Grade (Unknown)';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            color: Colors.grey[50],
                            child: Column(
                              children: [
                                // Grade header
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              gradeName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              '${sections.length} section(s)',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                // Sections under this grade
                                ...sections.map((section) {
                                  return ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue,
                                      radius: 18,
                                      child: Text(
                                        section.sectionName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    title: Text('Section ${section.sectionName}'),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'delete') {
                                          _showDeleteConfirmation(section.id);
                                        }
                                      },
                                      itemBuilder: (BuildContext context) => [
                                        const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }

            // Default/initial state
            return const Center(
              child: Text('Loading...'),
            );
          },
        ),
      ),
    );
  }
}
