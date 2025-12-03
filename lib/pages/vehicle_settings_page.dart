import 'package:flutter/material.dart';
import '../models/motor.dart';
import '../database/database_helper.dart';
import '../services/location_service.dart';
import '../services/notification.dart';
import '../theme.dart';

class VehicleSettingsPage extends StatefulWidget {
  final Motor motor;

  const VehicleSettingsPage({super.key, required this.motor});

  @override
  State<VehicleSettingsPage> createState() => _VehicleSettingsPageState();
}

class _VehicleSettingsPageState extends State<VehicleSettingsPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final LocationService _locationService = LocationService.instance;
  final NotificationService _notificationService = NotificationService.instance;
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _dailyKmController = TextEditingController();
  final TextEditingController _fuelEfficiencyController = TextEditingController();
  final TextEditingController _tankVolumeController = TextEditingController();

  bool _autoIncrementEnabled = false;
  bool _locationTrackingEnabled = false;
  bool _notificationEnabled = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    // Check notification permission status
    final notificationStatus = await _notificationService.getPermissionStatus();

    // Load motor data from database to get latest values
    final motorData = await _dbHelper.getMotor(widget.motor.id);
    final fuelEfficiency = motorData?['fuel_efficiency'] as double? ?? 0.0;
    final tankVolume = motorData?['fuel_tank_volume_liters'] as double? ?? 0.0;

    setState(() {
      _odometerController.text = widget.motor.odometer.toString();
      _autoIncrementEnabled = widget.motor.autoIncrementEnabled;
      // Only show dailyKm if it's greater than 0
      _dailyKmController.text = widget.motor.dailyKm > 0 ? widget.motor.dailyKm.toString() : '';
      _locationTrackingEnabled = widget.motor.locationTrackingEnabled;
      _notificationEnabled = notificationStatus; // Now returns bool instead of PermissionStatus

      // Load fuel settings
      _fuelEfficiencyController.text = fuelEfficiency > 0 ? fuelEfficiency.toStringAsFixed(1) : '';
      _tankVolumeController.text = tankVolume > 0 ? tankVolume.toStringAsFixed(1) : '';
    });
  }

  Future<void> _saveSettings() async {
    if (_odometerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odometer tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final odometer = int.tryParse(_odometerController.text) ?? 0;
    final dailyKm = int.tryParse(_dailyKmController.text) ?? 0;
    final fuelEfficiency = double.tryParse(_fuelEfficiencyController.text) ?? 0.0;
    final tankVolume = double.tryParse(_tankVolumeController.text) ?? 0.0;

    // Request location permission if location tracking enabled
    if (_locationTrackingEnabled) {
      final granted = await _locationService.requestPermission();
      if (!granted) {
        if (!mounted) return;
        setState(() => _locationTrackingEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Izin lokasi diperlukan untuk location tracking'),
          ),
        );
      }
    }

    // Set tanggal aktivasi auto increment jika baru diaktifkan
    String? autoIncrementEnabledDate = widget.motor.autoIncrementEnabledDate;
    if (_autoIncrementEnabled && !widget.motor.autoIncrementEnabled) {
      // Baru diaktifkan - simpan tanggal hari ini
      autoIncrementEnabledDate = DateTime.now().toIso8601String();
    } else if (!_autoIncrementEnabled) {
      // Dinonaktifkan - hapus tanggal aktivasi
      autoIncrementEnabledDate = null;
    }

    final motorData = widget.motor
        .copyWith(
          odometer: odometer,
          autoIncrementEnabled: _autoIncrementEnabled,
          dailyKm: dailyKm,
          autoIncrementEnabledDate: autoIncrementEnabledDate,
          locationTrackingEnabled: _locationTrackingEnabled,
        )
        .toMap();

    // Add fuel efficiency and tank volume to the update
    motorData['fuel_efficiency'] = fuelEfficiency;
    motorData['fuel_tank_volume_liters'] = tankVolume;

    await _dbHelper.updateMotor(motorData);

    // Save odometer history
    await _dbHelper.insertOdometerHistory({
      'motor_id': widget.motor.id,
      'odometer_value': odometer,
      'source': 'manual',
      'created_at': DateTime.now().toIso8601String(),
    });

    if (!mounted) return;

    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pengaturan berhasil disimpan'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context, motorData);
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _dailyKmController.dispose();
    _fuelEfficiencyController.dispose();
    _tankVolumeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Motor'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        backgroundColor: kAccent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: kBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Auto Odometer Section
            _buildSection(
              icon: Icons.speed,
              iconColor: kAccent,
              title: 'Auto Odometer',
              description:
                  'Lacak kilometer harian secara otomatis',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Odometer Reading
                  _buildCard(
                    icon: Icons.speed,
                    iconColor: Colors.green,
                    title: 'Jarak Tempuh Saat Ini',
                    child: TextField(
                      controller: _odometerController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: kAccent,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Masukkan odometer',
                        hintStyle: TextStyle(color: kMuted),
                        suffixText: 'km',
                        suffixStyle: TextStyle(color: kMuted),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Enable Auto Increment
                  _buildCard(
                    icon: Icons.calendar_today,
                    iconColor: kAccent,
                    title: 'Aktifkan Penambahan Otomatis',
                    description: 'Tambah kilometer secara otomatis setiap hari (Tidak bisa bersamaan dengan GPS)',
                    trailing: Switch(
                      value: _autoIncrementEnabled,
                      onChanged: (value) {
                        setState(() {
                          _autoIncrementEnabled = value;
                          // Jika auto-increment diaktifkan, matikan GPS tracking
                          if (value && _locationTrackingEnabled) {
                            _locationTrackingEnabled = false;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Pelacakan GPS dinonaktifkan karena Penambahan Otomatis aktif',
                                ),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        });
                      },
                    ),
                    child: _autoIncrementEnabled
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TextField(
                              controller: _dailyKmController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: kAccent,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Kilometer Harian',
                                labelStyle: TextStyle(color: kMuted),
                                hintText: 'e.g., 20',
                                hintStyle: TextStyle(color: kMuted),
                                suffixText: 'km/hari',
                                suffixStyle: TextStyle(color: kMuted),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: kCardAlt),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: kAccent),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  // Location Tracking
                  _buildCard(
                    icon: Icons.location_on,
                    iconColor: Colors.orange,
                    title: 'Pelacakan Berbasis Lokasi',
                    description:
                        'Lacak kilometer secara otomatis menggunakan GPS (Tidak bisa bersamaan dengan Penambahan Otomatis)',
                    trailing: Switch(
                      value: _locationTrackingEnabled,
                      onChanged: (value) async {
                        if (value) {
                          // Cek apakah auto-increment aktif
                          if (_autoIncrementEnabled) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Nonaktifkan Penambahan Otomatis terlebih dahulu',
                                ),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 3),
                              ),
                            );
                            return;
                          }

                          final messenger = ScaffoldMessenger.of(context);
                          final granted = await _locationService
                              .requestPermission();
                          if (!mounted) return;
                          setState(() => _locationTrackingEnabled = granted);
                          if (!granted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Izin lokasi diperlukan untuk fitur ini',
                                ),
                              ),
                            );
                          }
                        } else {
                          if (!mounted) return;
                          setState(() => _locationTrackingEnabled = false);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Notification Section
            _buildSection(
              icon: Icons.notifications,
              iconColor: Colors.blue,
              title: 'Notifikasi',
              description: 'Terima pemberitahuan kondisi motor',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCard(
                    icon: Icons.notifications_active,
                    iconColor: Colors.blue,
                    title: 'Notifikasi Peringatan',
                    description:
                        'Dapatkan notifikasi saat bensin hampir habis atau komponen perlu diganti',
                    trailing: Switch(
                      value: _notificationEnabled,
                      onChanged: (value) async {
                        if (value) {
                          // Request permission when enabling
                          final messenger = ScaffoldMessenger.of(context);
                          final granted = await _notificationService.requestPermission();
                          if (!mounted) return;

                          setState(() => _notificationEnabled = granted);

                          if (granted) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Notifikasi diaktifkan'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Izin notifikasi diperlukan'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        } else {
                          // Just disable without revoking permission
                          setState(() => _notificationEnabled = false);
                        }
                      },
                    ),
                  ),
                  if (_notificationEnabled) ...[
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: kMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Notifikasi aktif untuk:',
                                  style: TextStyle(
                                    color: kMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildNotificationInfo(
                            icon: Icons.local_gas_station,
                            text: 'Bensin ≤ 20%',
                          ),
                          _buildNotificationInfo(
                            icon: Icons.warning_amber,
                            text: 'Komponen dalam status bahaya',
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Fuel Settings Section
            _buildSection(
              icon: Icons.local_gas_station,
              iconColor: Colors.green,
              title: 'Pengaturan Bensin',
              description: 'Atur efisiensi dan kapasitas tangki',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCard(
                    icon: Icons.speed,
                    iconColor: Colors.green,
                    title: 'Efisiensi Bensin',
                    description: 'Konsumsi bahan bakar motor (km/L)',
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: _fuelEfficiencyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          color: kAccent,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Efisiensi',
                          labelStyle: TextStyle(color: kMuted),
                          hintText: 'e.g., 45.0',
                          hintStyle: TextStyle(color: kMuted),
                          suffixText: 'km/L',
                          suffixStyle: TextStyle(color: kMuted),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: kCardAlt),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: kAccent),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildCard(
                    icon: Icons.water_drop,
                    iconColor: Colors.blue,
                    title: 'Kapasitas Tangki',
                    description: 'Volume tangki bensin (Liter)',
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: _tankVolumeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(
                          color: kAccent,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Kapasitas Tangki',
                          labelStyle: TextStyle(color: kMuted),
                          hintText: 'e.g., 4.2',
                          hintStyle: TextStyle(color: kMuted),
                          suffixText: 'L',
                          suffixStyle: TextStyle(color: kMuted),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: kCardAlt),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: kAccent),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.check, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Simpan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: kAccent,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(color: kMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? description,
    Widget? trailing,
    Widget? child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: kAccent,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(description, style: TextStyle(color: kMuted, fontSize: 12)),
          ],
          if (child != null) child,
        ],
      ),
    );
  }

  Widget _buildNotificationInfo({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: kMuted),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: kMuted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
