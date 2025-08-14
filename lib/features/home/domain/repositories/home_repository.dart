import '../entities/home_entity.dart';

abstract class HomeRepository {
  Future<HomeEntity> getHomeMessage();
}
