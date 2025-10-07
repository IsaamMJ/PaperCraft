// features/onboarding/data/template/school_templates.dart

class SubjectTemplate {
  final String catalogSubjectId; // Reference to subject_catalog
  final String name;

  const SubjectTemplate({
    required this.catalogSubjectId,
    required this.name,
  });
}

class ExamSectionTemplate {
  final String name;
  final String type;
  final int questions;
  final int marksPerQuestion;

  const ExamSectionTemplate({
    required this.name,
    required this.type,
    required this.questions,
    required this.marksPerQuestion,
  });
}

class ExamTypeTemplate {
  final String name;
  final String subjectName; // Link to subject
  final int durationMinutes;
  final List<ExamSectionTemplate> sections;

  const ExamTypeTemplate({
    required this.name,
    required this.subjectName,
    required this.durationMinutes,
    required this.sections,
  });
}

enum SchoolType {
  cbse,
  stateBoard,
}

class SchoolTemplates {
  // These match your subject_catalog seed data names
  static const cbseSubjects = [
    SubjectTemplate(catalogSubjectId: 'Mathematics', name: 'Mathematics'),
    SubjectTemplate(catalogSubjectId: 'Physics', name: 'Physics'),
    SubjectTemplate(catalogSubjectId: 'Chemistry', name: 'Chemistry'),
    SubjectTemplate(catalogSubjectId: 'Biology', name: 'Biology'),
    SubjectTemplate(catalogSubjectId: 'English', name: 'English'),
    SubjectTemplate(catalogSubjectId: 'Hindi', name: 'Hindi'),
    SubjectTemplate(catalogSubjectId: 'Tamil', name: 'Tamil'),
    SubjectTemplate(catalogSubjectId: 'Computer Science', name: 'Computer Science'),
  ];

  static const stateBoardSubjects = [
    SubjectTemplate(catalogSubjectId: 'Mathematics', name: 'Mathematics'),
    SubjectTemplate(catalogSubjectId: 'Science', name: 'Science'),
    SubjectTemplate(catalogSubjectId: 'English', name: 'English'),
    SubjectTemplate(catalogSubjectId: 'Tamil', name: 'Tamil'),
    SubjectTemplate(catalogSubjectId: 'Social Science', name: 'Social Science'),
    SubjectTemplate(catalogSubjectId: 'Computer Science', name: 'Computer Science'),
  ];

  static List<int> cbseGrades = List.generate(12, (i) => i + 1);
  static List<int> stateBoardGrades = List.generate(10, (i) => i + 1);

  static const cbseExamTypes = [
    ExamTypeTemplate(
      name: 'Quarterly Exam',
      subjectName: 'Mathematics',
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
      subjectName: 'Mathematics',
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
  ];

  static const stateBoardExamTypes = [
    ExamTypeTemplate(
      name: 'Quarterly Exam',
      subjectName: 'Mathematics',
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
      ],
    ),
    ExamTypeTemplate(
      name: 'Annual Exam',
      subjectName: 'Mathematics',
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
      ],
    ),
  ];

  static List<SubjectTemplate> getSubjects(SchoolType type) {
    return type == SchoolType.cbse ? cbseSubjects : stateBoardSubjects;
  }

  static List<int> getGrades(SchoolType type) {
    return type == SchoolType.cbse ? cbseGrades : stateBoardGrades;
  }

  static List<ExamTypeTemplate> getExamTypes(SchoolType type) {
    return type == SchoolType.cbse ? cbseExamTypes : stateBoardExamTypes;
  }

  static String getDisplayName(SchoolType type) {
    return type == SchoolType.cbse ? 'CBSE School' : 'State Board School';
  }

  static String getDescription(SchoolType type) {
    if (type == SchoolType.cbse) {
      return '${cbseSubjects.length} subjects, ${cbseGrades.length} grades, ${cbseExamTypes.length} exam types';
    } else {
      return '${stateBoardSubjects.length} subjects, ${stateBoardGrades.length} grades, ${stateBoardExamTypes.length} exam types';
    }
  }
}