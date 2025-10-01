class SubjectTemplate {
  final String name;
  final String? description;

  const SubjectTemplate({
    required this.name,
    this.description,
  });
}

class ExamSectionTemplate {
  final String name;
  final String type;
  final int questions;
  final int marksPerQuestion;
  final int? questionsToAnswer;

  const ExamSectionTemplate({
    required this.name,
    required this.type,
    required this.questions,
    required this.marksPerQuestion,
    this.questionsToAnswer,
  });
}

class ExamTypeTemplate {
  final String name;
  final int durationMinutes;
  final List<ExamSectionTemplate> sections;

  const ExamTypeTemplate({
    required this.name,
    required this.durationMinutes,
    required this.sections,
  });
}

enum SchoolType {
  cbse,
  stateBoard,
}

class SchoolTemplates {
  static const cbseSubjects = [
    SubjectTemplate(name: 'Mathematics'),
    SubjectTemplate(name: 'Physics'),
    SubjectTemplate(name: 'Chemistry'),
    SubjectTemplate(name: 'Biology'),
    SubjectTemplate(name: 'English'),
    SubjectTemplate(name: 'Hindi'),
    SubjectTemplate(name: 'Tamil'),
    SubjectTemplate(name: 'History'),
    SubjectTemplate(name: 'Geography'),
    SubjectTemplate(name: 'Political Science'),
    SubjectTemplate(name: 'Economics'),
    SubjectTemplate(name: 'Computer Science'),
    SubjectTemplate(name: 'Physical Education'),
    SubjectTemplate(name: 'Business Studies'),
    SubjectTemplate(name: 'Accountancy'),
  ];

  static const stateBoardSubjects = [
    SubjectTemplate(name: 'Mathematics'),
    SubjectTemplate(name: 'Physics'),
    SubjectTemplate(name: 'Chemistry'),
    SubjectTemplate(name: 'Biology'),
    SubjectTemplate(name: 'English'),
    SubjectTemplate(name: 'Tamil'),
    SubjectTemplate(name: 'History'),
    SubjectTemplate(name: 'Geography'),
    SubjectTemplate(name: 'Civics'),
    SubjectTemplate(name: 'Economics'),
    SubjectTemplate(name: 'Computer Science'),
    SubjectTemplate(name: 'Commerce'),
  ];

  static List<int> cbseGrades = List.generate(12, (i) => i + 1);
  static List<int> stateBoardGrades = List.generate(10, (i) => i + 1);

  static const cbseExamTypes = [
    ExamTypeTemplate(
      name: 'Quarterly Exam',
      durationMinutes: 180,
      sections: [
        ExamSectionTemplate(
          name: 'Part A - Multiple Choice',
          type: 'multiple_choice',
          questions: 20,
          marksPerQuestion: 1,
        ),
        ExamSectionTemplate(
          name: 'Part B - Short Answer',
          type: 'short_answer',
          questions: 10,
          marksPerQuestion: 3,
        ),
        ExamSectionTemplate(
          name: 'Part C - Long Answer',
          type: 'short_answer',
          questions: 5,
          marksPerQuestion: 10,
        ),
      ],
    ),
    ExamTypeTemplate(
      name: 'Half Yearly Exam',
      durationMinutes: 180,
      sections: [
        ExamSectionTemplate(
          name: 'Part A - Multiple Choice',
          type: 'multiple_choice',
          questions: 20,
          marksPerQuestion: 1,
        ),
        ExamSectionTemplate(
          name: 'Part B - Short Answer',
          type: 'short_answer',
          questions: 10,
          marksPerQuestion: 3,
        ),
        ExamSectionTemplate(
          name: 'Part C - Long Answer',
          type: 'short_answer',
          questions: 5,
          marksPerQuestion: 10,
        ),
      ],
    ),
    ExamTypeTemplate(
      name: 'Annual Exam',
      durationMinutes: 180,
      sections: [
        ExamSectionTemplate(
          name: 'Part A - Multiple Choice',
          type: 'multiple_choice',
          questions: 25,
          marksPerQuestion: 1,
        ),
        ExamSectionTemplate(
          name: 'Part B - Short Answer',
          type: 'short_answer',
          questions: 10,
          marksPerQuestion: 3,
        ),
        ExamSectionTemplate(
          name: 'Part C - Long Answer',
          type: 'short_answer',
          questions: 5,
          marksPerQuestion: 9,
        ),
      ],
    ),
    ExamTypeTemplate(
      name: 'Unit Test',
      durationMinutes: 60,
      sections: [
        ExamSectionTemplate(
          name: 'Part A - Multiple Choice',
          type: 'multiple_choice',
          questions: 10,
          marksPerQuestion: 1,
        ),
        ExamSectionTemplate(
          name: 'Part B - Short Answer',
          type: 'short_answer',
          questions: 5,
          marksPerQuestion: 3,
        ),
      ],
    ),
  ];

