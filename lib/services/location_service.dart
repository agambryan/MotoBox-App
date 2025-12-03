import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Location service for handling geolocation features
class LocationService {
  static LocationService? _instance;
  static LocationService get instance {
    _instance ??= LocationService._();
    return _instance!;
  }

  LocationService._();

  Position? _lastPosition;
  DateTime? _lastUpdateTime;

  // Request location permission
  Future<bool> requestPermission() async {
    try {
      // Cek apakah location service enabled dengan timeout
      final servicesEnabled = await isLocationServiceEnabled();
      if (!servicesEnabled) {
        debugPrint('Location services are disabled');
        return false;
      }

      // Request foreground location permission dengan timeout
      var status = await Permission.location.status
          .timeout(const Duration(seconds: 2), onTimeout: () => PermissionStatus.denied);

      if (status.isDenied) {
        // Request permission dengan timeout
        status = await Permission.location.request()
            .timeout(const Duration(seconds: 10), onTimeout: () => PermissionStatus.denied);
      }

      // Jika permanently denied, tidak perlu buka settings di sini
      if (status.isPermanentlyDenied) {
        debugPrint('Location permission permanently denied');
        return false;
      }

      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      return false;
    }
  }

  // Check if location permission is granted
  Future<bool> isPermissionGranted() async {
    try {
      final status = await Permission.location.status
          .timeout(const Duration(seconds: 2), onTimeout: () => PermissionStatus.denied);
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking permission status: $e');
      return false;
    }
  }

  // Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
    } catch (e) {
      debugPrint('Error checking location service: $e');
      return false;
    }
  }

  // Get current position
  Future<Position?> getCurrentPosition() async {
    try {
      final servicesEnabled = await isLocationServiceEnabled();
      if (!servicesEnabled) {
        return null;
      }

      final granted = await isPermissionGranted();
      if (!granted) {
        final permissionGranted = await requestPermission();
        if (!permissionGranted) return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Get current position timeout');
          throw TimeoutException('Location request timeout');
        },
      );

      _lastPosition = position;
      _lastUpdateTime = DateTime.now();
      return position;
    } on TimeoutException {
      debugPrint('Location request timeout');
      return null;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  // Start listening to position changes
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }

  // Calculate distance between two positions in kilometers
  double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
  }

  // Get last known position
  Position? get lastPosition => _lastPosition;
  DateTime? get lastUpdateTime => _lastUpdateTime;
}

