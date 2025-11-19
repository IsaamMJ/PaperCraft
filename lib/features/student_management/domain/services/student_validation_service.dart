import 'package:papercraft/core/domain/interfaces/ilogger.dart';

/// Service to validate student data
class StudentValidationService {
  final ILogger logger;

  StudentValidationService(this.logger);

  /// Validate roll number format
  String? validateRollNumber(String rollNumber) {
    if (rollNumber.trim().isEmpty) {
      return 'Roll number cannot be empty';
    }

    if (rollNumber.length > 50) {
      return 'Roll number cannot exceed 50 characters';
    }

    return null;
  }

  /// Validate full name
  String? validateFullName(String fullName) {
    if (fullName.trim().isEmpty) {
      return 'Full name cannot be empty';
    }

    if (fullName.length < 2) {
      return 'Full name must be at least 2 characters';
    }

    if (fullName.length > 100) {
      return 'Full name cannot exceed 100 characters';
    }

    return null;
  }

  /// Validate email (if provided)
  String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return null; // Email is optional
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Invalid email format';
    }

    return null;
  }

  /// Validate phone (if provided)
  String? validatePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) {
      return null; // Phone is optional
    }

    // Remove non-numeric characters for validation
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');

    if (cleaned.length < 10) {
      return 'Phone number must have at least 10 digits';
    }

    if (cleaned.length > 15) {
      return 'Phone number cannot exceed 15 digits';
    }

    return null;
  }

  /// Validate a student record completely
  Map<String, String> validateStudent({
    required String rollNumber,
    required String fullName,
    String? email,
    String? phone,
  }) {
    final errors = <String, String>{};

    final rollError = validateRollNumber(rollNumber);
    if (rollError != null) {
      errors['rollNumber'] = rollError;
    }

    final nameError = validateFullName(fullName);
    if (nameError != null) {
      errors['fullName'] = nameError;
    }

    final emailError = validateEmail(email);
    if (emailError != null) {
      errors['email'] = emailError;
    }

    final phoneError = validatePhone(phone);
    if (phoneError != null) {
      errors['phone'] = phoneError;
    }

    return errors;
  }

  /// Validate CSV row data
  List<String> validateCsvRow({
    required Map<String, String> row,
    required int rowNumber,
  }) {
    final errors = <String>[];

    final rollNumber = row['roll_number']?.trim() ?? '';
    final fullName = row['full_name']?.trim() ?? '';

    if (rollNumber.isEmpty) {
      errors.add('Row $rowNumber: Roll number is required');
    } else {
      final rollError = validateRollNumber(rollNumber);
      if (rollError != null) {
        errors.add('Row $rowNumber, Roll Number: $rollError');
      }
    }

    if (fullName.isEmpty) {
      errors.add('Row $rowNumber: Full name is required');
    } else {
      final nameError = validateFullName(fullName);
      if (nameError != null) {
        errors.add('Row $rowNumber, Full Name: $nameError');
      }
    }

    final email = row['email']?.trim();
    if (email != null && email.isNotEmpty) {
      final emailError = validateEmail(email);
      if (emailError != null) {
        errors.add('Row $rowNumber, Email: $emailError');
      }
    }

    final phone = row['phone']?.trim();
    if (phone != null && phone.isNotEmpty) {
      final phoneError = validatePhone(phone);
      if (phoneError != null) {
        errors.add('Row $rowNumber, Phone: $phoneError');
      }
    }

    return errors;
  }
}
