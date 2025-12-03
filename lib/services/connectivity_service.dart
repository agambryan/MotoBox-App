import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service untuk mengelola network connectivity
/// Menggunakan connectivity_plus untuk monitor koneksi internet
class ConnectivityService {
  static ConnectivityService? _instance;
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final _connectivityController = StreamController<ConnectivityStatus>.broadcast();

  bool _isOnline = true;
  ConnectivityStatus _currentStatus = ConnectivityStatus.online;

  // Private constructor
  ConnectivityService._();

  // Singleton instance
  static ConnectivityService get instance {
    _instance ??= ConnectivityService._();
    return _instance!;
  }

  /// Initialize connectivity service
  Future<void> initialize() async {
    try {
      // Check initial connectivity
      final result = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(result);

      // Listen to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _updateConnectivityStatus,
        onError: (error) {
          debugPrint('Connectivity error: $error');
        },
      );

      debugPrint('ConnectivityService initialized');
    } catch (e) {
      debugPrint('Error initializing connectivity service: $e');
    }
  }

  /// Update connectivity status
  void _updateConnectivityStatus(List<ConnectivityResult> results) {
    final isConnected = results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn);

    _isOnline = isConnected;

    if (isConnected) {
      _currentStatus = ConnectivityStatus.online;
    } else {
      _currentStatus = ConnectivityStatus.offline;
    }

    _connectivityController.add(_currentStatus);
    debugPrint('Connectivity status: $_currentStatus (isOnline: $_isOnline)');
  }

  /// Get current connectivity status
  ConnectivityStatus get currentStatus => _currentStatus;

  /// Check if device is online
  bool get isOnline => _isOnline;

  /// Check if device is offline
  bool get isOffline => !_isOnline;

  /// Stream of connectivity status changes
  Stream<ConnectivityStatus> get onStatusChanged =>
      _connectivityController.stream;

  /// Check connectivity and return result
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(result);
      return _isOnline;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
}

/// Connectivity status enum
enum ConnectivityStatus {
  online,
  offline,
}
