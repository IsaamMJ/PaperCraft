part of 'marks_entry_bloc.dart';

abstract class MarksEntryEvent extends Equatable {
  const MarksEntryEvent();
}

class InitializeMarksEntry extends MarksEntryEvent {
  final String examTimetableEntryId;
  final String gradeSectionId;

  const InitializeMarksEntry({
    required this.examTimetableEntryId,
    required this.gradeSectionId,
  });

  @override
  List<Object?> get props => [examTimetableEntryId, gradeSectionId];
}

class UpdateStudentMarkValue extends MarksEntryEvent {
  final String studentId;
  final double marks;

  const UpdateStudentMarkValue({
    required this.studentId,
    required this.marks,
  });

  @override
  List<Object?> get props => [studentId, marks];
}

class UpdateStudentMarkStatus extends MarksEntryEvent {
  final String studentId;
  final StudentMarkStatus status;

  const UpdateStudentMarkStatus({
    required this.studentId,
    required this.status,
  });

  @override
  List<Object?> get props => [studentId, status];
}

class SubmitExamMarks extends MarksEntryEvent {
  const SubmitExamMarks();

  @override
  List<Object?> get props => [];
}

class BulkUploadExamMarks extends MarksEntryEvent {
  final List<Map<String, dynamic>> marksData;

  const BulkUploadExamMarks({required this.marksData});

  @override
  List<Object?> get props => [marksData];
}

class ReloadDraftMarks extends MarksEntryEvent {
  const ReloadDraftMarks();

  @override
  List<Object?> get props => [];
}
