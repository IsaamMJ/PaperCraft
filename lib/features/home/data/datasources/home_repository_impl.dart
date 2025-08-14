import '../../domain/entities/home_entity.dart';
import '../../domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  @override
  Future<HomeEntity> getHomeMessage() async {
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate network
    return const HomeEntity(message: "Welcome to Home Screen from Repository");
  }
}
