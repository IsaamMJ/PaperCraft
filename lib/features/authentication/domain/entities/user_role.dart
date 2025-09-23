enum UserRole {
  admin,
  teacher,
  student,
  user,
  blocked;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'teacher':
        return UserRole.teacher;
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
      case UserRole.teacher:
        return 'teacher';
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
        return 'Administrator';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.student:
        return 'Student';
      case UserRole.user:
        return 'User';
      case UserRole.blocked:
        return 'Blocked';
    }
  }
}