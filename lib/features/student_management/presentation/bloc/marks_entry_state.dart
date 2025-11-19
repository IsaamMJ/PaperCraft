part of 'marks_entry_bloc.dart';

abstract class MarksEntryState extends Equatable {
  const MarksEntryState();
}

class MarksEntryInitial extends MarksEntryState {
  const MarksEntryInitial();

  @override
  List<Object?> get props => [];
}

class MarksEntryLoading extends MarksEntryState {
  const MarksEntryLoading();

  @override
  List<Object?> get props => [];
}

class MarksEntryReady extends MarksEntryState {
  final String examTimetableEntryId;
  final String gradeSectionId;
  final List<StudentEntity> students;
  final Map<String, StudentMarkEntry> marksEntries;
  final bool isDraft;

  const MarksEntryReady({
    required this.examTimetableEntryId,
    required this.gradeSectionId,
    required this.students,
    required this.marksEntries,
    required this.isDraft,
  });

  MarksEntryReady copyWith({
    String? examTimetableEntryId,
    String? gradeSectionId,
    List<StudentEntity>? students,
    Map<String, StudentMarkEntry>? marksEntries,
    bool? isDraft,
  }) {
    return MarksEntryReady(
      examTimetableEntryId: examTimetableEntryId ?? this.examTimetableEntryId,
      gradeSectionId: gradeSectionId ?? this.gradeSectionId,
      students: students ?? this.students,
      marksEntries: marksEntries ?? this.marksEntries,
      isDraft: isDraft ?? this.isDraft,
    );
  }

  @override
  List<Object?> get props => [
        examTimetableEntryId,
        gradeSectionId,
        students,
        marksEntries,
        isDraft,
      ];
}

class SubmittingMarks extends MarksEntryState {
  const SubmittingMarks();

  @override
  List<Object?> get props => [];
}

class MarksSubmitted extends MarksEntryState {
  final MarksSubmissionSummary summary;

  const MarksSubmitted(this.summary);

  @override
  List<Object?> get props => [summary];
}

class BulkUploadingMarks extends MarksEntryState {
  const BulkUploadingMarks();

  @override
  List<Object?> get props => [];
}

class BulkUploadFailed extends MarksEntryState {
  final String message;

  const BulkUploadFailed(this.message);

  @override
  List<Object?> get props => [message];
}

class MarkValidationError extends MarksEntryState {
  final String message;

  const MarkValidationError(this.message);

  @override
  List<Object?> get props => [message];
}

class MarksEntryError extends MarksEntryState {
  final String message;

  const MarksEntryError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Helper class to represent a student's mark entry
class StudentMarkEntry extends Equatable {
  final String studentId;
  final double marks;
  final StudentMarkStatus status;
  final String? remarks;

  const StudentMarkEntry({
    required this.studentId,
    required this.marks,
    required this.status,
    this.remarks,
  });

  StudentMarkEntry copyWith({
    String? studentId,
    double? marks,
    StudentMarkStatus? status,
    String? remarks,
  }) {
    return StudentMarkEntry(
      studentId: studentId ?? this.studentId,
      marks: marks ?? this.marks,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
    );
  }

  @override
  List<Object?> get props => [studentId, marks, status, remarks];
}
