import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

/// Service untuk menghitung dan mengelola efisiensi bensin motor
class FuelEfficiencyService {
  FuelEfficiencyService._();
  static final FuelEfficiencyService instance = FuelEfficiencyService._();

  final DatabaseHelper _db = DatabaseHelper();

  static const Map<String, double> defaultEfficiency = {
    'matic': 45.0,    // Motor matic rata-rata 45 km/L
    'bebek': 55.0,    // Motor bebek/cub rata-rata 55 km/L
    'sport': 30.0,    // Motor sport rata-rata 30 km/L
  };

  static const Map<String, double> defaultTankVolume = {
    'matic': 4.2,     // Motor matic rata-rata 4.2 L (Beat, Vario, dll)
    'bebek': 4.0,     // Motor bebek/cub rata-rata 4.0 L (Supra, Revo, dll)
    'sport': 12.0,    // Motor sport rata-rata 12.0 L (CBR, Ninja, dll)
  };

  double getDefaultEfficiency(String category) {
    return defaultEfficiency[category] ?? 40.0;
  }

  double getDefaultTankVolume(String category) {
    return defaultTankVolume[category] ?? 4.2;
  }

  /// Hitung efisiensi aktual berdasarkan riwayat pengisian bensin
  ///
  /// Formula:
  /// - Jarak tempuh = odometer sekarang - odometer isi bensin terakhir
  /// - Bensin terpakai (liter) = (persen awal - persen sekarang) / 100 * volume tangki
  /// - Efisiensi = jarak tempuh / bensin terpakai
  Future<double?> calculateActualEfficiency({
    required int currentOdometer,
    required double currentFuelPercent,
    required int lastRefillOdometer,
    required double lastRefillPercent,
    required double tankVolume,
  }) async {
    try {
      // Validasi input
      if (tankVolume <= 0) {
        debugPrint('Tank volume is zero or negative');
        return null;
      }

      final distanceTraveled = currentOdometer - lastRefillOdometer;

      if (distanceTraveled <= 0) {
        debugPrint('Distance traveled is zero or negative');
        return null;
      }

      final fuelUsedPercent = lastRefillPercent - currentFuelPercent;

      if (fuelUsedPercent <= 0) {
        debugPrint('Fuel used is zero or negative');
        return null;
      }

      final fuelUsedLiters = (fuelUsedPercent / 100.0) * tankVolume;
      final efficiency = distanceTraveled / fuelUsedLiters;

      if (efficiency < 5.0 || efficiency > 100.0) {
        debugPrint('Calculated efficiency out of range: $efficiency km/L');
        return null;
      }

      debugPrint('Calculated efficiency: $efficiency km/L (${distanceTraveled}km / ${fuelUsedLiters.toStringAsFixed(2)}L)');
      return efficiency;
    } catch (e) {
      debugPrint('Error calculating fuel efficiency: $e');
      return null;
    }
  }

