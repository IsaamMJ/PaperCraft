import 'package:equatable/equatable.dart';

class HomeEntity extends Equatable {
  final String message;

  const HomeEntity({required this.message});

  @override
  List<Object?> get props => [message];
}
