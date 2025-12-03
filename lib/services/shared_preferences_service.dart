import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service untuk mengelola SharedPreferences
/// Menyimpan app settings, preferences, dan cache data
class SharedPreferencesService {
  static SharedPreferencesService? _instance;
  static SharedPreferences? _preferences;

  SharedPreferencesService._();

  static Future<SharedPreferencesService> getInstance() async {
    _instance ??= SharedPreferencesService._();
    _preferences ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  static const String _keyLastUserId = 'last_user_id';
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyLanguage = 'language';
  static const String _keyNotificationEnabled = 'notification_enabled';
  static const String _keyLocationEnabled = 'location_enabled';
  static const String _keyLastSyncTime = 'last_sync_time';
  static const String _keyOfflineModeEnabled = 'offline_mode_enabled';
  static const String _keyAutoBackupEnabled = 'auto_backup_enabled';
  static const String _keyLastBackupTime = 'last_backup_time';
  static const String _keyCacheVersion = 'cache_version';

  String? get lastUserId => _preferences?.getString(_keyLastUserId);

  Future<bool> setLastUserId(String userId) async {
    try {
      return await _preferences?.setString(_keyLastUserId, userId) ?? false;
    } catch (e) {
      debugPrint('Error setting last user ID: $e');
      return false;
    }
  }

  Future<bool> clearLastUserId() async {
    try {
      return await _preferences?.remove(_keyLastUserId) ?? false;
    } catch (e) {
      debugPrint('Error clearing last user ID: $e');
      return false;
    }
  }

  bool get isOnboardingCompleted =>
      _preferences?.getBool(_keyOnboardingCompleted) ?? false;

  Future<bool> setOnboardingCompleted(bool completed) async {
    try {
      return await _preferences?.setBool(_keyOnboardingCompleted, completed) ?? false;
    } catch (e) {
      debugPrint('Error setting onboarding completed: $e');
      return false;
    }
  }

  bool get isDarkMode => _preferences?.getBool(_keyDarkMode) ?? false;

  Future<bool> setDarkMode(bool enabled) async {
    try {
      return await _preferences?.setBool(_keyDarkMode, enabled) ?? false;
    } catch (e) {
      debugPrint('Error setting dark mode: $e');
      return false;
    }
  }

  String get language => _preferences?.getString(_keyLanguage) ?? 'id';

  Future<bool> setLanguage(String languageCode) async {
    try {
      return await _preferences?.setString(_keyLanguage, languageCode) ?? false;
    } catch (e) {
      debugPrint('Error setting language: $e');
      return false;
    }
  }

  bool get isNotificationEnabled =>
      _preferences?.getBool(_keyNotificationEnabled) ?? true;

  Future<bool> setNotificationEnabled(bool enabled) async {
    try {
      return await _preferences?.setBool(_keyNotificationEnabled, enabled) ?? false;
    } catch (e) {
      debugPrint('Error setting notification enabled: $e');
      return false;
    }
  }

  bool get isLocationEnabled =>
      _preferences?.getBool(_keyLocationEnabled) ?? false;

  Future<bool> setLocationEnabled(bool enabled) async {
    try {
      return await _preferences?.setBool(_keyLocationEnabled, enabled) ?? false;
    } catch (e) {
      debugPrint('Error setting location enabled: $e');
      return false;
    }
  }

  DateTime? get lastSyncTime {
    final timestamp = _preferences?.getInt(_keyLastSyncTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<bool> setLastSyncTime(DateTime time) async {
    try {
      return await _preferences?.setInt(
            _keyLastSyncTime,
            time.millisecondsSinceEpoch,
          ) ??
          false;
    } catch (e) {
      debugPrint('Error setting last sync time: $e');
      return false;
    }
  }

  bool get isOfflineModeEnabled =>
      _preferences?.getBool(_keyOfflineModeEnabled) ?? false;

  Future<bool> setOfflineModeEnabled(bool enabled) async {
    try {
      return await _preferences?.setBool(_keyOfflineModeEnabled, enabled) ?? false;
    } catch (e) {
      debugPrint('Error setting offline mode: $e');
      return false;
    }
  }

  bool get isAutoBackupEnabled =>
      _preferences?.getBool(_keyAutoBackupEnabled) ?? false;

  Future<bool> setAutoBackupEnabled(bool enabled) async {
    try {
      return await _preferences?.setBool(_keyAutoBackupEnabled, enabled) ?? false;
    } catch (e) {
      debugPrint('Error setting auto backup: $e');
      return false;
    }
  }

  DateTime? get lastBackupTime {
    final timestamp = _preferences?.getInt(_keyLastBackupTime);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<bool> setLastBackupTime(DateTime time) async {
    try {
      return await _preferences?.setInt(
            _keyLastBackupTime,
            time.millisecondsSinceEpoch,
          ) ??
          false;
    } catch (e) {
      debugPrint('Error setting last backup time: $e');
      return false;
    }
  }

  int get cacheVersion => _preferences?.getInt(_keyCacheVersion) ?? 1;

  Future<bool> setCacheVersion(int version) async {
    try {
      return await _preferences?.setInt(_keyCacheVersion, version) ?? false;
    } catch (e) {
      debugPrint('Error setting cache version: $e');
      return false;
    }
  }

  Future<bool> clearCache() async {
    try {
      final futures = <Future<bool>>[];
      futures.add(_preferences?.remove(_keyLastSyncTime) ?? Future.value(false));
      futures.add(_preferences?.remove(_keyLastBackupTime) ?? Future.value(false));

      final results = await Future.wait(futures);
      return results.every((result) => result);
    } catch (e) {
      debugPrint('Error clearing cache: $e');
      return false;
    }
  }

  String _userKey(String userId, String key) => '${userId}_$key';

  String? getUserString(String userId, String key) {
    return _preferences?.getString(_userKey(userId, key));
  }

  Future<bool> setUserString(String userId, String key, String value) async {
    try {
      return await _preferences?.setString(_userKey(userId, key), value) ?? false;
    } catch (e) {
      debugPrint('Error setting user string: $e');
      return false;
    }
  }

  bool? getUserBool(String userId, String key) {
    return _preferences?.getBool(_userKey(userId, key));
  }

  Future<bool> setUserBool(String userId, String key, bool value) async {
    try {
      return await _preferences?.setBool(_userKey(userId, key), value) ?? false;
    } catch (e) {
      debugPrint('Error setting user bool: $e');
      return false;
    }
  }

  Future<bool> clearUserData(String userId) async {
    try {
      final allKeys = _preferences?.getKeys() ?? {};
      final userKeys = allKeys.where((key) => key.startsWith('${userId}_'));

      final futures = <Future<bool>>[];
      for (final key in userKeys) {
        futures.add(_preferences?.remove(key) ?? Future.value(false));
      }

      if (futures.isEmpty) return true;

      final results = await Future.wait(futures);
      return results.every((result) => result);
    } catch (e) {
      debugPrint('Error clearing user data: $e');
      return false;
    }
  }

  Future<bool> clearAll() async {
    try {
      return await _preferences?.clear() ?? false;
    } catch (e) {
      debugPrint('Error clearing all preferences: $e');
      return false;
    }
  }

  Future<void> reload() async {
    try {
      await _preferences?.reload();
    } catch (e) {
      debugPrint('Error reloading preferences: $e');
    }
  }
}
