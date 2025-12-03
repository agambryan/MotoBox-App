import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../database/database_helper.dart';
import '../database/database_config.dart';
import 'location_service.dart';
import 'notification.dart';

class AppInitializer {
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('App already initialized, skipping...');
      return;
    }

    try {
      debugPrint('Starting app initialization...');

      // STEP 1: Initialize database factory for desktop (quick)
      if (!kIsWeb) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          await DatabaseConfig.initializeDatabase().timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              debugPrint('DatabaseConfig init timeout');
            },
          );
        }
      }

      // STEP 2: Initialize locale data and database in parallel
      await Future.wait([
        // Prepare locale data
        initializeDateFormatting('id_ID', null).timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            debugPrint('Locale initialization timeout');
          },
        ).catchError((e) {
          debugPrint('Locale init error: $e');
        }),

        // Warm up SQLite database
        _initializeDatabase(),
      ]);

      // STEP 3: Request notification permission on main thread (blocking)
      await _initializeNotificationService();

      // STEP 4: Handle location permission in background (non-blocking)
      _initializeLocationPermission();

      _initialized = true;
      debugPrint('App initialization completed successfully');
    } catch (e) {
      debugPrint('Error during app initialization: $e');
      // Don't throw, allow app to continue
      _initialized = true; // Mark as initialized even on error
    }
  }

  static Future<void> _initializeDatabase() async {
    try {
      final db = await DatabaseHelper().database.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('Database initialization timeout');
          throw TimeoutException('Database initialization timeout');
        },
      );

      // Verify connection is alive
      await db.rawQuery('PRAGMA user_version').timeout(
        const Duration(seconds: 2),
      );

      debugPrint('Database initialized successfully');
    } catch (e) {
      debugPrint('Database initialization error: $e');
      // Don't throw - let app continue without database
    }
  }

  static void _initializeLocationPermission() {
    Future(() async {
      try {
        final locationService = LocationService.instance;
        var granted = await locationService.isPermissionGranted();
        if (!granted) {
          // Only request if services enabled; avoid hard blocking
          if (await locationService.isLocationServiceEnabled()) {
            await locationService.requestPermission();
          }
        }
      } catch (e) {
        debugPrint('Error initializing location permission: $e');
        // Best effort; do not crash app if location init fails
      }
    });
  }

  static Future<void> _initializeNotificationService() async {
    try {
      await NotificationService.instance.initialize();
      debugPrint('Notification service initialized');

      // Request notification permission at startup
      final granted = await NotificationService.instance.requestPermission();
      if (granted) {
        debugPrint('Notification permission granted');
      } else {
        debugPrint('Notification permission denied or not available');
      }
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
    }
  }
}
