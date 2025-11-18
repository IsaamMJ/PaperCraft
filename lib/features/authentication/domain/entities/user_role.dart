enum UserRole {
  admin,
  director,
  teacher,
  office_staff,
  primary_reviewer,
  secondary_reviewer,
  student,
  user,
  blocked;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'director':
        return UserRole.director;
      case 'teacher':
        return UserRole.teacher;
      case 'office_staff':
        return UserRole.office_staff;
      case 'primary_reviewer':
        return UserRole.primary_reviewer;
      case 'secondary_reviewer':
        return UserRole.secondary_reviewer;
      case 'student':
        return UserRole.student;
      case 'user':
        return UserRole.user;
      case 'blocked':
        return UserRole.blocked;
      default:
        return UserRole.blocked;
    }
  }

  String get value {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.director:
        return 'director';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.office_staff:
        return 'office_staff';
      case UserRole.primary_reviewer:
        return 'primary_reviewer';
      case UserRole.secondary_reviewer:
        return 'secondary_reviewer';
      case UserRole.student:
        return 'student';
      case UserRole.user:
        return 'user';
      case UserRole.blocked:
        return 'blocked';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.director:
        return 'Director';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.office_staff:
        return 'Office Staff';
      case UserRole.primary_reviewer:
        return 'Primary Reviewer';
      case UserRole.secondary_reviewer:
        return 'Secondary Reviewer';
      case UserRole.student:
        return 'Student';
      case UserRole.user:
        return 'User';
      case UserRole.blocked:
        return 'Blocked';
    }
  }
}