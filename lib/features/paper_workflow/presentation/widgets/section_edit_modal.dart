import 'package:flutter/material.dart';
import '../../../../core/presentation/constants/app_colors.dart';
import '../../../../core/presentation/constants/ui_constants.dart';

class SectionEditModal extends StatefulWidget {
  final String sectionName;
  final int sectionNumber;
  final Function(String newName) onSave;
  final VoidCallback onCancel;

  const SectionEditModal({
    super.key,
    required this.sectionName,
    required this.sectionNumber,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<SectionEditModal> createState() => _SectionEditModalState();
}

class _SectionEditModalState extends State<SectionEditModal> {
  late TextEditingController _sectionNameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _sectionNameController = TextEditingController(text: widget.sectionName);
  }

  @override
  void dispose() {
    _sectionNameController.dispose();
    super.dispose();
  }

  void _saveChanges() {

    final updatedName = _sectionNameController.text.trim();

    // Validation
    if (updatedName.isEmpty) {
      _showErrorSnackBar('Section name cannot be empty');
      return;
    }

    if (updatedName == widget.sectionName) {
      Navigator.pop(context);
      return;
    }

    setState(() => _isSaving = true);

    // Call the save callback

    widget.onSave(updatedName);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 48,
        vertical: isMobile ? 24 : 48,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UIConstants.radiusLarge),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(UIConstants.paddingMedium),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(UIConstants.radiusLarge),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Edit Section ${widget.sectionNumber}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: widget.onCancel,
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(UIConstants.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Name
                    _buildLabel('Section Name'),
                    SizedBox(height: UIConstants.spacing8),
                    TextField(
                      controller: _sectionNameController,
                      maxLines: 2,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Enter the section name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(UIConstants.radiusSmall),
                          borderSide: BorderSide(color: AppColors.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.all(UIConstants.paddingSmall),
                      ),
                    ),
                    SizedBox(height: UIConstants.spacing16),
                  ],
                ),
              ),

              // Action Buttons
              Container(
                padding: const EdgeInsets.all(UIConstants.paddingMedium),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : widget.onCancel,
                      child: const Text('Cancel'),
                    ),
                    SizedBox(width: UIConstants.spacing12),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveChanges,
                      icon: _isSaving
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
