/// PostgreSQL and Postgrest error codes
/// Reference: https://www.postgresql.org/docs/current/errcodes-appendix.html
class PostgresErrorCodes {
  // Integrity Constraint Violations (23xxx)
  static const String uniqueViolation = '23505';
  static const String foreignKeyViolation = '23503';
  static const String checkViolation = '23514';
  static const String notNullViolation = '23502';

  // Insufficient Privilege (42501)
  static const String insufficientPrivilege = '42501';

  // Syntax/Configuration Errors (42xxx)
  static const String undefinedTable = '42P01';
  static const String undefinedColumn = '42703';

  // PostgREST specific errors
  static const String noRowsReturned = 'PGRST116';
  static const String rlsPolicyViolation = 'PGRST301';
  static const String jwtExpired = 'PGRST301';

  // RLS and security related
  static const String rowLevelSecurityViolation = '42501';
}

/// User-friendly error messages for common database errors
class PostgresErrorMessages {
  static const String uniqueViolation = 'This record already exists.';
  static const String foreignKeyViolation = 'Cannot perform this action due to related data.';
  static const String checkViolation = 'The data provided does not meet validation requirements.';
  static const String notNullViolation = 'Required field is missing.';
  static const String insufficientPrivilege = 'You do not have permission to perform this action.';
  static const String undefinedTable = 'Database configuration error. Please contact support.';
  static const String undefinedColumn = 'Database configuration error. Please contact support.';
  static const String noRowsReturned = 'No data found.';
  static const String rlsPolicyViolation = 'Access denied. You do not have permission to access this resource.';
  static const String unknown = 'An unexpected database error occurred.';
}
