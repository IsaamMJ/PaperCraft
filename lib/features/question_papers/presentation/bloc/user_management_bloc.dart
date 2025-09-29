// features/authentication/presentation/bloc/user_management_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/domain/entities/user_role.dart';
// =============== EVENTS ===============
abstract class UserManagementEvent extends Equatable {
  const UserManagementEvent();

  @override
  List<Object?> get props => [];
}

class LoadTenantUsers extends UserManagementEvent {
  const LoadTenantUsers();
}

class UpdateUserRole extends UserManagementEvent {
  final String userId;
  final UserRole newRole;

  const UpdateUserRole(this.userId, this.newRole);

  @override
  List<Object> get props => [userId, newRole];
}

class ToggleUserStatus extends UserManagementEvent {
  final String userId;
  final bool isActive;

  const ToggleUserStatus(this.userId, this.isActive);

  @override
  List<Object> get props => [userId, isActive];
}

class DeleteUser extends UserManagementEvent {
  final String userId;

  const DeleteUser(this.userId);

  @override
  List<Object> get props => [userId];
}

// =============== STATES ===============
abstract class UserManagementState extends Equatable {
  const UserManagementState();

  @override
  List<Object?> get props => [];
}

class UserManagementInitial extends UserManagementState {}

class UserManagementLoading extends UserManagementState {
  final String? message;

  const UserManagementLoading({this.message});

  @override
  List<Object?> get props => [message];
}

class TenantUsersLoaded extends UserManagementState {
  final List<UserEntity> users;

  const TenantUsersLoaded(this.users);

  @override
  List<Object> get props => [users];
}

class UserRoleUpdated extends UserManagementState {
  final UserEntity user;

  const UserRoleUpdated(this.user);

  @override
  List<Object> get props => [user];
}

class UserStatusToggled extends UserManagementState {
  final UserEntity user;

  const UserStatusToggled(this.user);

  @override
  List<Object> get props => [user];
}

class UserDeleted extends UserManagementState {
  final String userId;

  const UserDeleted(this.userId);

  @override
  List<Object> get props => [userId];
}

class UserManagementError extends UserManagementState {
  final String message;

  const UserManagementError(this.message);

  @override
  List<Object> get props => [message];
}

// =============== BLOC ===============
class UserManagementBloc extends Bloc<UserManagementEvent, UserManagementState> {
  UserManagementBloc() : super(UserManagementInitial()) {
    on<LoadTenantUsers>(_onLoadTenantUsers);
    on<UpdateUserRole>(_onUpdateUserRole);
    on<ToggleUserStatus>(_onToggleUserStatus);
    on<DeleteUser>(_onDeleteUser);
  }

  Future<void> _onLoadTenantUsers(LoadTenantUsers event, Emitter<UserManagementState> emit) async {
    emit(const UserManagementLoading(message: 'Loading users...'));

    // TODO: Implement user loading from repository
    // For now, emit empty list to prevent errors
    emit(const TenantUsersLoaded([]));
  }

  Future<void> _onUpdateUserRole(UpdateUserRole event, Emitter<UserManagementState> emit) async {
    emit(const UserManagementLoading(message: 'Updating user role...'));

    // TODO: Implement user role update
    emit(const UserManagementError('User role update not implemented yet'));
  }

  Future<void> _onToggleUserStatus(ToggleUserStatus event, Emitter<UserManagementState> emit) async {
    emit(const UserManagementLoading(message: 'Updating user status...'));

    // TODO: Implement user status toggle
    emit(const UserManagementError('User status toggle not implemented yet'));
  }

  Future<void> _onDeleteUser(DeleteUser event, Emitter<UserManagementState> emit) async {
    emit(const UserManagementLoading(message: 'Deleting user...'));

    // TODO: Implement user deletion
    emit(const UserManagementError('User deletion not implemented yet'));
  }
}