  /// Update efisiensi motor berdasarkan perhitungan aktual
  /// Menggunakan weighted average untuk smooth transition
  Future<void> updateMotorEfficiency({
    required String motorId,
    required double newEfficiency,
  }) async {
    try {
      final motor = await _db.getMotor(motorId);
      if (motor == null) return;

      final currentEfficiency = motor['fuel_efficiency'] as double? ?? 0.0;
      final source = motor['fuel_efficiency_source'] as String? ?? 'default';

      double updatedEfficiency;
      String updatedSource;

      if (source == 'default' || currentEfficiency == 0.0) {
        updatedEfficiency = newEfficiency;
        updatedSource = 'calculated';
      } else {
        // Weighted average: 70% nilai lama, 30% nilai baru untuk smooth transition
        updatedEfficiency = (currentEfficiency * 0.7) + (newEfficiency * 0.3);
        updatedSource = 'calculated';
      }

      await _db.updateMotor({
        'id': motorId,
        'fuel_efficiency': updatedEfficiency,
        'fuel_efficiency_source': updatedSource,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Updated motor $motorId efficiency: ${updatedEfficiency.toStringAsFixed(2)} km/L (source: $updatedSource)');
    } catch (e) {
      debugPrint('Error updating motor efficiency: $e');
    }
  }

  /// Hitung pengurangan bensin berdasarkan jarak tempuh dan efisiensi
  ///
  /// Returns: Persentase bensin baru setelah dikurangi
  double calculateFuelAfterDistance({
    required double currentFuelPercent,
    required int distanceTraveled,
    required double efficiency,
    required double tankVolume,
  }) {
    if (efficiency <= 0 || tankVolume <= 0 || distanceTraveled <= 0) {
      return currentFuelPercent;
    }

    final fuelUsedLiters = distanceTraveled / efficiency;
    final fuelUsedPercent = (fuelUsedLiters / tankVolume) * 100.0;
    final newFuelPercent = currentFuelPercent - fuelUsedPercent;

    return newFuelPercent.clamp(0.0, 100.0);
  }

  /// Auto-update bensin motor saat odometer berubah
  Future<void> autoUpdateFuelLevel({
    required String motorId,
    required int newOdometer,
  }) async {
    try {
      final motor = await _db.getMotor(motorId);
      if (motor == null) {
        debugPrint('⚠️ autoUpdateFuelLevel: Motor not found (id: $motorId)');
        return;
      }

      final currentOdometer = motor['odometer'] as int? ?? 0;
      final currentFuel = (motor['fuel_level'] ?? motor['fuelLevel']) as double? ?? 0.0;
      final efficiency = motor['fuel_efficiency'] as double? ?? 0.0;
      final tankVolume = motor['fuel_tank_volume_liters'] as double? ?? 0.0;

      debugPrint('📊 autoUpdateFuelLevel called:');
      debugPrint('   Current odometer: $currentOdometer km');
      debugPrint('   New odometer: $newOdometer km');
      debugPrint('   Current fuel: ${currentFuel.toStringAsFixed(1)}%');
      debugPrint('   Efficiency: ${efficiency.toStringAsFixed(1)} km/L');
      debugPrint('   Tank volume: ${tankVolume.toStringAsFixed(1)} L');

      double newFuelLevel = currentFuel;
      bool fuelUpdated = false;
      final distanceTraveled = newOdometer - currentOdometer;

      if (efficiency > 0 && tankVolume > 0 && distanceTraveled > 0) {
        newFuelLevel = calculateFuelAfterDistance(
          currentFuelPercent: currentFuel,
          distanceTraveled: distanceTraveled,
          efficiency: efficiency,
          tankVolume: tankVolume,
        );
        fuelUpdated = true;
        debugPrint('✅ Auto-updated fuel: ${currentFuel.toStringAsFixed(1)}% → ${newFuelLevel.toStringAsFixed(1)}% (traveled: ${distanceTraveled}km)');
      } else {
        if (efficiency <= 0 || tankVolume <= 0) {
          debugPrint('⚠️ Cannot auto-update fuel: efficiency=$efficiency, tankVolume=$tankVolume');
          debugPrint('   💡 Tip: Setup fuel efficiency dan tank volume di motor setup!');
        } else if (distanceTraveled <= 0) {
          debugPrint('⚠️ Distance traveled is $distanceTraveled km (fuel not updated)');
        }
      }

      await _db.updateMotor({
        'id': motorId,
        'fuel_level': newFuelLevel,
        'fuel_last_update': fuelUpdated ? DateTime.now().toIso8601String() : motor['fuel_last_update'],
        'odometer': newOdometer,
        'odometer_last_update': newOdometer,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Odometer updated: $currentOdometer → $newOdometer km');
    } catch (e) {
      debugPrint('❌ Error auto-updating fuel level: $e');
    }
  }

  /// Set efisiensi manual oleh user (override)
  Future<void> setManualEfficiency({
    required String motorId,
    required double efficiency,
  }) async {
    try {
      await _db.updateMotor({
        'id': motorId,
        'fuel_efficiency': efficiency,
        'fuel_efficiency_source': 'manual',
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('Set manual efficiency for motor $motorId: $efficiency km/L');
    } catch (e) {
      debugPrint('Error setting manual efficiency: $e');
    }
  }
}
