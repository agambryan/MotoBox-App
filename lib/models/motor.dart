class Motor {
  final String id;
  final String nama;
  final String merk;
  final String model;
  final String? category;
  final int startOdometer;
  final String? gambar;
  final int odometer;
  final int odometerLastUpdate;
  final double fuelLevel; // 0-100 percentage
  final DateTime? fuelLastUpdate;
  final DateTime? fuelLastRefillDate;
  final double? fuelLastRefillPercent;
  final int? fuelLastRefillOdometer;
  final double? fuelTankVolumeLiters;
  final String? fuelType; // pertalite, pertamax, etc
  final bool autoIncrementEnabled;
  final int dailyKm; // KM per hari untuk auto increment
  final String? autoIncrementEnabledDate; // Tanggal kapan auto increment diaktifkan
  final bool locationTrackingEnabled;

  Motor({
    required this.id,
    required this.nama,
    required this.merk,
    required this.model,
    this.category,
    this.startOdometer = 0,
    this.gambar,
    this.odometer = 0,
    this.odometerLastUpdate = 0,
    this.fuelLevel = 0,
    this.fuelLastUpdate,
    this.fuelLastRefillDate,
    this.fuelLastRefillPercent,
    this.fuelLastRefillOdometer,
    this.fuelTankVolumeLiters,
    this.fuelType,
    this.autoIncrementEnabled = false,
    this.dailyKm = 0,
    this.autoIncrementEnabledDate,
    this.locationTrackingEnabled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'merk': merk,
      'model': model,
      'category': category,
      'start_odometer': startOdometer,
      'gambar': gambar,
      'odometer': odometer,
      'odometer_last_update': odometerLastUpdate,
      'fuel_level': fuelLevel,
      'fuel_last_update': fuelLastUpdate?.toIso8601String(),
      'fuel_last_refill_date': fuelLastRefillDate?.toIso8601String(),
      'fuel_last_refill_percent': fuelLastRefillPercent,
      'fuel_last_refill_odometer': fuelLastRefillOdometer,
      'fuel_tank_volume_liters': fuelTankVolumeLiters,
      'fuel_type': fuelType,
      'auto_increment_enabled': autoIncrementEnabled ? 1 : 0,
      'daily_km': dailyKm,
      'auto_increment_enabled_date': autoIncrementEnabledDate,
      'location_tracking_enabled': locationTrackingEnabled ? 1 : 0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory Motor.fromMap(Map<String, dynamic> map) {
    // Support both snake_case (new) and camelCase (old) for backward compatibility
    DateTime? fuelLastUpdate;
    final fuelLastUpdateStr = map['fuel_last_update'] ?? map['fuelLastUpdate'];
    if (fuelLastUpdateStr != null && fuelLastUpdateStr.toString().isNotEmpty) {
      try {
        fuelLastUpdate = DateTime.parse(fuelLastUpdateStr.toString());
      } catch (e) {
        fuelLastUpdate = null;
      }
    }

    DateTime? fuelLastRefillDate;
    if (map['fuel_last_refill_date'] != null && map['fuel_last_refill_date'].toString().isNotEmpty) {
      try {
        fuelLastRefillDate = DateTime.parse(map['fuel_last_refill_date'].toString());
      } catch (e) {
        fuelLastRefillDate = null;
      }
    }

    return Motor(
      id: map['id']?.toString() ?? '',
      nama: map['nama']?.toString() ?? '',
      merk: map['merk']?.toString() ?? '',
      model: map['model']?.toString() ?? '',
      category: map['category']?.toString(),
      startOdometer: (map['start_odometer'] is int)
          ? map['start_odometer']
          : ((map['start_odometer'] is num) ? (map['start_odometer'] as num).toInt() : 0),
      gambar: map['gambar']?.toString(),
      odometer: (map['odometer'] is int)
          ? map['odometer']
          : ((map['odometer'] is num) ? (map['odometer'] as num).toInt() : 0),
      odometerLastUpdate: ((map['odometer_last_update'] ?? map['odometerLastUpdate']) is int)
          ? (map['odometer_last_update'] ?? map['odometerLastUpdate'])
          : (((map['odometer_last_update'] ?? map['odometerLastUpdate']) is num)
              ? ((map['odometer_last_update'] ?? map['odometerLastUpdate']) as num).toInt()
              : 0),
      fuelLevel: ((map['fuel_level'] ?? map['fuelLevel']) is double)
          ? (map['fuel_level'] ?? map['fuelLevel'])
          : (((map['fuel_level'] ?? map['fuelLevel']) is num)
              ? ((map['fuel_level'] ?? map['fuelLevel']) as num).toDouble()
              : 0.0),
      fuelLastUpdate: fuelLastUpdate,
      fuelLastRefillDate: fuelLastRefillDate,
      fuelLastRefillPercent: (map['fuel_last_refill_percent'] is double)
          ? map['fuel_last_refill_percent']
          : ((map['fuel_last_refill_percent'] is num) ? (map['fuel_last_refill_percent'] as num).toDouble() : null),
      fuelLastRefillOdometer: (map['fuel_last_refill_odometer'] is int)
          ? map['fuel_last_refill_odometer']
          : ((map['fuel_last_refill_odometer'] is num) ? (map['fuel_last_refill_odometer'] as num).toInt() : null),
      fuelTankVolumeLiters: (map['fuel_tank_volume_liters'] is double)
          ? map['fuel_tank_volume_liters']
          : ((map['fuel_tank_volume_liters'] is num) ? (map['fuel_tank_volume_liters'] as num).toDouble() : null),
      fuelType: map['fuel_type']?.toString(),
      autoIncrementEnabled: ((map['auto_increment_enabled'] ?? map['autoIncrementEnabled']) is int)
          ? ((map['auto_increment_enabled'] ?? map['autoIncrementEnabled']) == 1)
          : (((map['auto_increment_enabled'] ?? map['autoIncrementEnabled']) is bool)
              ? (map['auto_increment_enabled'] ?? map['autoIncrementEnabled'])
              : false),
      dailyKm: ((map['daily_km'] ?? map['dailyKm']) is int)
          ? (map['daily_km'] ?? map['dailyKm'])
          : (((map['daily_km'] ?? map['dailyKm']) is num)
              ? ((map['daily_km'] ?? map['dailyKm']) as num).toInt()
              : 0),
      autoIncrementEnabledDate: (map['auto_increment_enabled_date'] ?? map['autoIncrementEnabledDate'])?.toString(),
      locationTrackingEnabled: ((map['location_tracking_enabled'] ?? map['locationTrackingEnabled']) is int)
          ? ((map['location_tracking_enabled'] ?? map['locationTrackingEnabled']) == 1)
          : (((map['location_tracking_enabled'] ?? map['locationTrackingEnabled']) is bool)
              ? (map['location_tracking_enabled'] ?? map['locationTrackingEnabled'])
              : false),
    );
  }

  Motor copyWith({
    String? id,
    String? nama,
    String? merk,
    String? model,
    String? category,
    int? startOdometer,
    String? gambar,
    int? odometer,
    int? odometerLastUpdate,
    double? fuelLevel,
    DateTime? fuelLastUpdate,
    DateTime? fuelLastRefillDate,
    double? fuelLastRefillPercent,
    int? fuelLastRefillOdometer,
    double? fuelTankVolumeLiters,
    String? fuelType,
    bool? autoIncrementEnabled,
    int? dailyKm,
    String? autoIncrementEnabledDate,
    bool? locationTrackingEnabled,
  }) {
    return Motor(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      merk: merk ?? this.merk,
      model: model ?? this.model,
      category: category ?? this.category,
      startOdometer: startOdometer ?? this.startOdometer,
      gambar: gambar ?? this.gambar,
      odometer: odometer ?? this.odometer,
      odometerLastUpdate: odometerLastUpdate ?? this.odometerLastUpdate,
      fuelLevel: fuelLevel ?? this.fuelLevel,
      fuelLastUpdate: fuelLastUpdate ?? this.fuelLastUpdate,
      fuelLastRefillDate: fuelLastRefillDate ?? this.fuelLastRefillDate,
      fuelLastRefillPercent: fuelLastRefillPercent ?? this.fuelLastRefillPercent,
      fuelLastRefillOdometer: fuelLastRefillOdometer ?? this.fuelLastRefillOdometer,
      fuelTankVolumeLiters: fuelTankVolumeLiters ?? this.fuelTankVolumeLiters,
      fuelType: fuelType ?? this.fuelType,
      autoIncrementEnabled: autoIncrementEnabled ?? this.autoIncrementEnabled,
      dailyKm: dailyKm ?? this.dailyKm,
      autoIncrementEnabledDate: autoIncrementEnabledDate ?? this.autoIncrementEnabledDate,
      locationTrackingEnabled: locationTrackingEnabled ?? this.locationTrackingEnabled,
    );
  }

  String get displayName => '$merk $model';
}

