import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

/// Base class for all use cases
/// [P] represents the parameter type passed to the use case
/// [T] represents the return type
abstract class UseCase<T, P> {
  Future<Either<Failure, T>> call(P params);
}

/// No parameters version
abstract class UseCaseNoParams<T> {
  Future<Either<Failure, T>> call();
}
