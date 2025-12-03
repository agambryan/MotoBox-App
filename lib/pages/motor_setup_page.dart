import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../services/motorcycle_api_service.dart';
import '../services/lifespan_service.dart';
import '../services/fuel_efficiency_service.dart';
import '../theme.dart';
import 'navbar.dart';

class MotorSetupPage extends StatefulWidget {
  const MotorSetupPage({super.key});

  @override
  State<MotorSetupPage> createState() => _MotorSetupPageState();
}

class _MotorSetupPageState extends State<MotorSetupPage> {
  final _dbHelper = DatabaseHelper();
  final _apiService = MotorcycleApiService();
  final _formKey = GlobalKey<FormState>();

  // Controllers - Informasi Motor
  final TextEditingController _odometerController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _manualMakeController = TextEditingController();
  final TextEditingController _manualModelController = TextEditingController();

  // Controllers - Data Bensin
  final TextEditingController _fuelLastRefillDateController = TextEditingController();
  final TextEditingController _fuelLastRefillOdometerController = TextEditingController();
  final TextEditingController _fuelTankVolumeController = TextEditingController();
  final TextEditingController _fuelEfficiencyController = TextEditingController();

  // Fuel level
  double _fuelLevel = 0.0;
  DateTime? _fuelLastRefillDate;
  bool _useCustomEfficiency = false; // Toggle untuk efisiensi manual

  // Dropdown values
  String? _selectedMake;
  String? _selectedModel;
  int? _selectedYear;
  List<String> _makes = [];
  List<String> _models = [];
  List<int> _years = [];

  // Manual input
  bool _useManualMake = false;
  bool _useManualModel = false;

  // Loading states
  bool _isLoadingMakes = false;
  bool _isLoadingModels = false;
  bool _isLoadingYears = false;
  bool _isSaving = false;

  // Category selection
  String? _selectedCategory; // User harus pilih sendiri
  static const Map<String, String> _categoryLabels = {
    'matic': 'Matic',
    'bebek': 'Bebek / Cub',
    'sport': 'Sport',
  };

  @override
  void initState() {
    super.initState();
    _loadMakes();
  }

