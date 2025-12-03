import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

enum NotificationType { peringatan, bahaya }

/// System notification service using flutter_local_notifications
/// Shows notifications outside the app in system tray
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    debugPrint('[NotificationService] Initializing system notifications...');

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // Combined initialization settings
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _initialized = true;
      debugPrint('[NotificationService] ✅ System notifications initialized');
    } catch (e) {
      debugPrint('[NotificationService] ❌ Failed to initialize: $e');
      _initialized = false;
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationService] Notification tapped: ${response.payload}');
  }

  /// Request notification permission
  Future<bool> requestPermission() async {
    await _ensureInitialized();

    try {
      // Check current permission status
      final currentStatus = await Permission.notification.status;
      debugPrint('[NotificationService] Current permission status: $currentStatus');

      // If already granted, no need to request
      if (currentStatus.isGranted) {
        debugPrint('[NotificationService] ✅ Permission already granted');
        return true;
      }

      // If permanently denied, cannot request again
      if (currentStatus.isPermanentlyDenied) {
        debugPrint('[NotificationService] ⚠️ Permission permanently denied - open app settings');
        return false;
      }

      // Request permission (for denied or not determined status)
      debugPrint('[NotificationService] 🔔 Requesting notification permission...');
      final status = await Permission.notification.request();

      if (status.isGranted) {
        debugPrint('[NotificationService] ✅ Permission granted by user');
        return true;
      } else if (status.isPermanentlyDenied) {
        debugPrint('[NotificationService] ⚠️ Permission permanently denied by user');
        return false;
      } else {
        debugPrint('[NotificationService] ❌ Permission denied by user');
        return false;
      }
    } catch (e) {
      debugPrint('[NotificationService] Permission request error: $e');
      // On platforms that don't support runtime permissions, assume granted
      return true;
    }
  }

  /// Get current permission status
  Future<bool> getPermissionStatus() async {
    try {
      final status = await Permission.notification.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('[NotificationService] Error checking permission: $e');
      // Assume granted on platforms where permission_handler doesn't work
      return true;
    }
  }

  /// Show system notification
  Future<void> show({
    required String id,
    required NotificationType type,
    required String message,
  }) async {
    await _ensureInitialized();

    if (!_initialized) {
      debugPrint('[NotificationService] Cannot show notification: not initialized');
      return;
    }

    // Check permission
    final hasPermission = await getPermissionStatus();
    if (!hasPermission) {
      debugPrint('[NotificationService] Cannot show notification: permission not granted');
      return;
    }

    final title = type == NotificationType.bahaya ? '⚠️ Perhatian' : '🔔 Peringatan';

    // Android notification details
    final androidDetails = AndroidNotificationDetails(
      'motobox_alerts',
      'MotoBox Alerts',
      channelDescription: 'Notifikasi kondisi motor dan komponen',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'MotoBox Alert',
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _plugin.show(
        id.hashCode,
        title,
        message,
        notificationDetails,
        payload: id,
      );

      debugPrint('[NotificationService] ✅ Notification shown: $title - $message');
    } catch (e) {
      debugPrint('[NotificationService] ❌ Failed to show notification: $e');
    }
  }

  /// Clear/cancel a specific notification by ID
  Future<void> clearNotification(String id) async {
    await _ensureInitialized();

    if (!_initialized) {
      debugPrint('[NotificationService] Cannot clear notification: not initialized');
      return;
    }

    try {
      await _plugin.cancel(id.hashCode);
      debugPrint('[NotificationService] 🗑️ Notification cleared: $id');
    } catch (e) {
      debugPrint('[NotificationService] ❌ Failed to clear notification: $e');
    }
  }

  /// Clear all notifications
  Future<void> clearAllNotifications() async {
    await _ensureInitialized();

    if (!_initialized) {
      debugPrint('[NotificationService] Cannot clear notifications: not initialized');
      return;
    }

    try {
      await _plugin.cancelAll();
      debugPrint('[NotificationService] 🗑️ All notifications cleared');
    } catch (e) {
      debugPrint('[NotificationService] ❌ Failed to clear all notifications: $e');
    }
  }

  /// Initialize service
  Future<void> initialize() async {
    await _ensureInitialized();
  }

  /// Check if permission is granted (for UI display)
  bool get hasPermission => _initialized;
}
