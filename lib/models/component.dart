import 'package:flutter/material.dart';

enum ComponentStatus {
  notSet, // Belum diatur - belum pernah diservis
  alert, // Merah - butuh perhatian segera
  warning, // Kuning - perlu diperhatikan
  good, // Hijau - dalam kondisi baik
}

class Component {
  final String id;
  final String nama;
  final int lifespanKm; // Umur dalam km
  final int lifespanDays; // Umur dalam hari
  final int kmLeft; // KM yang tersisa
  final int daysLeft; // Hari yang tersisa
  final int lastReplacementKm; // KM terakhir ganti
  final DateTime? lastReplacementDate; // Tanggal terakhir ganti
  final IconData icon;
  final String? keterangan;
  final bool isActive; // Status aktif/tidak aktif
  final String lifespanSource; // 'default' | 'custom'

  Component({
    required this.id,
    required this.nama,
    required this.lifespanKm,
    required this.lifespanDays,
    this.kmLeft = 0,
    this.daysLeft = 0,
    this.lastReplacementKm = 0,
    this.lastReplacementDate,
    required this.icon,
    this.keterangan,
    this.isActive = false,
    this.lifespanSource = 'default',
  });

  // Hitung status berdasarkan km left dan days left
  ComponentStatus getStatus(int currentOdometer) {
    // Jika belum pernah diservis, return notSet
    if (lastReplacementKm == 0 && lastReplacementDate == null) {
      return ComponentStatus.notSet;
    }

    final currentKm = currentOdometer - lastReplacementKm;
    final remainingKm = lifespanKm - currentKm;
    final remainingPercent = remainingKm / lifespanKm;

    // Calculate remaining days dynamically
    final calculatedDaysLeft = lastReplacementDate != null
        ? lastReplacementDate!
              .add(Duration(days: lifespanDays))
              .difference(DateTime.now())
              .inDays
        : lifespanDays;

    if (remainingKm < 0 || calculatedDaysLeft < 0) {
      return ComponentStatus.alert; // Overdue
    } else if (remainingPercent < 0.2 || calculatedDaysLeft < 30) {
      return ComponentStatus.alert; // Kurang dari 20% atau kurang dari 30 hari
    } else if (remainingPercent < 0.5 || calculatedDaysLeft < 90) {
      return ComponentStatus
          .warning; // Kurang dari 50% atau kurang dari 90 hari
    } else {
      return ComponentStatus.good;
    }
  }

  // Hitung persentase sisa umur
  double getPercentRemaining(int currentOdometer) {
    // Jika belum pernah diservis, return 0
    if (lastReplacementKm == 0 && lastReplacementDate == null) {
      return 0.0;
    }

    final currentKm = currentOdometer - lastReplacementKm;
    final remainingKm = lifespanKm - currentKm;
    final percent = (remainingKm / lifespanKm) * 100;
    return percent.clamp(0.0, 100.0);
  }

  // Hitung km yang tersisa secara dinamis
  int getRemainingKm(int currentOdometer) {
    if (lastReplacementKm == 0 && lastReplacementDate == null) {
      return lifespanKm;
    }
    final currentKm = currentOdometer - lastReplacementKm;
    final remainingKm = lifespanKm - currentKm;
    return remainingKm;
  }

  // Hitung hari yang tersisa secara dinamis
  int getRemainingDays() {
    if (lastReplacementDate == null) {
      return lifespanDays;
    }
    final expiryDate = lastReplacementDate!.add(Duration(days: lifespanDays));
    final daysLeft = expiryDate.difference(DateTime.now()).inDays;
    return daysLeft;
  }

