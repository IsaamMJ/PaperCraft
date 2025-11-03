import 'package:equatable/equatable.dart';

/// Events for GradeSectionBloc
abstract class GradeSectionEvent extends Equatable {
  const GradeSectionEvent();

  @override
  List<Object?> get props => [];
}

/// Load all grade sections for tenant
class LoadGradeSectionsEvent extends GradeSectionEvent {
  final String tenantId;
  final String? gradeId; // Optional filter by grade

  const LoadGradeSectionsEvent({
    required this.tenantId,
    this.gradeId,
  });

  @override
  List<Object?> get props => [tenantId, gradeId];
}

/// Create a new grade section
class CreateGradeSectionEvent extends GradeSectionEvent {
  final String tenantId;
  final String gradeId;
  final String sectionName;
  final int displayOrder;

  const CreateGradeSectionEvent({
    required this.tenantId,
    required this.gradeId,
    required this.sectionName,
    required this.displayOrder,
  });

  @override
  List<Object?> get props => [tenantId, gradeId, sectionName, displayOrder];
}

/// Delete (soft delete) a grade section
class DeleteGradeSectionEvent extends GradeSectionEvent {
  final String sectionId;

  const DeleteGradeSectionEvent({required this.sectionId});

  @override
  List<Object?> get props => [sectionId];
}

/// Refresh grade sections (reload from server)
class RefreshGradeSectionsEvent extends GradeSectionEvent {
  final String tenantId;
  final String? gradeId;

  const RefreshGradeSectionsEvent({
    required this.tenantId,
    this.gradeId,
  });

  @override
  List<Object?> get props => [tenantId, gradeId];
}
