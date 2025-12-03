import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/motor.dart';
import '../models/component.dart';
import '../database/database_helper.dart';
import '../theme.dart';
import 'component_detail_page.dart';

class ComponentPage extends StatefulWidget {
  const ComponentPage({super.key});

  @override
  State<ComponentPage> createState() => _ComponentPageState();
}

class _ComponentPageState extends State<ComponentPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  Motor? _currentMotor;
  List<Component> _components = [];
  ComponentStatus? _selectedFilter;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Defer loading untuk optimasi performance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Load motor - defer heavy operations
      final motors = await _dbHelper.getMotors();
      if (motors.isEmpty || !mounted) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      _currentMotor = Motor.fromMap(motors.first);

      // Load components in background
      Future.microtask(() async {
        if (!mounted) return;

        final componentsData = await _dbHelper.getComponents(_currentMotor!.id);
        final defaultComponents = Component.getDefaultComponents();

        if (!mounted) return;

        _components = componentsData.map((data) {
          try {
            // Extract component type from ID (motorId_componentType)
            final componentId = data['id'].toString();
            final componentType = getComponentTypeFromId(componentId);

            final defaultComp = defaultComponents.firstWhere(
              (c) => c.id == componentType,
              orElse: () => defaultComponents.first,
            );
            final component = Component.fromMap(data, defaultComp.icon);

            // Calculate kmLeft and daysLeft
            final currentKm =
                _currentMotor!.odometer - component.lastReplacementKm;
            final remainingKm = component.lifespanKm - currentKm;

            int daysLeft = 0;
            if (component.lastReplacementDate != null) {
              final nextReplacementDate = component.lastReplacementDate!.add(
                Duration(days: component.lifespanDays),
              );
              daysLeft = nextReplacementDate.difference(DateTime.now()).inDays;
            }

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
          } catch (e) {
            return defaultComponents.first;
          }
        }).toList();

        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Component> get _filteredComponents {
    if (_currentMotor == null) return [];

    // Show ALL components (aktif dan nonaktif) untuk halaman setting
    List<Component> filtered = _components.where((c) {
      return _selectedFilter == null ||
          c.getStatus(_currentMotor!.odometer) == _selectedFilter;
    }).toList();

    // Sort by status: notSet first, then alert, warning, good
    filtered.sort((a, b) {
      final statusA = a.getStatus(_currentMotor!.odometer);
      final statusB = b.getStatus(_currentMotor!.odometer);

      final orderA = statusA == ComponentStatus.notSet
          ? 0
          : statusA == ComponentStatus.alert
          ? 1
          : statusA == ComponentStatus.warning
          ? 2
          : 3;
      final orderB = statusB == ComponentStatus.notSet
          ? 0
          : statusB == ComponentStatus.alert
          ? 1
          : statusB == ComponentStatus.warning
          ? 2
          : 3;

      if (orderA != orderB) return orderA.compareTo(orderB);
      return a.nama.compareTo(b.nama);
    });

    return filtered;
  }

  int _countByStatus(ComponentStatus status) {
    if (_currentMotor == null) return 0;
    return _components
        .where(
          (c) => c.isActive && c.getStatus(_currentMotor!.odometer) == status,
        )
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text(
          'Komponen Motor',
          style: TextStyle(
            color: kAccent,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: kBg,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentMotor == null
          ? const Center(child: Text('Tidak ada data motor'))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final alertCount = _countByStatus(ComponentStatus.alert);
    final warningCount = _countByStatus(ComponentStatus.warning);

    return Column(
      children: [
        // Status Filter Section
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter buttons
              Row(
                children: [
                  Expanded(
                    child: _buildFilterButton(
                      'Semua',
                      null,
                      _selectedFilter == null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterButton(
                      'Belum Diatur',
                      ComponentStatus.notSet,
                      _selectedFilter == ComponentStatus.notSet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildFilterButton(
                      'Bahaya',
                      ComponentStatus.alert,
                      _selectedFilter == ComponentStatus.alert,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterButton(
                      'Perhatian',
                      ComponentStatus.warning,
                      _selectedFilter == ComponentStatus.warning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFilterButton(
                      'Aman',
                      ComponentStatus.good,
                      _selectedFilter == ComponentStatus.good,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Checks needed
              Row(
                children: [
                  Icon(Icons.settings, color: kMuted, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Perlu Dicek: ${alertCount + warningCount} Komponen',
                    style: TextStyle(color: kMuted, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Component List
        Expanded(
          child: _filteredComponents.isEmpty
              ? Center(
                  child: Text(
                    'Tidak ada komponen',
                    style: TextStyle(color: kMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    86,
                  ), // Padding bottom untuk navbar
                  itemCount: _filteredComponents.length,
                  itemBuilder: (context, index) {
                    final component = _filteredComponents[index];
                    final status = component.getStatus(_currentMotor!.odometer);

                    // Show status indicator if status changed from previous
                    bool showStatusIndicator = false;
                    if (_selectedFilter == null) {
                      if (index == 0) {
                        showStatusIndicator = true;
                      } else {
                        final prevComponent = _filteredComponents[index - 1];
                        final prevStatus = prevComponent.getStatus(
                          _currentMotor!.odometer,
                        );
                        if (prevStatus != status) {
                          showStatusIndicator = true;
                        }
                      }
                    }

                    if (showStatusIndicator) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildStatusIndicator(status),
                          ),
                          _buildComponentCard(component, status),
                        ],
                      );
                    }

                    return _buildComponentCard(component, status);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterButton(
    String label,
    ComponentStatus? status,
    bool isSelected,
  ) {
    Color? color;
    if (status == ComponentStatus.notSet) {
      color = Colors.grey;
    } else if (status == ComponentStatus.alert) {
      color = Colors.red;
    } else if (status == ComponentStatus.warning) {
      color = Colors.orange;
    } else if (status == ComponentStatus.good) {
      color = Colors.green;
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? (color ?? kCardAlt) : kCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (color != null && !isSelected) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(ComponentStatus status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case ComponentStatus.notSet:
        color = Colors.grey;
        icon = Icons.help_outline;
        label = 'Belum Diatur';
        break;
      case ComponentStatus.alert:
        color = Colors.red;
        icon = Icons.error;
        label = 'Bahaya';
        break;
      case ComponentStatus.warning:
        color = Colors.orange;
        icon = Icons.warning;
        label = 'Perhatian';
        break;
      case ComponentStatus.good:
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'Aman';
        break;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildComponentCard(Component component, ComponentStatus status) {
    final percentRemaining = component.getPercentRemaining(
      _currentMotor!.odometer,
    );
    final currentKm = _currentMotor!.odometer - component.lastReplacementKm;
    final kmPercent = (currentKm / component.lifespanKm * 100).clamp(
      0.0,
      100.0,
    );

    // Calculate time interval percent
    double timePercent = 0;
    String timeIntervalText = 'Tidak ada data';
    if (component.lastReplacementDate != null && component.lifespanDays > 0) {
      final daysSince = DateTime.now()
          .difference(component.lastReplacementDate!)
          .inDays;
      timePercent = (daysSince / component.lifespanDays * 100).clamp(
        0.0,
        100.0,
      );

      final months = component.lifespanDays ~/ 30;
      timeIntervalText = '$months bulan (${timePercent.toStringAsFixed(0)}%)';
    }

    Color statusColor;
    switch (status) {
      case ComponentStatus.notSet:
        statusColor = Colors.grey;
        break;
      case ComponentStatus.alert:
        statusColor = Colors.red;
        break;
      case ComponentStatus.warning:
        statusColor = Colors.orange;
        break;
      case ComponentStatus.good:
        statusColor = Colors.green;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(component.icon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            component.nama,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${percentRemaining.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Health progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentRemaining / 100,
                        minHeight: 6,
                        backgroundColor: kCardAlt,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Service intervals
          Row(
            children: [
              Expanded(
                child: Text(
                  'Interval Servis (km): ${component.lifespanKm.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} km (${kmPercent.toStringAsFixed(0)}%)',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Interval Waktu: $timeIntervalText',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
            ],
          ),
          if (component.lastReplacementDate != null) ...[
            const SizedBox(height: 8),
            Text(
              'Terakhir Diservis: ${DateFormat('d MMMM yyyy', 'id_ID').format(component.lastReplacementDate!)}',
              style: TextStyle(color: kMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          // Action button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // Jika belum pernah diservis atau status notSet, buka sebagai new update
                  // Jika sudah pernah diservis, buka sebagai edit
                  final isNotSet = status == ComponentStatus.notSet;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ComponentDetailPage(
                        motor: _currentMotor!,
                        component: component,
                        isNewUpdate: isNotSet,
                      ),
                    ),
                  ).then((_) => _loadData());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  foregroundColor: Colors.white,
                ),
                icon: Icon(
                  status == ComponentStatus.notSet ? Icons.add : Icons.edit,
                  size: 18,
                ),
                label: Text(
                  status == ComponentStatus.notSet ? 'Atur Data' : 'Edit',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
