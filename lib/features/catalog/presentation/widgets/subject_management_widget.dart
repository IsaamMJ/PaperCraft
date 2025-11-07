// features/catalog/presentation/widgets/subject_management_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../data/models/subject_catalog_model.dart';
import '../../domain/entities/subject_entity.dart';
import '../bloc/subject_bloc.dart';

class SubjectManagementWidget extends StatefulWidget {
  const SubjectManagementWidget({super.key});

  @override
  State<SubjectManagementWidget> createState() => _SubjectManagementWidgetState();
}

class _SubjectManagementWidgetState extends State<SubjectManagementWidget> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCatalogSubjectId;
  List<SubjectCatalogModel> _catalogSubjects = [];
  List<String> _enabledCatalogSubjectIds = [];
  bool _loadingCatalog = false;

  @override
  void initState() {
    super.initState();
    // Load subjects first
    context.read<SubjectBloc>().add(const LoadSubjects());
    // Then load catalog
    _loadSubjectCatalog();
  }

  Future<void> _loadSubjectCatalog() async {
    setState(() => _loadingCatalog = true);
    context.read<SubjectBloc>().add(const LoadSubjectCatalog());
  }

  Future<void> _refreshPage() async {
    // Show loading state
    setState(() => _loadingCatalog = true);

    // Refresh both the catalog dropdown and the subjects list
    context.read<SubjectBloc>().add(const LoadSubjectCatalog());
    context.read<SubjectBloc>().add(const LoadSubjects());

    // Loading state will be reset by BlocListener when SubjectCatalogLoaded is emitted
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SubjectBloc, SubjectState>(
      listener: (context, state) {
        // FIXED: Move setState to listener instead of builder
        if (state is SubjectCatalogLoaded) {
          setState(() {
            _catalogSubjects = state.catalog;
            _loadingCatalog = false;
          });
        }

        // Track enabled subject IDs to filter them from the dropdown
        if (state is SubjectsLoaded) {
          setState(() {
            _enabledCatalogSubjectIds = state.subjects
                .map((subject) => subject.catalogSubjectId)
                .toList();
          });
        }

        // Handle other state changes
        _handleStateChanges(context, state);
      },
      child: Padding(
        padding: const EdgeInsets.all(UIConstants.paddingMedium),
        child: Column(
          children: [
            _buildForm(),
            SizedBox(height: UIConstants.spacing20),
            const Divider(),
            SizedBox(height: UIConstants.spacing20),
            Expanded(
              child: BlocBuilder<SubjectBloc, SubjectState>(
                builder: (context, state) {
                  // Show loading for any loading state
                  if (state is SubjectLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Show loading while waiting for reload after create/delete
                  if (state is SubjectCreated || state is SubjectDeleted) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state is SubjectError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          SizedBox(height: UIConstants.spacing16),
                          Text(
                            state.message,
                            style: TextStyle(color: AppColors.error),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: UIConstants.spacing16),
                          ElevatedButton(
                            onPressed: () {
                              context.read<SubjectBloc>().add(const LoadSubjects());
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (state is SubjectsLoaded) {
                    if (state.subjects.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.subject_outlined, size: 48, color: AppColors.textTertiary),
                            SizedBox(height: UIConstants.spacing16),
                            Text(
                              'No subjects enabled',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(height: UIConstants.spacing8),
                            Text(
                              'Enable subjects from the catalog above',
                              style: TextStyle(color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: state.subjects.length,
                      itemBuilder: (context, index) {
                        final subject = state.subjects[index];
                        return _buildSubjectCard(subject);
                      },
                    );
                  }

                  return const Center(child: Text('No subjects loaded'));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Enable Subject',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: _loadingCatalog ? null : _refreshPage,
                icon: Icon(
                  Icons.refresh,
                  color: _loadingCatalog ? AppColors.textTertiary : AppColors.primary,
                ),
                tooltip: 'Refresh subjects and catalog',
              ),
            ],
          ),
          SizedBox(height: UIConstants.spacing16),
          DropdownButtonFormField<String>(
            value: _selectedCatalogSubjectId,
            decoration: InputDecoration(
              labelText: 'Select Subject from Catalog',
              hintText: 'Choose a subject to enable',
              prefixIcon: Icon(Icons.subject, color: AppColors.primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
            items: _catalogSubjects
                .where((catalog) => !_enabledCatalogSubjectIds.contains(catalog.id))
                .map((catalog) => DropdownMenuItem(
              value: catalog.id,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    catalog.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (catalog.description != null)
                    Text(
                      catalog.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ))
                .toList(),
            onChanged: _loadingCatalog
                ? null
                : (value) {
              setState(() {
                _selectedCatalogSubjectId = value;
              });
            },
            validator: (value) {
              if (value == null) return 'Please select a subject';
              return null;
            },
          ),
          SizedBox(height: UIConstants.spacing20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loadingCatalog ? null : _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Enable Subject'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(SubjectEntity subject) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary10,
          child: Icon(Icons.subject, color: AppColors.primary, size: 20),
        ),
        title: Text(
          subject.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subject.description != null) Text(subject.description!),
            if (subject.minGrade != null && subject.maxGrade != null)
              Text(
                'Grades ${subject.minGrade}-${subject.maxGrade}',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
          ],
        ),
        trailing: IconButton(
          onPressed: () => _showDeleteDialog(subject),
          icon: Icon(Icons.delete, color: AppColors.error),
          tooltip: 'Disable subject',
        ),
      ),
    );
  }

  void _handleStateChanges(BuildContext context, SubjectState state) {
    if (state is SubjectCreated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subject "${state.subject.name}" enabled successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      _clearForm();
      context.read<SubjectBloc>().add(const LoadSubjects());
    } else if (state is SubjectDeleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subject disabled successfully'),
          backgroundColor: Colors.orange,
        ),
      );
      context.read<SubjectBloc>().add(const LoadSubjects());
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final newSubject = SubjectEntity(
      id: '',
      tenantId: '',
      catalogSubjectId: _selectedCatalogSubjectId!,
      name: '',
      isActive: true,
      createdAt: DateTime.now(),
    );

    context.read<SubjectBloc>().add(CreateSubject(newSubject));
  }

  void _clearForm() {
    setState(() {
      _selectedCatalogSubjectId = null;
    });
  }

  void _showDeleteDialog(SubjectEntity subject) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Disable Subject'),
          content: Text('Are you sure you want to disable "${subject.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<SubjectBloc>().add(DeleteSubject(subject.id));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Disable'),
            ),
          ],
        );
      },
    );
  }
}