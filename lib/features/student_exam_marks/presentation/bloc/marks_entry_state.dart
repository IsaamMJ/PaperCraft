import 'package:equatable/equatable.dart';
import '../../domain/entities/student_exam_marks_entity.dart';
import '../../domain/entities/student_mark_entry_dto.dart';

abstract class MarksEntryState extends Equatable {
  const MarksEntryState();

  @override
  List<Object?> get props => [];
}

class MarksEntryInitial extends MarksEntryState {
  const MarksEntryInitial();
}

class MarksEntryLoading extends MarksEntryState {
  final String message;

  const MarksEntryLoading({this.message = 'Loading marks...'});

  @override
  List<Object?> get props => [message];
}

class MarksEntryLoaded extends MarksEntryState {
  final List<StudentExamMarksEntity> marks;
  final List<StudentMarkEntryDto> editableMarks;
  final bool isDraft;
  final String examTimetableEntryId;

  const MarksEntryLoaded({
    required this.marks,
    required this.editableMarks,
    required this.isDraft,
    required this.examTimetableEntryId,
  });

  @override
  List<Object?> get props => [marks, editableMarks, isDraft, examTimetableEntryId];

  MarksEntryLoaded copyWith({
    List<StudentExamMarksEntity>? marks,
    List<StudentMarkEntryDto>? editableMarks,
    bool? isDraft,
    String? examTimetableEntryId,
  }) {
    return MarksEntryLoaded(
      marks: marks ?? this.marks,
      editableMarks: editableMarks ?? this.editableMarks,
      isDraft: isDraft ?? this.isDraft,
      examTimetableEntryId: examTimetableEntryId ?? this.examTimetableEntryId,
    );
  }
}

class MarkUpdateInProgress extends MarksEntryState {
  final List<StudentMarkEntryDto> currentMarks;

  const MarkUpdateInProgress({required this.currentMarks});

  @override
  List<Object?> get props => [currentMarks];
}

class MarksSubmitting extends MarksEntryState {
  final String message;

  const MarksSubmitting({this.message = 'Submitting marks...'});

  @override
  List<Object?> get props => [message];
}

class MarksSubmitted extends MarksEntryState {
  final String message;
  final int totalRecords;

  const MarksSubmitted({
    required this.message,
    required this.totalRecords,
  });

  @override
  List<Object?> get props => [message, totalRecords];
}

class MarksSavedAsDraft extends MarksEntryState {
  final String message;
  final int totalRecords;

  const MarksSavedAsDraft({
    required this.message,
    required this.totalRecords,
  });

  @override
  List<Object?> get props => [message, totalRecords];
}

class MarksEntryError extends MarksEntryState {
  final String message;
  final String? details;

  const MarksEntryError({
    required this.message,
    this.details,
  });

  @override
  List<Object?> get props => [message, details];
}
