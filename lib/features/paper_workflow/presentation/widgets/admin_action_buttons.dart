// features/question_papers/pages/widgets/shared/admin_action_buttons.dart
import 'package:flutter/material.dart';
import '../../../../core/presentation/constants/ui_constants.dart';
import '../../domain/entities/question_paper_entity.dart';

class AdminActionButtons extends StatelessWidget {
  final QuestionPaperEntity paper;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onViewDetails;
  final VoidCallback? onEdit;  // ADDED: Edit button callback
  final VoidCallback? onRestore;  // ADDED: Restore spare paper callback
  final VoidCallback? onMarkSpare;  // ADDED: Mark as spare button callback
  final bool isCompact;
  final bool isLoading;

  const AdminActionButtons({
    super.key,
    required this.paper,
    this.onApprove,
    this.onReject,
    this.onViewDetails,
    this.onEdit,  // ADDED: Edit parameter
    this.onRestore,  // ADDED: Restore parameter
    this.onMarkSpare,  // ADDED: Mark as spare parameter
    this.isCompact = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Only show action buttons for submitted or spare papers
    if (!paper.status.isSubmitted && !paper.status.isSpare) {
      return _buildViewButton(context);
    }

    // Show restore button for spare papers
    if (paper.status.isSpare) {
      return _buildSpareActions(context);
    }

    if (isCompact) {
      return _buildCompactActions(context);
    }

    return _buildFullActions(context);
  }

  Widget _buildSpareActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            border: Border.all(color: Colors.orange.shade300),
            borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This is a spare paper (backup)',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: isLoading ? null : onRestore,
          icon: isLoading
              ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Icon(Icons.restore),
          label: Text('Restore to Submitted'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade600,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
            ),
          ),
        ),
        SizedBox(height: 8),
        TextButton.icon(
          onPressed: onViewDetails,
          icon: Icon(Icons.visibility_outlined),
          label: Text('View Full Details'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue.shade600,
            padding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quick approve button
        IconButton(
          onPressed: isLoading ? null : onApprove,
          icon: isLoading
              ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.green.shade600,
            ),
          )
              : Icon(
            Icons.check_circle_outline,
            color: Colors.green.shade600,
          ),
          tooltip: 'Approve',
          iconSize: 20,
        ),
        // Quick reject button
        IconButton(
          onPressed: isLoading ? null : onReject,
          icon: Icon(
            Icons.cancel_outlined,
            color: Colors.red.shade600,
          ),
          tooltip: 'Reject',
          iconSize: 20,
        ),
        // View details button
        IconButton(
          onPressed: onViewDetails,
          icon: Icon(
            Icons.visibility_outlined,
            color: Colors.blue.shade600,
          ),
          tooltip: 'View Details',
          iconSize: 20,
        ),
      ],
    );
  }

  Widget _buildFullActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : onApprove,
                icon: isLoading
                    ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Icon(Icons.check),
                label: Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: isLoading ? null : onReject,
                icon: Icon(Icons.close),
                label: Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade600),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  ),
                ),
              ),
            ),
          ],
        ),
        // ADDED: Edit button row for admin corrections
        SizedBox(height: 8),
        if (onEdit != null)
          ElevatedButton.icon(
            onPressed: isLoading ? null : onEdit,
            icon: Icon(Icons.edit_outlined),
            label: Text('Edit & Correct'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade600,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
          ),
        SizedBox(height: 8),
        // ADDED: Mark as spare button
        if (onMarkSpare != null)
          OutlinedButton.icon(
            onPressed: isLoading ? null : onMarkSpare,
            icon: Icon(Icons.bookmark_outline),
            label: Text('Mark as Spare'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade600,
              side: BorderSide(color: Colors.orange.shade600),
              padding: EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
              ),
            ),
          ),
        SizedBox(height: 8),
        TextButton.icon(
          onPressed: onViewDetails,
          icon: Icon(Icons.visibility_outlined),
          label: Text('View Full Details'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue.shade600,
            padding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildViewButton(BuildContext context) {
    return TextButton.icon(
      onPressed: onViewDetails,
      icon: Icon(Icons.visibility_outlined),
      label: Text('View Details'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.blue.shade600,
        padding: EdgeInsets.symmetric(
          vertical: isCompact ? 4 : 8,
          horizontal: isCompact ? 8 : 12,
        ),
      ),
    );
  }
}

// Rejection Dialog Widget
class RejectPaperDialog extends StatefulWidget {
  final String paperTitle;
  final Function(String reason) onReject;

  const RejectPaperDialog({
    super.key,
    required this.paperTitle,
    required this.onReject,
  });

  @override
  State<RejectPaperDialog> createState() => _RejectPaperDialogState();
}

class _RejectPaperDialogState extends State<RejectPaperDialog> {
  final TextEditingController _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _handleReject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      widget.onReject(_reasonController.text.trim());
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject paper: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reject Paper'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to reject:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 4),
            Text(
              widget.paperTitle,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Please provide a reason for rejection:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            TextFormField(
              controller: _reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter specific feedback for the teacher...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(UIConstants.radiusMedium),
                  borderSide: BorderSide(color: Colors.red.shade600, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please provide a rejection reason';
                }
                if (value.trim().length < 10) {
                  return 'Please provide a more detailed reason';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleReject,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Text('Reject Paper'),
        ),
      ],
    );
  }
}