  static const stateBoardExamTypes = [
    ExamTypeTemplate(
      name: 'Quarterly Exam',
      durationMinutes: 180,
      sections: [
        ExamSectionTemplate(
          name: 'Part A - Multiple Choice',
          type: 'multiple_choice',
          questions: 15,
          marksPerQuestion: 1,
        ),
        ExamSectionTemplate(
          name: 'Part B - Short Answer',
          type: 'short_answer',
          questions: 8,
          marksPerQuestion: 2,
        ),
        ExamSectionTemplate(
          name: 'Part C - Long Answer',
          type: 'short_answer',
          questions: 5,
          marksPerQuestion: 5,
        ),
      ],
    ),
    ExamTypeTemplate(
      name: 'Half Yearly Exam',
      durationMinutes: 180,
      sections: [
        ExamSectionTemplate(
          name: 'Part A - Multiple Choice',
          type: 'multiple_choice',
          questions: 15,
          marksPerQuestion: 1,
        ),
        ExamSectionTemplate(
          name: 'Part B - Short Answer',
          type: 'short_answer',
          questions: 8,
          marksPerQuestion: 2,
        ),
        ExamSectionTemplate(
          name: 'Part C - Long Answer',
          type: 'short_answer',
          questions: 5,
          marksPerQuestion: 5,
        ),
      ],
    ),
    ExamTypeTemplate(
      name: 'Annual Exam',
      durationMinutes: 180,
      sections: [
        ExamSectionTemplate(
          name: 'Part A - Multiple Choice',
          type: 'multiple_choice',
          questions: 20,
          marksPerQuestion: 1,
        ),
        ExamSectionTemplate(
          name: 'Part B - Short Answer',
          type: 'short_answer',
          questions: 10,
          marksPerQuestion: 2,
        ),
        ExamSectionTemplate(
          name: 'Part C - Long Answer',
          type: 'short_answer',
          questions: 5,
          marksPerQuestion: 5,
        ),
      ],
    ),
  ];

  static List<SubjectTemplate> getSubjects(SchoolType type) {
    switch (type) {
      case SchoolType.cbse:
        return cbseSubjects;
      case SchoolType.stateBoard:
        return stateBoardSubjects;
    }
  }

  static List<int> getGrades(SchoolType type) {
    switch (type) {
      case SchoolType.cbse:
        return cbseGrades;
      case SchoolType.stateBoard:
        return stateBoardGrades;
    }
  }

  static List<ExamTypeTemplate> getExamTypes(SchoolType type) {
    switch (type) {
      case SchoolType.cbse:
        return cbseExamTypes;
      case SchoolType.stateBoard:
        return stateBoardExamTypes;
    }
  }

  static String getDisplayName(SchoolType type) {
    switch (type) {
      case SchoolType.cbse:
        return 'CBSE School';
      case SchoolType.stateBoard:
        return 'State Board School';
    }
  }

  static String getDescription(SchoolType type) {
    switch (type) {
      case SchoolType.cbse:
        return '15 subjects, 12 grades (1-12), 4 exam types';
      case SchoolType.stateBoard:
        return '12 subjects, 10 grades (1-10), 3 exam types';
    }
  }
}