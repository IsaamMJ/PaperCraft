import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import '../../domain/interfaces/i_network_service.dart';
import '../../domain/interfaces/i_logger.dart';
import '../config/environment_config.dart';
import '../config/environment.dart';
import '../utils/platform_utils.dart';

class NetworkServiceImpl implements INetworkService {
  final Connectivity _connectivity = Connectivity();
  final ILogger _logger;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();

  bool _isConnected = true;

  NetworkServiceImpl(this._logger) {
    _initializeConnectivity();
  }

  @override
  Stream<bool> get connectionStream => _connectionController.stream;

  @override
  bool get isConnectedSync => _isConnected;

  @override
  Future<bool> isConnected() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();

      if (!connectivityResults.any((result) => result != ConnectivityResult.none)) {
        return false;
      }

      return await _testNetworkConnection();
    } catch (e) {
      _logger.warning('Network connectivity check failed', category: LogCategory.network, context: {'error': e.toString(), 'platform': PlatformUtils.platformName});
      return false;
    }
  }

  Future<bool> _testNetworkConnection() async {
    try {
      // For web platform, skip the HTTP test since CORS will block it
      // Instead, rely on connectivity status only
      if (kIsWeb) {
        _logger.debug('Web platform - skipping HTTP connectivity test due to CORS',
            category: LogCategory.network,
            context: {'platform': 'web'});
        return true; // Assume connected if we have connectivity
      }

      final testUrl = _getNetworkTestUrl();
      final response = await http.head(testUrl).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      _logger.debug('Network test failed',
          category: LogCategory.network,
          context: {
            'error': e.toString(),
            'platform': PlatformUtils.platformName,
            'testUrl': _getNetworkTestUrl().toString()
          });

      // For web, if the test fails due to CORS, assume we're connected
      // if we have basic connectivity
      if (kIsWeb) {
        return true;
      }
      return false;
    }
  }

  Uri _getNetworkTestUrl() {
    switch (EnvironmentConfig.current) {
      case Environment.dev:
        return Uri.parse('https://www.google.com');
      case Environment.staging:
      case Environment.prod:
        if (EnvironmentConfig.supabaseUrl.isNotEmpty) {
          return Uri.parse(EnvironmentConfig.supabaseUrl);
        }
        return Uri.parse('https://www.google.com');
    }
  }

  void _initializeConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      _updateConnectionStatus(hasConnection);
    });

    _connectivity.checkConnectivity().then((results) {
      final hasConnection = results.any((result) => result != ConnectivityResult.none);
      _updateConnectionStatus(hasConnection);
    });
  }

  void _updateConnectionStatus(bool isConnected) {
    if (_isConnected != isConnected) {
      _isConnected = isConnected;
      _connectionController.add(isConnected);
      _logger.info('Network status changed: ${isConnected ? 'Connected' : 'Disconnected'}', category: LogCategory.network, context: {'platform': PlatformUtils.platformName});
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionController.close();
  }
}
