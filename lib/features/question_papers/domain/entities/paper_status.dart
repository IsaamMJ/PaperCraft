// features/question_papers/domain2/entities/paper_status.dart
enum PaperStatus {
  draft('draft'),
  submitted('submitted'),
  approved('approved'),
  rejected('rejected');

  const PaperStatus(this.value);

  final String value;

  static PaperStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return PaperStatus.draft;
      case 'submitted':
        return PaperStatus.submitted;
      case 'approved':
        return PaperStatus.approved;
      case 'rejected':
        return PaperStatus.rejected;
      default:
        throw ArgumentError('Invalid paper status: $status');
    }
  }

  bool get isDraft => this == PaperStatus.draft;
  bool get isSubmitted => this == PaperStatus.submitted;
  bool get isApproved => this == PaperStatus.approved;
  bool get isRejected => this == PaperStatus.rejected;

  // Status transition validation
  bool canTransitionTo(PaperStatus newStatus) {
    switch (this) {
      case PaperStatus.draft:
        return newStatus == PaperStatus.submitted;
      case PaperStatus.submitted:
        return newStatus == PaperStatus.approved || newStatus == PaperStatus.rejected;
      case PaperStatus.rejected:
        return newStatus == PaperStatus.submitted; // Can resubmit
      case PaperStatus.approved:
        return false; // Final state
    }
  }

  String get displayName {
    switch (this) {
      case PaperStatus.draft:
        return 'Draft';
      case PaperStatus.submitted:
        return 'Submitted';
      case PaperStatus.approved:
        return 'Approved';
      case PaperStatus.rejected:
        return 'Rejected';
    }
  }
}