// features/paper_workflow/presentation/bloc/user_management_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/infrastructure/di/injection_container.dart';
import '../../../authentication/domain/entities/user_entity.dart';
import '../../../authentication/domain/entities/user_role.dart';
import '../../../authentication/domain/repositories/user_repository.dart';
import '../../../authentication/domain/services/user_state_service.dart';

// =============== EVENTS ===============
abstract class UserManagementEvent extends Equatable {
  const UserManagementEvent();

  @override
  List<Object?> get props => [];
}

class LoadUsers extends UserManagementEvent {
  const LoadUsers();
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

class UserManagementLoaded extends UserManagementState {
  final List<UserEntity> users;

  const UserManagementLoaded(this.users);

  @override
  List<Object> get props => [users];
}

class UserManagementError extends UserManagementState {
  final String message;

  const UserManagementError(this.message);

  @override
  List<Object> get props => [message];
}

class UserManagementSuccess extends UserManagementState {
  final String message;

  const UserManagementSuccess(this.message);

  @override
  List<Object> get props => [message];
}

// =============== BLOC ===============
class UserManagementBloc extends Bloc<UserManagementEvent, UserManagementState> {
  final UserRepository _repository;

  UserManagementBloc({UserRepository? repository})
      : _repository = repository ?? sl<UserRepository>(),
        super(UserManagementInitial()) {
    on<LoadUsers>(_onLoadUsers);
    on<UpdateUserRole>(_onUpdateUserRole);
    on<ToggleUserStatus>(_onToggleUserStatus);
  }

  Future<void> _onLoadUsers(LoadUsers event, Emitter<UserManagementState> emit) async {
    emit(const UserManagementLoading(message: 'Loading users...'));

    try {
      final userStateService = sl<UserStateService>();
      final tenantId = userStateService.currentTenantId;

      if (tenantId == null) {
        emit(const UserManagementError('User not authenticated'));
        return;
      }

      final result = await _repository.getTenantUsers(tenantId);

      result.fold(
            (failure) {
          emit(UserManagementError(failure.message));
        },
            (users) {
          emit(UserManagementLoaded(users));
        },
      );
    } catch (e) {
      emit(UserManagementError('Failed to load users: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateUserRole(UpdateUserRole event, Emitter<UserManagementState> emit) async {
    emit(const UserManagementLoading(message: 'Updating user role...'));

    final result = await _repository.updateUserRole(event.userId, event.newRole);

    result.fold(
          (failure) {
        emit(UserManagementError(failure.message));
      },
          (_) {
        emit(const UserManagementSuccess('User role updated successfully'));
        add(const LoadUsers()); // Reload users
      },
    );
  }

  Future<void> _onToggleUserStatus(ToggleUserStatus event, Emitter<UserManagementState> emit) async {
    emit(const UserManagementLoading(message: 'Updating user status...'));

    final result = await _repository.updateUserStatus(event.userId, event.isActive);

    result.fold(
          (failure) => emit(UserManagementError(failure.message)),
          (_) {
        emit(const UserManagementSuccess('User status updated successfully'));
        add(const LoadUsers()); // Reload users
      },
    );
  }
}