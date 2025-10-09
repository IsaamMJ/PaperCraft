/// Input validation utilities for production use
///
/// Enforces business rules and prevents invalid data from entering the system
class InputValidators {
  // Paper limits
  static const int MAX_TITLE_LENGTH = 200;
  static const int MIN_TITLE_LENGTH = 3;
  static const int MAX_DESCRIPTION_LENGTH = 1000;

  // Question limits
  static const int MAX_QUESTION_LENGTH = 2000;
  static const int MIN_QUESTION_LENGTH = 3;
  static const int MAX_OPTION_LENGTH = 500;
  static const int MAX_OPTIONS_PER_QUESTION = 10;
  static const int MIN_OPTIONS_FOR_MCQ = 2;

  // Structure limits
  static const int MAX_SECTIONS = 20;
  static const int MAX_QUESTIONS_PER_SECTION = 100;
  static const int MAX_TOTAL_QUESTIONS = 200;
  static const int MAX_SUB_QUESTIONS = 10;

  // Marks limits
  static const int MIN_MARKS = 1;
  static const int MAX_MARKS_PER_QUESTION = 100;
  static const int MAX_TOTAL_MARKS = 500;

  // Paper Title Validation
  static String? validatePaperTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Paper title is required';
    }

    final trimmed = value.trim();

    if (trimmed.length < MIN_TITLE_LENGTH) {
      return 'Title must be at least $MIN_TITLE_LENGTH characters';
    }

    if (trimmed.length > MAX_TITLE_LENGTH) {
      return 'Title cannot exceed $MAX_TITLE_LENGTH characters';
    }

    // Check for invalid characters
    if (trimmed.contains(RegExp(r'[<>]'))) {
      return 'Title contains invalid characters';
    }

    return null;
  }

  // Question Text Validation
  static String? validateQuestionText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Question text is required';
    }

    final trimmed = value.trim();

    if (trimmed.length < MIN_QUESTION_LENGTH) {
      return 'Question must be at least $MIN_QUESTION_LENGTH characters';
    }

    if (trimmed.length > MAX_QUESTION_LENGTH) {
      return 'Question cannot exceed $MAX_QUESTION_LENGTH characters';
    }

    return null;
  }

  // Option Text Validation
  static String? validateOption(String? value, {bool required = true}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Option cannot be empty' : null;
    }

    final trimmed = value.trim();

    if (trimmed.length > MAX_OPTION_LENGTH) {
      return 'Option cannot exceed $MAX_OPTION_LENGTH characters';
    }

    return null;
  }

  // Marks Validation
  static String? validateMarks(int? value) {
    if (value == null || value < MIN_MARKS) {
      return 'Marks must be at least $MIN_MARKS';
    }

    if (value > MAX_MARKS_PER_QUESTION) {
      return 'Marks cannot exceed $MAX_MARKS_PER_QUESTION';
    }

    return null;
  }

  // Total Marks Validation
  static String? validateTotalMarks(int? value) {
    if (value == null || value < MIN_MARKS) {
      return 'Total marks must be at least $MIN_MARKS';
    }

    if (value > MAX_TOTAL_MARKS) {
      return 'Total marks cannot exceed $MAX_TOTAL_MARKS';
    }

    return null;
  }

  // Email Validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // Password Validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  // Section Name Validation
  static String? validateSectionName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Section name is required';
    }

    if (value.length > 100) {
      return 'Section name too long (max 100 characters)';
    }

    return null;
  }

  // Sanitize input (remove potentially harmful characters)
  static String sanitize(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'[<>]'), '') // Remove HTML-like characters
        .replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
  }

  // Check if string contains only valid characters
  static bool hasValidCharacters(String input) {
    // Allow alphanumeric, spaces, and common punctuation
    final pattern = r'^[a-zA-Z0-9\s.,!?;:()\-]+$';
    return RegExp(pattern).hasMatch(input);
  }
}

/// Validation result class for complex validations
class ValidationResult {
  final bool isValid;
  final List<String> errors;

  const ValidationResult({
    required this.isValid,
    required this.errors,
  });

  factory ValidationResult.success() {
    return const ValidationResult(isValid: true, errors: []);
  }

  factory ValidationResult.failure(List<String> errors) {
    return ValidationResult(isValid: false, errors: errors);
  }

  String get firstError => errors.isNotEmpty ? errors.first : '';
}
