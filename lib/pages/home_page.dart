import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/motor.dart';
import '../theme.dart';
import '../models/component.dart';
import '../database/database_helper.dart';
import '../widgets/motor_photo_album.dart';
import '../widgets/timezone_clock_panel.dart';
import '../services/location_service.dart';
import '../services/app_notification_service.dart';
import '../services/fuel_efficiency_service.dart';
import 'component_management_page.dart';
import 'motor_setup_page.dart';
import 'vehicle_settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LocationService _locationService = LocationService.instance;
  Motor? _currentMotor;
  List<Component> _components = [];
  int _dailyKm = 0;

  late Future<void> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<void> _loadData() async {
    try {
      final motors = await _dbHelper.getMotors();

      if (motors.isEmpty) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MotorSetupPage()),
          );
        }
        return;
      }

      _currentMotor = Motor.fromMap(motors.first);

      await _loadComponents();

      if (_currentMotor != null) {
        _updateComponentsWithoutSetState(_currentMotor!.odometer);
      }

      if (_currentMotor != null) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;

          AppNotificationService.instance.updateFromApp(
            motor: _currentMotor!,
            components: _components,
          );

          if (_currentMotor!.autoIncrementEnabled) {
            _checkAutoIncrement();
          }

          if (_currentMotor!.locationTrackingEnabled) {
            _startLocationTracking();
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      rethrow;
    }
  }

  Future<void> _initializeData() async {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  void _updateComponentsWithoutSetState(int currentOdometer) {
    _components = _components.map((component) {
      final currentKm = currentOdometer - component.lastReplacementKm;
      final remainingKm = component.lifespanKm - currentKm;
      final daysLeft = component.lastReplacementDate != null
          ? component.lastReplacementDate!
                .add(Duration(days: component.lifespanDays))
                .difference(DateTime.now())
                .inDays
          : component.lifespanDays;

      return Component(
        id: component.id,
        nama: component.nama,
        lifespanKm: component.lifespanKm,
        lifespanDays: component.lifespanDays,
        kmLeft: remainingKm,
        daysLeft: daysLeft,
        lastReplacementKm: component.lastReplacementKm,
        lastReplacementDate: component.lastReplacementDate,
        icon: component.icon,
        keterangan: component.keterangan,
        isActive: component.isActive,
      );
    }).toList();
  }

  Future<void> _loadComponents() async {
    if (_currentMotor == null) return;
    final componentsData = await _dbHelper.getActiveComponents(
      _currentMotor!.id,
    );
    final defaultComponents = [
      Component(
        id: 'ban',
        nama: 'Ban',
        lifespanKm: 25000,
        lifespanDays: 730,
        kmLeft: 25000,
        daysLeft: 730,
        lastReplacementKm: 0,
        lastReplacementDate: null,
        icon: Icons.adjust,
        keterangan: 'Ban kendaraan',
        isActive: true,
      ),
      Component(
        id: 'oli_mesin',
        nama: 'Oli Mesin',
        lifespanKm: 2000,
        lifespanDays: 90,
        kmLeft: 2000,
        daysLeft: 90,
        lastReplacementKm: 0,
        lastReplacementDate: null,
        icon: Icons.opacity,
        keterangan: 'Oli mesin kendaraan',
        isActive: true,
      ),
      Component(
        id: 'kampas_rem',
        nama: 'Kampas Rem',
        lifespanKm: 20000,
        lifespanDays: 365,
        kmLeft: 20000,
        daysLeft: 365,
        lastReplacementKm: 0,
        lastReplacementDate: null,
        icon: Icons.do_not_step,
        keterangan: 'Kampas rem kendaraan',
        isActive: true,
      ),
      Component(
        id: 'oli_gardan',
        nama: 'Oli Gardan',
        lifespanKm: 20000,
        lifespanDays: 365,
        kmLeft: 20000,
        daysLeft: 365,
        lastReplacementKm: 0,
        lastReplacementDate: null,
        icon: Icons.engineering,
        keterangan: 'Oli gardan kendaraan',
        isActive: true,
      ),
    ];

    if (componentsData.isEmpty) {
      _components = defaultComponents;
    } else {
      _components = componentsData.map((data) {
        try {
          final defaultComp = defaultComponents.firstWhere(
            (c) => c.id == data['id'],
            orElse: () => defaultComponents.first,
          );
          return Component.fromMap(data, defaultComp.icon);
        } catch (e) {
          debugPrint('Error mapping component: $e');
          return defaultComponents.first;
        }
      }).toList();
    }
  }

  Future<void> _checkAutoIncrement() async {
    if (!_currentMotor!.autoIncrementEnabled || _currentMotor!.dailyKm <= 0) {
      return;
    }

    // Jika belum ada tanggal aktivasi, set hari ini (untuk kompatibilitas data lama)
    if (_currentMotor!.autoIncrementEnabledDate == null) {
      await _dbHelper.updateMotor(
        _currentMotor!
            .copyWith(
              autoIncrementEnabledDate: DateTime.now().toIso8601String(),
            )
            .toMap(),
      );
      final motors = await _dbHelper.getMotors();
      if (motors.isNotEmpty && mounted) {
        _currentMotor = Motor.fromMap(motors.first);
      }
      return;
    }

    final today = DateTime.now();
    final enabledDate = DateTime.parse(
      _currentMotor!.autoIncrementEnabledDate!,
    );

    // Hitung hari yang sudah berlalu sejak aktivasi (paling sedikit 1 hari)
    final daysSinceEnabled = today.difference(enabledDate).inDays;

    // Hanya tambahkan jika sudah lebih dari 1 hari sejak aktivasi
    if (daysSinceEnabled >= 1) {
      // Tambahkan KM untuk setiap hari yang sudah berlalu
      final totalKmToAdd = daysSinceEnabled * _currentMotor!.dailyKm;

      // Update tanggal aktivasi menjadi hari ini untuk reset counter
      final updatedMotor = _currentMotor!.copyWith(
        autoIncrementEnabledDate: today.toIso8601String(),
      );

      await _adjustOdometer(totalKmToAdd, source: 'auto_increment');

      await _dbHelper.updateMotor(updatedMotor.toMap());

      final motors = await _dbHelper.getMotors();
      if (motors.isNotEmpty && mounted) {
        _currentMotor = Motor.fromMap(motors.first);
      }
    }
  }

  void _startLocationTracking() async {
    try {
      // Cek dan request permission
      var granted = await _locationService.isPermissionGranted();

      if (!granted) {
        // Request permission
        granted = await _locationService.requestPermission();
      }

      if (!granted) {
        debugPrint('Location permission not granted');
        if (mounted && _currentMotor != null) {
          // Disable location tracking jika permission tidak diberikan
          final updatedMotor = _currentMotor!.copyWith(
            locationTrackingEnabled: false,
          );
          await _dbHelper.updateMotor(updatedMotor.toMap());
          setState(() {
            _currentMotor = updatedMotor;
          });
        }
        return;
      }

      // Get initial position
      final initialPosition = await _locationService.getCurrentPosition();
      if (initialPosition == null) {
        debugPrint('Could not get initial position');
        return;
      }

      double lastLat = initialPosition.latitude;
      double lastLon = initialPosition.longitude;
      debugPrint('GPS Tracking started at: $lastLat, $lastLon');

      // Start listening to position changes
      _locationService.getPositionStream().listen(
        (position) async {
          if (!mounted || _currentMotor == null) return;

          // Hitung jarak dari posisi terakhir (dalam km)
          final distance = _locationService.calculateDistance(
            lastLat,
            lastLon,
            position.latitude,
            position.longitude,
          );

          // Update hanya jika jarak signifikan (min 0.01 km = 10 meter)
          if (distance >= 0.01) {
            debugPrint('GPS: Moved ${distance.toStringAsFixed(3)} km');

            // Convert km to meter untuk odometer (odometer dalam km, tapi kita tambah sebagai meter)
            final distanceInMeters = (distance * 1000).round();

            // Update odometer
            await _adjustOdometer(distanceInMeters, source: 'gps');

            // Update last position
            lastLat = position.latitude;
            lastLon = position.longitude;

            debugPrint('Odometer updated: ${_currentMotor!.odometer} km');
          }
        },
        onError: (error) {
          debugPrint('Location stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
    }
  }

  void _updateComponents(int currentOdometer) {
    if (!mounted) return;

    setState(() {
      _components = _components.map((component) {
        final currentKm = currentOdometer - component.lastReplacementKm;
        final remainingKm = component.lifespanKm - currentKm;
        final daysLeft = component.lastReplacementDate != null
            ? component.lastReplacementDate!
                  .add(Duration(days: component.lifespanDays))
                  .difference(DateTime.now())
                  .inDays
            : component.lifespanDays;

        return Component(
          id: component.id,
          nama: component.nama,
          lifespanKm: component.lifespanKm,
          lifespanDays: component.lifespanDays,
          kmLeft: remainingKm,
          daysLeft: daysLeft,
          lastReplacementKm: component.lastReplacementKm,
          lastReplacementDate: component.lastReplacementDate,
          icon: component.icon,
          keterangan: component.keterangan,
          isActive: component.isActive,
        );
      }).toList();
    });

    // Notify after components recalculated
    if (_currentMotor != null) {
      AppNotificationService.instance.updateFromApp(
        motor: _currentMotor!,
        components: _components,
      );
    }
  }

  int _countByStatus(ComponentStatus status) {
    if (_currentMotor == null) return 0;
    return _components
        .where(
          (c) => c.isActive && c.getStatus(_currentMotor!.odometer) == status,
        )
        .length;
  }

  Future<void> _adjustOdometer(int change, {String source = 'manual'}) async {
    if (_currentMotor == null) return;

    final newOdometer = (_currentMotor!.odometer + change).clamp(0, 999999);

    // Auto-update fuel level berdasarkan jarak tempuh DULU sebelum update motor
    if (change > 0) {
      await FuelEfficiencyService.instance.autoUpdateFuelLevel(
        motorId: _currentMotor!.id,
        newOdometer: newOdometer,
      );
    } else {
      // Jika tidak ada perubahan positif, hanya update odometer
      await _dbHelper.updateMotor({
        'id': _currentMotor!.id,
        'odometer': newOdometer,
        'odometer_last_update': newOdometer,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    // Reload motor data to get updated values
    final updatedMotor = await _dbHelper.getMotor(_currentMotor!.id);
    if (updatedMotor != null) {
      _currentMotor = Motor.fromMap(updatedMotor);
    }

    // Save to history
    await _dbHelper.insertOdometerHistory({
      'motor_id': _currentMotor!.id,
      'odometer_value': newOdometer,
      'source': source,
      'created_at': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      setState(() {
        _updateComponentsWithoutSetState(newOdometer);
        if (change > 0) {
          _dailyKm += change;
        }
      });

      // Trigger notifications for fuel and component status
      if (_currentMotor != null) {
        AppNotificationService.instance.updateFromApp(
          motor: _currentMotor!,
          components: _components,
        );
      }
    }
  }

  Future<void> _updateFuelLevel(double level) async {
    if (_currentMotor == null || !mounted) return;

    final clampedLevel = level.clamp(0.0, 100.0);

    // Save to database first
    await _dbHelper.updateMotor({
      'id': _currentMotor!.id,
      'fuel_level': clampedLevel,
      'fuel_last_update': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    // Then reload from database
    final updatedMotor = await _dbHelper.getMotor(_currentMotor!.id);
    if (updatedMotor != null && mounted) {
      setState(() {
        _currentMotor = Motor.fromMap(updatedMotor);
      });

      // Notify on fuel update
      AppNotificationService.instance.updateFromApp(
        motor: _currentMotor!,
        components: _components,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _dataFuture,
      builder: (context, snapshot) {
        // Show loading indicator while data is loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: kBg,
            appBar: AppBar(
              title: Text(
                'Dashboard',
                style: TextStyle(
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // Show error if data loading failed
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: kBg,
            appBar: AppBar(
              title: Text(
                'Dashboard',
                style: TextStyle(
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: kDanger),
                  const SizedBox(height: 16),
                  Text(
                    'Kesalahan memuat data: ${snapshot.error}',
                    style: const TextStyle(color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _dataFuture = _loadData();
                      });
                    },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          );
        }

        // Show content when data is loaded
        if (_currentMotor == null) {
          return Scaffold(
            backgroundColor: kBg,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            title: Text(
              'Dashboard',
              style: TextStyle(
                color: kAccent,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(Icons.settings, color: kAccent),
                onPressed: () async {
                  if (_currentMotor == null) return;
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          VehicleSettingsPage(motor: _currentMotor!),
                    ),
                  );
                  if (result != null && mounted) {
                    await _initializeData();
                  }
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildMotorPhotoSection(),
                const SizedBox(height: 16),
                const TimezoneClockPanel(),
                const SizedBox(height: 16),
                _buildStatusIndicators(),
                const SizedBox(height: 16),
                _buildFuelGauge(),
                const SizedBox(height: 16),
                _buildOdometerSection(),
                const SizedBox(height: 24),
                _buildComponentSection(),
                const SizedBox(
                  height: 86,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMotorPhotoSection() {
    if (_currentMotor == null) return const SizedBox();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kAccent.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: kAccent, width: 1.2),
      ),
      child: SizedBox(
        height: 160,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: MotorPhotoAlbum(motorId: _currentMotor!.id),
        ),
      ),
    );
  }

  Widget _buildStatusIndicators() {
    final alertCount = _countByStatus(ComponentStatus.alert);
    final warningCount = _countByStatus(ComponentStatus.warning);
    final goodCount = _countByStatus(ComponentStatus.good);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatusBox(
            icon: Icons.error,
            color: kDanger,
            count: alertCount,
            label: 'Bahaya',
          ),
          _buildStatusBox(
            icon: Icons.warning,
            color: kWarning,
            count: warningCount,
            label: 'Perhatian',
          ),
          _buildStatusBox(
            icon: Icons.check_circle,
            color: kSuccess,
            count: goodCount,
            label: 'Aman',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBox({
    required IconData icon,
    required Color color,
    required int count,
    required String label,
  }) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tingkat 1: Icon dan Angka sejajar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Tingkat 2: Label Alert/Warning/Good
          Text(label, style: TextStyle(fontSize: 12, color: kMuted)),
        ],
      ),
    );
  }

  Widget _buildFuelGauge() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kAccent.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: kAccent, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Bensin Motor',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 16),
                ),
                onPressed: () => _showFuelUpdateDialog(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _currentMotor!.fuelLevel / 100,
                      backgroundColor: kCardAlt,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _currentMotor!.fuelLevel < 20
                            ? kDanger
                            : _currentMotor!.fuelLevel < 50
                            ? kWarning
                            : kSuccess,
                      ),
                      minHeight: 24,
                    ),
                    const SizedBox(height: 8),
                    // Persentase di atas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${_currentMotor!.fuelLevel.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFuelUpdateDialog() {
    final controller = TextEditingController(
      text: _currentMotor!.fuelLevel.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Bensin'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Persentase Bensin (0-100)',
            suffixText: '%',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value >= 0 && value <= 100) {
                _updateFuelLevel(value);
                Navigator.pop(context);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildOdometerSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kAccent.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: kAccent, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: kSuccess, size: 20),
              const SizedBox(width: 8),
              Text(
                '$_dailyKm km Hari Ini',
                style: TextStyle(color: kSuccess, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      NumberFormat('#,##0').format(_currentMotor!.odometer),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const Text(
                      'Odometer Anda Saat Ini',
                      style: TextStyle(fontSize: 14, color: kMuted),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // Minus Button
                  Container(
                    decoration: BoxDecoration(
                      color: kDanger,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.remove, color: Colors.white),
                      onPressed: () => _adjustOdometer(-1),
                      tooltip: 'Kurangi Odometer',
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Plus Button
                  Container(
                    decoration: BoxDecoration(
                      color: kSuccess,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () => _adjustOdometer(1),
                      tooltip: 'Tambah Odometer',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComponentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Komponen',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kAccent,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  if (_currentMotor == null) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ComponentManagementPage(
                        motorId: _currentMotor!.id,
                        components: _components,
                      ),
                    ),
                  );
                  // Selalu reload setelah kembali dari component management
                  if (mounted) {
                    await _loadComponents();
                    _updateComponents(_currentMotor!.odometer);
                  }
                },
                icon: Icon(
                  Icons.edit,
                  color: kAccent,
                  size: 16,
                ),
                label: Text(
                  'Edit Komponen',
                  style: TextStyle(color: kAccent),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            final activeComponents = _components
                .where((c) => c.isActive)
                .toList();
            if (index >= activeComponents.length) return const SizedBox();
            return _buildComponentCard(activeComponents[index]);
          },
          itemCount: _components.where((c) => c.isActive).length,
        ),
      ],
    );
  }

  Widget _buildComponentCard(Component component) {
    final status = component.getStatus(_currentMotor!.odometer);
    final percent = component.getPercentRemaining(_currentMotor!.odometer);

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case ComponentStatus.notSet:
        statusColor = kMuted;
        statusIcon = Icons.error;
        break;
      case ComponentStatus.alert:
        statusColor = kDanger;
        statusIcon = Icons.error;
        break;
      case ComponentStatus.warning:
        statusColor = kWarning;
        statusIcon = Icons.warning;
        break;
      case ComponentStatus.good:
        statusColor = kSuccess;
        statusIcon = Icons.check_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kAccent.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: kAccent, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              Row(
                children: [
                  Text(
                    '${component.getRemainingDays()} hari',
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.info_outline,
                    size: 14,
                    color: const Color(0xFF333067).withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: percent / 100,
                      strokeWidth: 8,
                      backgroundColor: kCardAlt,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${percent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(component.icon, size: 32, color: kMuted),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            component.nama,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: kAccent,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            component.getRemainingKm(_currentMotor!.odometer) >= 0
                ? '${NumberFormat('#,##0').format(component.getRemainingKm(_currentMotor!.odometer))} Km tersisa'
                : '-${NumberFormat('#,##0').format(component.getRemainingKm(_currentMotor!.odometer).abs())} Km tersisa',
            style: TextStyle(
              fontSize: 12,
              color: component.getRemainingKm(_currentMotor!.odometer) < 0 ? Colors.red : kMuted,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