  // Update component setelah diganti
  Component copyWith({
    int? lastReplacementKm,
    DateTime? lastReplacementDate,
    int? currentOdometer,
  }) {
    final newLastReplacementKm = lastReplacementKm ?? this.lastReplacementKm;
    final newLastReplacementDate =
        lastReplacementDate ?? this.lastReplacementDate;
    final odometer = currentOdometer ?? newLastReplacementKm;

    final currentKm = odometer - newLastReplacementKm;
    final remainingKm = lifespanKm - currentKm;
    final daysLeft = newLastReplacementDate != null
        ? newLastReplacementDate
              .add(Duration(days: lifespanDays))
              .difference(DateTime.now())
              .inDays
        : this.daysLeft;

    return Component(
      id: id,
      nama: nama,
      lifespanKm: lifespanKm,
      lifespanDays: lifespanDays,
      kmLeft: remainingKm,
      daysLeft: daysLeft,
      lastReplacementKm: newLastReplacementKm,
      lastReplacementDate: newLastReplacementDate,
      icon: icon,
      keterangan: keterangan,
      isActive: isActive,
      lifespanSource: lifespanSource,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'lifespan_km': lifespanKm,
      'lifespan_days': lifespanDays,
      'lifespan_source': lifespanSource,
      'last_replacement_km': lastReplacementKm,
      'last_replacement_date': lastReplacementDate?.toIso8601String(),
      'keterangan': keterangan,
      'is_active': isActive ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory Component.fromMap(Map<String, dynamic> map, IconData icon) {
    return Component(
      id: map['id']?.toString() ?? '',
      nama: map['nama'] ?? '',
      lifespanKm: map['lifespan_km'] ?? 0,
      lifespanDays: map['lifespan_days'] ?? 0,
      kmLeft: 0, // Will be calculated
      daysLeft: 0, // Will be calculated
      lastReplacementKm: map['last_replacement_km'] ?? 0,
      lastReplacementDate: map['last_replacement_date'] != null
          ? DateTime.parse(map['last_replacement_date'])
          : null,
      icon: icon,
      keterangan: map['keterangan'],
      isActive: (map['is_active'] ?? 0) == 1,
      lifespanSource: (map['lifespan_source'] ?? 'default').toString(),
    );
  }

  // Default components untuk motor
  static List<Component> getDefaultComponents() {
    return [
      Component(id: 'oli_mesin', nama: 'Oli Mesin', lifespanKm: 3000, lifespanDays: 180, icon: Icons.oil_barrel),
      Component(id: 'oli_gardan', nama: 'Oli Gardan', lifespanKm: 5000, lifespanDays: 180, icon: Icons.settings),
      Component(id: 'filter_oli', nama: 'Filter Oli', lifespanKm: 5000, lifespanDays: 180, icon: Icons.filter_alt),
      Component(id: 'busi', nama: 'Busi', lifespanKm: 10000, lifespanDays: 365, icon: Icons.flash_on),
      Component(id: 'filter_angin', nama: 'Filter Angin', lifespanKm: 10000, lifespanDays: 365, icon: Icons.air),
      Component(id: 'filter_udara', nama: 'Filter Udara', lifespanKm: 10000, lifespanDays: 365, icon: Icons.air),
      Component(id: 'kampas_rem_depan', nama: 'Kampas Rem Depan', lifespanKm: 20000, lifespanDays: 730, icon: Icons.disc_full),
      Component(id: 'kampas_rem_belakang', nama: 'Kampas Rem Belakang', lifespanKm: 20000, lifespanDays: 730, icon: Icons.disc_full),
      Component(id: 'v_belt', nama: 'V-Belt', lifespanKm: 15000, lifespanDays: 365, icon: Icons.settings_ethernet),
      Component(id: 'aki', nama: 'Aki', lifespanKm: 20000, lifespanDays: 730, icon: Icons.battery_charging_full),
      Component(id: 'ban', nama: 'Ban', lifespanKm: 25000, lifespanDays: 730, icon: Icons.radio_button_checked),
      Component(id: 'shockbreaker_suspensi', nama: 'Shockbreaker/Suspensi', lifespanKm: 30000, lifespanDays: 1095, icon: Icons.vertical_align_center),
      Component(id: 'cairan_rem', nama: 'Cairan Rem', lifespanKm: 20000, lifespanDays: 730, icon: Icons.opacity),
      Component(id: 'radiator_coolant', nama: 'Radiator Coolant', lifespanKm: 50000, lifespanDays: 1825, icon: Icons.water_drop),
      Component(id: 'filter_bensin', nama: 'Filter Bensin', lifespanKm: 20000, lifespanDays: 730, icon: Icons.local_gas_station),
      Component(id: 'rantai_gir_set', nama: 'Rantai/Gir Set', lifespanKm: 15000, lifespanDays: 365, icon: Icons.link),
      Component(id: 'kampas_kopling', nama: 'Kampas Kopling', lifespanKm: 30000, lifespanDays: 1095, icon: Icons.precision_manufacturing),
    ];
  }
}
