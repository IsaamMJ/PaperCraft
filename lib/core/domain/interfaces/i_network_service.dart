abstract class INetworkService {
  Stream<bool> get connectionStream;
  bool get isConnectedSync;
  Future<bool> isConnected();
  void dispose();
}