  Future<void> _loadMakes() async {
    setState(() => _isLoadingMakes = true);
    try {
      final makes = await _apiService.getMakes();
      if (mounted) {
        setState(() {
          _makes = makes;
          _isLoadingMakes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMakes = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Terjadi masalah koneksi. Periksa internet Anda dan coba lagi.',
            ),
            backgroundColor: kDanger,
          ),
        );
      }
    }
  }

  Future<void> _loadModels(String make) async {
    setState(() {
      _isLoadingModels = true;
      _selectedModel = null;
      _models = [];
      _selectedYear = null;
      _years = [];
    });

    try {
      final models = await _apiService.getModels(make);
      if (mounted) {
        setState(() {
          _models = models;
          _isLoadingModels = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingModels = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Terjadi masalah koneksi. Periksa internet Anda dan coba lagi.',
            ),
            backgroundColor: kDanger,
          ),
        );
      }
    }
  }

  Future<void> _loadYears(String make, String model) async {
    if (make.isEmpty || model.isEmpty) return;

    setState(() {
      _isLoadingYears = true;
      _selectedYear = null;
    });

    try {
      final years = await _apiService.getYears(make, model);
      if (mounted) {
        setState(() {
          _years = years;
          _isLoadingYears = false;
          // Auto-select the latest year if available
          if (_years.isNotEmpty && _selectedYear == null) {
            _selectedYear = _years.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingYears = false);
        // Fallback to recent years if API fails (newest first)
        final currentYear = DateTime.now().year;
        _years = List.generate(currentYear - 2009, (i) => currentYear - i);
        if (_years.isNotEmpty && _selectedYear == null) {
          _selectedYear = _years.first;
        }
        debugPrint('Error loading years: $e');
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final make = _useManualMake
        ? _manualMakeController.text.trim()
        : _selectedMake;

    final model = _useManualModel
        ? _manualModelController.text.trim()
        : _selectedModel;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan pilih kategori motor'),
          backgroundColor: kDanger,
        ),
      );
      return;
    }

    if (make == null ||
        make.isEmpty ||
        model == null ||
        model.isEmpty ||
        _selectedYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Silakan lengkapi data motor'),
          backgroundColor: kDanger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final nama = _namaController.text.trim().isNotEmpty
          ? _namaController.text.trim()
          : '$make $model';

      final odometer = int.tryParse(_odometerController.text) ?? 0;

      // Parse data bensin - jika kosong default ke odometer saat ini (baru isi bensin)
      final fuelLastRefillOdometer = int.tryParse(_fuelLastRefillOdometerController.text) ?? odometer;

      // Auto-fill tank volume jika kosong berdasarkan kategori
      final fuelEfficiencyService = FuelEfficiencyService.instance;
      final fuelTankVolume = _fuelTankVolumeController.text.trim().isNotEmpty
          ? double.tryParse(_fuelTankVolumeController.text) ?? fuelEfficiencyService.getDefaultTankVolume(_selectedCategory!)
          : fuelEfficiencyService.getDefaultTankVolume(_selectedCategory!);

      // Clamp fuel level to 0-100
      final clampedFuel = _fuelLevel.clamp(0.0, 100.0);

      final motorId = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now();

      // Get fuel efficiency (custom atau default berdasarkan kategori)
      // _selectedCategory sudah divalidasi tidak null di atas
      double fuelEfficiency;
      String efficiencySource;

      if (_useCustomEfficiency && _fuelEfficiencyController.text.trim().isNotEmpty) {
        // User input manual efficiency
        fuelEfficiency = double.tryParse(_fuelEfficiencyController.text) ??
                        fuelEfficiencyService.getDefaultEfficiency(_selectedCategory!);
        efficiencySource = 'manual';
      } else {
        // Default berdasarkan kategori motor
        fuelEfficiency = fuelEfficiencyService.getDefaultEfficiency(_selectedCategory!);
        efficiencySource = 'default';
      }

      // Create motor data dengan semua field (using snake_case for Supabase compatibility)
      final motorData = {
        'id': motorId,
        'nama': nama,
        'merk': make,
        'model': model,
        'category': _selectedCategory,
        'start_odometer': odometer,
        'odometer': odometer,
        'odometer_last_update': odometer,
        'fuel_level': clampedFuel,
        'fuel_last_update': now.toIso8601String(),
        'fuel_last_refill_date': _fuelLastRefillDate?.toIso8601String() ?? now.toIso8601String(),
        'fuel_last_refill_percent': clampedFuel,
        'fuel_last_refill_odometer': fuelLastRefillOdometer,
        'fuel_tank_volume_liters': fuelTankVolume,
        'fuel_efficiency': fuelEfficiency,
        'fuel_efficiency_source': efficiencySource,
        'auto_increment_enabled': 0,
        'daily_km': 0,
        'location_tracking_enabled': 0,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      await _dbHelper.insertMotor(motorData);

      // Apply category defaults from API dataset
      await LifespanService.applyDefaultsForCategory(
        motorId: motorId,
        category: _selectedCategory!,
      );

      // Save odometer history
      await _dbHelper.insertOdometerHistory({
        'motor_id': motorId,
        'odometer_value': odometer,
        'source': 'initial_setup',
        'created_at': now.toIso8601String(),
      });

      if (!mounted) return;

      final navigator = Navigator.of(context);
      await navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const NavBar()),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMakeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedMake,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Merk',
            prefixIcon: const Icon(
              Icons.two_wheeler,
              color: kAccent,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kAccent),
            ),
            fillColor: kCard,
            filled: true,
          ),
          items: _makes.map((make) {
            return DropdownMenuItem(value: make, child: Text(make));
          }).toList(),
          onChanged: _isLoadingMakes
              ? null
              : (value) {
                  setState(() {
                    _selectedMake = value;
                    _selectedModel = null;
                    _models = [];
                    _selectedYear = null;
                    _years = [];
                    _manualModelController.clear();
                  });
                  if (value != null) {
                    _loadModels(value);
                  }
                },
          validator: (value) {
            if (!_useManualMake && (value == null || value.isEmpty)) {
              return 'Pilih merek motor';
            }
            return null;
          },
        ),
        if (_isLoadingMakes)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildManualMakeInput() {
    return TextFormField(
      controller: _manualMakeController,
      decoration: InputDecoration(
        labelText: 'Merk Motor',
        hintText: 'Masukkan merk motor Anda',
        prefixIcon: const Icon(Icons.edit, color: kAccent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kAccent),
        ),
        fillColor: kCard,
        filled: true,
      ),
      validator: (value) {
        if (_useManualMake && (value == null || value.trim().isEmpty)) {
          return 'Masukkan merk motor';
        }
        return null;
      },
      onChanged: (value) {
        setState(() {
          _selectedModel = null;
          _models = [];
          _selectedYear = null;
          _years = [];
        });
      },
    );
  }

  Widget _buildModelDropdowns() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedModel,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Model',
            prefixIcon: const Icon(Icons.two_wheeler, color: kAccent),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kAccent),
            ),
            fillColor: kCard,
            filled: true,
          ),
          items: _models.map((model) {
            return DropdownMenuItem(value: model, child: Text(model));
          }).toList(),
          onChanged: _isLoadingModels || (_selectedMake == null && !_useManualMake)
              ? null
              : (value) {
                  setState(() => _selectedModel = value);
                  if (value != null) {
                    final make = _useManualMake
                        ? _manualMakeController.text.trim()
                        : _selectedMake;
                    if (make != null && make.isNotEmpty) {
                      _loadYears(make, value);
                    }
                  }
                },
          validator: (value) {
            if (!_useManualModel && (value == null || value.isEmpty)) {
              return 'Pilih model motor';
            }
            return null;
          },
        ),
        if (_isLoadingModels)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildManualModelInput() {
    return TextFormField(
      controller: _manualModelController,
      decoration: InputDecoration(
        labelText: 'Model Motor',
        hintText: 'Masukkan model motor Anda',
        prefixIcon: const Icon(Icons.edit, color: kAccent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kAccent),
        ),
        fillColor: kCard,
        filled: true,
      ),
      validator: (value) {
        if (_useManualModel && (value == null || value.trim().isEmpty)) {
          return 'Masukkan model motor';
        }
        return null;
      },
      onChanged: (value) {
        setState(() {
          _selectedYear = null;
          _years = [];
        });
        if (value.trim().isNotEmpty) {
          final make = _useManualMake
              ? _manualMakeController.text.trim()
              : _selectedMake;
          if (make != null && make.isNotEmpty) {
            _loadYears(make, value.trim());
          }
        }
      },
    );
  }

  Widget _buildYearDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          initialValue: _selectedYear,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Tahun Keluaran',
            prefixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kAccent),
            ),
            fillColor: kCard,
            filled: true,
          ),
          items: _years.isEmpty
              ? List.generate(DateTime.now().year - 2009, (i) {
                  final year = DateTime.now().year - i;
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                })
              : _years.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }).toList(),
          onChanged: _isLoadingYears
              ? null
              : (value) {
                  setState(() => _selectedYear = value);
                },
          validator: (value) {
            if (value == null) {
              return 'Pilih tahun keluaran motor';
            }
            return null;
          },
        ),
        if (_isLoadingYears)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }

  // Get fuel color based on level
  Color _getFuelColor(double level) {
    if (level > 50) {
      return kSuccess;
    } else if (level > 25) {
      return kWarning;
    } else {
      return kDanger;
    }
  }

  String _getCategoryLabel(String category) {
    const labels = {
      'matic': 'Matic',
      'bebek': 'Bebek / Cub',
      'sport': 'Sport',
    };
    return labels[category] ?? 'Motor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Setup Motor', 
        style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
        ),
        backgroundColor: kAccent,
        foregroundColor: kCard,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  const Text(
                    'Setup Motor Anda',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lengkapi informasi motor dan data bensin',
                    style: const TextStyle(fontSize: 14, color: kMuted),
                  ),
                  const SizedBox(height: 18),

                  // ========== BAGIAN 1: INFORMASI MOTOR ==========
                  const Text(
                    'Informasi Motor',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kAccent,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Nama Motor (optional)
                  TextFormField(
                    controller: _namaController,
                    decoration: InputDecoration(
                      labelText: 'Nama Motor (Opsional)',
                      hintText: 'Misal: Motor Utama',
                      prefixIcon: const Icon(
                        Icons.label_outline,
                        color: kAccent,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kAccent, width: 2),
                      ),
                      fillColor: kCard,
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Make Selection Toggle
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _useManualMake,
                        onChanged: (value) {
                          setState(() {
                            _useManualMake = value ?? false;
                            _selectedMake = null;
                            _selectedModel = null;
                            _models = [];
                            _selectedYear = null;
                            _years = [];
                            if (!_useManualMake) {
                              _manualMakeController.clear();
                            }
                            _manualModelController.clear();
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Merk tidak ada di list',
                          style: TextStyle(
                            fontSize: 14,
                            color: kMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Make Input Area
                  _useManualMake
                      ? _buildManualMakeInput()
                      : _buildMakeDropdown(),
                  const SizedBox(height: 16),

                  // Model Selection Toggle
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _useManualModel,
                        onChanged: (value) {
                          setState(() {
                            _useManualModel = value ?? false;
                            _selectedModel = null;
                            _selectedYear = null;
                            _years = [];
                            if (!_useManualModel) {
                              _manualModelController.clear();
                            }
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Model tidak ada di list',
                          style: TextStyle(
                            fontSize: 14,
                            color: kMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Model Input Area - Always visible
                  _useManualModel
                      ? _buildManualModelInput()
                      : _buildModelDropdowns(),
                  const SizedBox(height: 16),

                  // Year Dropdown - Always visible
                  _buildYearDropdown(),
                  const SizedBox(height: 16),

                  // Category Dropdown (default suggestion, user can override)
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Kategori Motor',
                      prefixIcon: const Icon(Icons.category, color: kAccent),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kAccent),
                      ),
                      fillColor: kCard,
                      filled: true,
                    ),
                    items: _categoryLabels.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Start Odometer Input
                  TextFormField(
                    controller: _odometerController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Start Odometer / KM Saat Ini',
                      hintText: '0',
                      suffixText: 'km',
                      prefixIcon: const Icon(Icons.speed, color: kAccent),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kAccent),
                      ),
                      fillColor: kCard,
                      filled: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Masukkan kilometer saat ini';
                      }
                      final km = int.tryParse(value);
                      if (km == null || km < 0) {
                        return 'Kilometer tidak valid';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 40),

                  // ========== BAGIAN 2: DATA BENSIN ==========
                  const Text(
                    'Data Bensin',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: kAccent,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tanggal Terakhir Ngisi Bensin
                  TextFormField(
                    controller: _fuelLastRefillDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Tanggal Pengisian Terakhir',
                      hintText: 'Pilih tanggal',
                      suffixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kAccent),
                      ),
                      fillColor: kCard,
                      filled: true,
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _fuelLastRefillDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() {
                          _fuelLastRefillDate = date;
                          _fuelLastRefillDateController.text =
                            DateFormat('d MMMM yyyy', 'id_ID').format(date);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Odometer Saat Isi Bensin Terakhir (Opsional)
                  TextFormField(
                    controller: _fuelLastRefillOdometerController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Odometer Terakhir Isi Bensin (Opsional)',
                      hintText: 'Kosongkan jika baru isi bensin atau lupa',
                      suffixText: 'km',
                      prefixIcon: const Icon(Icons.speed),
                      helperText: 'Jika kosong, dianggap sama dengan odometer sekarang (baru isi bensin)',
                      helperMaxLines: 3,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kAccent),
                      ),
                      fillColor: kCard,
                      filled: true,
                    ),
                    validator: (value) {
                      // Field opsional, boleh kosong
                      if (value == null || value.isEmpty) {
                        return null;
                      }
                      final odometerValue = int.tryParse(value);
                      if (odometerValue == null || odometerValue < 0) {
                        return 'Odometer harus berupa angka positif';
                      }
                      final currentOdometer = int.tryParse(_odometerController.text) ?? 0;
                      if (odometerValue > currentOdometer) {
                        return 'Tidak boleh lebih dari odometer sekarang ($currentOdometer km)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Bensin Sekarang Berapa Persen
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kCard, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: kCard.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.local_gas_station,
                                    color: kWarning,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Level Bensin Sekarang',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Sisa bensin di tangki saat ini',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: kMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${_fuelLevel.round()}%',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _getFuelColor(_fuelLevel),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Linear Gauge
                        Container(
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: kBorder),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              children: [
                                // Background
                                Container(
                                  width: double.infinity,
                                  color: kCardAlt.withValues(alpha: 0.3),
                                ),
                                // Filled portion
                                FractionallySizedBox(
                                  widthFactor: _fuelLevel / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          _getFuelColor(_fuelLevel),
                                          _getFuelColor(
                                            _fuelLevel,
                                          ).withValues(alpha: 0.8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Slider
                        Slider(
                          value: _fuelLevel,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: '${_fuelLevel.round()}%',
                          activeColor: _getFuelColor(_fuelLevel),
                          onChanged: (value) {
                            setState(() {
                              _fuelLevel = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Volume Full Tank
                  TextFormField(
                    controller: _fuelTankVolumeController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Kapasitas Tangki',
                      hintText: 'Contoh: 4.2',
                      suffixText: 'Liter',
                      prefixIcon: const Icon(Icons.water_drop),
                      helperText: 'Kapasitas tangki bensin motor (opsional)',
                      helperMaxLines: 2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: kAccent),
                      ),
                      fillColor: kCard,
                      filled: true,
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final volume = double.tryParse(value);
                        if (volume == null || volume < 0) {
                          return 'Volume tidak valid';
                        }
                        if (volume > 50) {
                          return 'Kapasitas terlalu besar untuk motor';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Toggle untuk custom efficiency
                  Row(
                    children: [
                      Checkbox(
                        value: _useCustomEfficiency,
                        onChanged: (value) {
                          setState(() {
                            _useCustomEfficiency = value ?? false;
                          });
                        },
                        activeColor: kAccent,
                      ),
                      Expanded(
                        child: Text(
                          'Saya tahu motor saya bisa jalan berapa km per liter (opsional)',
                          style: TextStyle(
                            fontSize: 14,
                            color: kMuted,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Input manual fuel efficiency (conditional)
                  if (_useCustomEfficiency) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fuelEfficiencyController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Berapa Km per 1 Liter?',
                        hintText: 'Contoh: 45',
                        suffixText: 'km/L',
                        prefixIcon: const Icon(Icons.eco),
                        helperText: _selectedCategory != null
                            ? 'Biasanya motor ${_getCategoryLabel(_selectedCategory!)} bisa jalan ${FuelEfficiencyService.instance.getDefaultEfficiency(_selectedCategory!).toStringAsFixed(0)} km/liter'
                            : 'Contoh: Motor matic rata-rata 45 km/liter',
                        helperMaxLines: 3,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: kBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: kBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: kAccent),
                        ),
                        fillColor: kCard,
                        filled: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return null; // Opsional
                        }
                        final eff = double.tryParse(value);
                        if (eff == null || eff < 5 || eff > 100) {
                          return 'Harus antara 5-100 km/liter';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: kCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: kCard,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Simpan dan Lanjutkan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _namaController.dispose();
    _manualMakeController.dispose();
    _manualModelController.dispose();
    _fuelLastRefillDateController.dispose();
    _fuelLastRefillOdometerController.dispose();
    _fuelTankVolumeController.dispose();
    _fuelEfficiencyController.dispose();
    super.dispose();
  }
}
