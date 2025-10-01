import 'package:equatable/equatable.dart';
import '../../data/template/school_templates.dart';

abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

class StartSeeding extends OnboardingEvent {
  final SchoolType schoolType;

  const StartSeeding({required this.schoolType});

  @override
  List<Object> get props => [schoolType];
}