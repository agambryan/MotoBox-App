import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class DatabaseConfig {
  static Future<void> initializeDatabase() async {
    try {
      if (!kIsWeb) {
        if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          // Initialize FFI for desktop
          sqfliteFfiInit();
          // Set global factory
          databaseFactory = databaseFactoryFfi;
        }
      }
    } catch (e) {
      debugPrint('Error initializing database: $e');
      rethrow;
    }
  }
}
