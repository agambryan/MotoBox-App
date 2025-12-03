import 'package:flutter/foundation.dart';
import '../models/motor.dart';
import '../models/component.dart' as app;
import 'notification.dart';

/// Service untuk mengelola notifikasi aplikasi (bensin dan komponen)
/// dengan anti-spam mechanism menggunakan threshold tracking
class AppNotificationService {
  AppNotificationService._();
  static final AppNotificationService instance = AppNotificationService._();

  final Map<String, int> _lastFuelThreshold = {};
  final Map<String, app.ComponentStatus> _lastComponentStatus = {};

  void updateFromApp({
    required Motor motor,
    required List<app.Component> components,
  }) {
    try {
      _checkFuel(motor);
      _checkComponents(motor, components);
    } catch (e) {
      debugPrint('[AppNotificationService] Error: $e');
    }
  }

  /// Check fuel level dan trigger notification jika mencapai threshold
  /// Threshold: 20%, 15%, 10%, 5% (tidak spam setiap km)
  void _checkFuel(Motor motor) {
    final fuelPercent = motor.fuelLevel.clamp(0.0, 100.0);

    final currentThreshold = _getFuelThreshold(fuelPercent);
    final lastThreshold = _lastFuelThreshold[motor.id] ?? 100;

    if (_shouldNotifyFuelDecrease(currentThreshold, lastThreshold)) {
      _sendFuelNotification(motor, fuelPercent);
      _lastFuelThreshold[motor.id] = currentThreshold;

      debugPrint('[AppNotificationService] 🔔 Fuel notification sent: $currentThreshold%');
    } else if (_isFuelRefilled(fuelPercent, lastThreshold)) {
      _clearFuelNotification(motor);
      _lastFuelThreshold[motor.id] = 100;

      debugPrint('[AppNotificationService] ✅ Fuel refilled, threshold reset');
    }
  }

  int _getFuelThreshold(double fuelPercent) {
    if (fuelPercent > 20.0) return 25;
    if (fuelPercent > 15.0) return 20;
    if (fuelPercent > 10.0) return 15;
    if (fuelPercent > 5.0) return 10;
    if (fuelPercent > 0.0) return 5;
    return 0;
  }

  bool _shouldNotifyFuelDecrease(int current, int last) {
    return current < last && current <= 20;
  }

  bool _isFuelRefilled(double fuelPercent, int lastThreshold) {
    return fuelPercent > 20.0 && lastThreshold <= 20;
  }

  void _sendFuelNotification(Motor motor, double fuelPercent) {
    NotificationService.instance.clearNotification(
      'bensin_hampir_habis-${motor.id}',
    );

    NotificationService.instance.show(
      id: 'bensin_hampir_habis-${motor.id}',
      type: NotificationType.peringatan,
      message: 'Bensin motor ${motor.displayName} tinggal ${fuelPercent.toStringAsFixed(0)}%. Segera isi bensin!',
    );
  }

  void _clearFuelNotification(Motor motor) {
    NotificationService.instance.clearNotification(
      'bensin_hampir_habis-${motor.id}',
    );
  }

  /// Check semua komponen dan trigger notification jika alert/warning
  /// Menggunakan status tracking untuk mencegah spam
  void _checkComponents(Motor motor, List<app.Component> components) {
    for (final component in components) {
      if (!component.isActive) continue;

      final currentStatus = component.getStatus(motor.odometer);
      final lastStatus = _lastComponentStatus[component.id];

      if (_shouldNotifyComponent(currentStatus, lastStatus)) {
        _sendComponentNotification(motor, component, currentStatus);
        _lastComponentStatus[component.id] = currentStatus;

        debugPrint('[AppNotificationService] 🔔 Component notification: ${component.nama} - $currentStatus');
      } else if (_isComponentImproved(currentStatus, lastStatus)) {
        _clearComponentNotification(component);
        _lastComponentStatus[component.id] = currentStatus;

        debugPrint('[AppNotificationService] ✅ Component improved: ${component.nama}');
      }
    }
  }

  bool _shouldNotifyComponent(
    app.ComponentStatus current,
    app.ComponentStatus? last,
  ) {
    if (current == app.ComponentStatus.alert) {
      return last != app.ComponentStatus.alert;
    }

    if (current == app.ComponentStatus.warning) {
      return last != app.ComponentStatus.warning &&
             last != app.ComponentStatus.alert;
    }

    return false;
  }

  bool _isComponentImproved(
    app.ComponentStatus current,
    app.ComponentStatus? last,
  ) {
    if (last == null) return false;

    if (current == app.ComponentStatus.good) {
      return last == app.ComponentStatus.alert ||
             last == app.ComponentStatus.warning;
    }

    if (current == app.ComponentStatus.warning) {
      return last == app.ComponentStatus.alert;
    }

    return false;
  }

  void _sendComponentNotification(
    Motor motor,
    app.Component component,
    app.ComponentStatus status,
  ) {
    final notificationId = 'komponen-${component.id}';

    NotificationService.instance.clearNotification(notificationId);

    if (status == app.ComponentStatus.alert) {
      NotificationService.instance.show(
        id: notificationId,
        type: NotificationType.bahaya,
        message: 'Komponen ${component.nama} motor ${motor.displayName} sudah harus diganti! Segera ke bengkel.',
      );
    } else if (status == app.ComponentStatus.warning) {
      NotificationService.instance.show(
        id: notificationId,
        type: NotificationType.peringatan,
        message: 'Komponen ${component.nama} motor ${motor.displayName} segera perlu diganti.',
      );
    }
  }

  void _clearComponentNotification(app.Component component) {
    NotificationService.instance.clearNotification('komponen-${component.id}');
  }

  void resetTracking(String motorId) {
    _lastFuelThreshold.remove(motorId);
    debugPrint('[AppNotificationService] 🔄 Tracking reset for motor: $motorId');
  }

  void resetComponentTracking(String componentId) {
    _lastComponentStatus.remove(componentId);
    debugPrint('[AppNotificationService] 🔄 Component tracking reset: $componentId');
  }

  void clearAllTracking() {
    _lastFuelThreshold.clear();
    _lastComponentStatus.clear();
    debugPrint('[AppNotificationService] 🔄 All tracking cleared');
  }
}
