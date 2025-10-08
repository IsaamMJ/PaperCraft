// features/paper_workflow/domain/entities/paper_rejection_history.dart
import 'package:equatable/equatable.dart';

class PaperRejectionHistory extends Equatable {
  final String id;
  final String paperId;
  final String rejectionReason;
  final String rejectedBy;
  final DateTime rejectedAt;
  final int revisionNumber;

  const PaperRejectionHistory({
    required this.id,
    required this.paperId,
    required this.rejectionReason,
    required this.rejectedBy,
    required this.rejectedAt,
    required this.revisionNumber,
  });

  @override
  List<Object?> get props => [
        id,
        paperId,
        rejectionReason,
        rejectedBy,
        rejectedAt,
        revisionNumber,
      ];

  PaperRejectionHistory copyWith({
    String? id,
    String? paperId,
    String? rejectionReason,
    String? rejectedBy,
    DateTime? rejectedAt,
    int? revisionNumber,
  }) {
    return PaperRejectionHistory(
      id: id ?? this.id,
      paperId: paperId ?? this.paperId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      revisionNumber: revisionNumber ?? this.revisionNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paper_id': paperId,
      'rejection_reason': rejectionReason,
      'rejected_by': rejectedBy,
      'rejected_at': rejectedAt.toIso8601String(),
      'revision_number': revisionNumber,
    };
  }

  factory PaperRejectionHistory.fromJson(Map<String, dynamic> json) {
    return PaperRejectionHistory(
      id: json['id'] as String,
      paperId: json['paper_id'] as String,
      rejectionReason: json['rejection_reason'] as String,
      rejectedBy: json['rejected_by'] as String,
      rejectedAt: DateTime.parse(json['rejected_at'] as String),
      revisionNumber: json['revision_number'] as int,
    );
  }
}
