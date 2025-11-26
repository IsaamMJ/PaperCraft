import 'package:equatable/equatable.dart';
import '../../domain/entities/student_mark_entry_dto.dart';

abstract class MarksEntryEvent extends Equatable {
  const MarksEntryEvent();

  @override
  List<Object?> get props => [];
}

class LoadMarksForTimetableEvent extends MarksEntryEvent {
  final String examTimetableEntryId;

  const LoadMarksForTimetableEvent({required this.examTimetableEntryId});

  @override
  List<Object?> get props => [examTimetableEntryId];
}

class UpdateStudentMarkEvent extends MarksEntryEvent {
  final int studentIndex;
  final double totalMarks;
  final String status;
  final String? remarks;

  const UpdateStudentMarkEvent({
    required this.studentIndex,
    required this.totalMarks,
    required this.status,
    this.remarks,
  });

  @override
  List<Object?> get props => [studentIndex, totalMarks, status, remarks];
}

class SaveMarksAsDraftEvent extends MarksEntryEvent {
  final String examTimetableEntryId;
  final List<StudentMarkEntryDto> marks;
  final String teacherId;

  const SaveMarksAsDraftEvent({
    required this.examTimetableEntryId,
    required this.marks,
    required this.teacherId,
  });

  @override
  List<Object?> get props => [examTimetableEntryId, marks, teacherId];
}

class SubmitMarksEvent extends MarksEntryEvent {
  final String examTimetableEntryId;
  final List<StudentMarkEntryDto> marks;
  final String teacherId;

  const SubmitMarksEvent({
    required this.examTimetableEntryId,
    required this.marks,
    required this.teacherId,
  });

  @override
  List<Object?> get props => [examTimetableEntryId, marks, teacherId];
}

class ClearMarksEntryEvent extends MarksEntryEvent {
  const ClearMarksEntryEvent();
}
