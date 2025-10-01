import 'package:equatable/equatable.dart';

abstract class OnboardingState extends Equatable {
  const OnboardingState();

  @override
  List<Object?> get props => [];
}

class OnboardingInitial extends OnboardingState {}

class OnboardingSeeding extends OnboardingState {
  final double progress;
  final String currentItem;

  const OnboardingSeeding({
    required this.progress,
    required this.currentItem,
  });

  @override
  List<Object> get props => [progress, currentItem];
}

class OnboardingSuccess extends OnboardingState {}

class OnboardingError extends OnboardingState {
  final String message;

  const OnboardingError(this.message);

  @override
  List<Object> get props => [message];
}