import 'package:flutter/material.dart';
import '../models/component.dart';
import '../database/database_helper.dart';
import '../theme.dart';

class ComponentManagementPage extends StatefulWidget {
  final String motorId;
  final List<Component> components;

  const ComponentManagementPage({
    super.key,
    required this.motorId,
    required this.components,
  });

  @override
  State<ComponentManagementPage> createState() =>
      _ComponentManagementPageState();
}

class _ComponentManagementPageState extends State<ComponentManagementPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Component> _components = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadComponents();
  }

  Future<void> _loadComponents() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    // Load semua components dari database (termasuk yang nonaktif untuk edit)
    final componentsData = await _dbHelper.getComponents(widget.motorId);

    if (!mounted) return;

    // Convert to Component objects with icons
    final defaultComponents = Component.getDefaultComponents();
    _components = componentsData.map((data) {
      try {
        // Extract component type from ID (motorId_componentType)
        final componentId = data['id'].toString();
        final componentType = getComponentTypeFromId(componentId);

        final defaultComp = defaultComponents.firstWhere(
          (c) => c.id == componentType,
          orElse: () => defaultComponents.first,
        );
        return Component.fromMap(data, defaultComp.icon);
      } catch (e) {
        // Error handling
        return defaultComponents.first;
      }
    }).toList();

    // Add any default components that aren't in database yet
    // Auto aktif untuk 4 component utama: ban, oli_mesin, kampas_rem_depan, oli_gardan
    final autoActiveIds = ['ban', 'oli_mesin', 'kampas_rem_depan', 'oli_gardan'];

    for (var defaultComp in defaultComponents) {
      // Cek berdasarkan component type dari default
      final componentType = defaultComp.id;
      final uniqueId = makeComponentId(widget.motorId, componentType);

      // Cek apakah komponen sudah ada di database
      if (!_components.any((c) => c.id == uniqueId)) {
        // Auto aktif untuk 4 component utama, lainnya inactive
        final isAutoActive = autoActiveIds.contains(componentType);

        try {
          // Insert to database dengan component_type
          await _dbHelper.insertComponent({
            'component_type': componentType,
            'motor_id': widget.motorId,
            'nama': defaultComp.nama,
            'lifespanKm': defaultComp.lifespanKm,
            'lifespanDays': defaultComp.lifespanDays,
            'lifespan_source': 'default',
            'lastReplacementKm': 0,
            'lastReplacementDate': null,
            'is_active': isAutoActive ? 1 : 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          if (!mounted) return;

          _components.add(
            Component.fromMap({
              'id': uniqueId,
              'motor_id': widget.motorId,
              'nama': defaultComp.nama,
              'lifespan_km': defaultComp.lifespanKm,
              'lifespan_days': defaultComp.lifespanDays,
              'lifespan_source': 'default',
              'last_replacement_km': 0,
              'last_replacement_date': null,
              'is_active': isAutoActive ? 1 : 0,
            }, defaultComp.icon),
          );
        } catch (e) {
          debugPrint('Error inserting component $componentType: $e');
          // Skip if component already exists
        }
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleComponent(String componentId, bool isActive) async {
    final activeCount = _components.where((c) => c.isActive).length;

    if (isActive && activeCount >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal 6 komponen yang bisa aktif')),
      );
      return;
    }

    await _dbHelper.toggleComponent(widget.motorId, componentId, isActive);
    // Reload components - component yang nonaktif akan hilang dari list
    await _loadComponents();
  }

  Future<void> _showEditComponentDialog(Component component) async {
    final lifespanKmController = TextEditingController(
      text: component.lifespanKm.toString(),
    );
    final lifespanDaysController = TextEditingController(
      text: component.lifespanDays.toString(),
    );
    // KM Terakhir Ganti dihapus dari form sesuai permintaan

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible:
          true, // Bisa ditutup dengan tap di luar atau back button
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Edit ${component.nama}'),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: lifespanKmController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Lifespan (KM)',
                  suffixText: 'km',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lifespanDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Lifespan (Hari)',
                  suffixText: 'hari',
                ),
              ),
              // Removed KM Terakhir Ganti input
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, {
                'lifespanKm': int.tryParse(lifespanKmController.text) ?? component.lifespanKm,
                'lifespanDays': int.tryParse(lifespanDaysController.text) ?? component.lifespanDays,
              });
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _dbHelper.updateComponent({
        'id': component.id,
        'motor_id': widget.motorId,
        'lifespanKm': result['lifespanKm'],
        'lifespanDays': result['lifespanDays'],
        // Removing KM terakhir ganti from update payload
        'lastReplacementDate': component.lastReplacementDate?.toIso8601String(),
        'keterangan': component.keterangan,
        'is_active': component.isActive ? 1 : 0,
      });
      _loadComponents();
    }

    lifespanKmController.dispose();
    lifespanDaysController.dispose();
    // No lastReplacementKmController anymore
  }

  int get _activeCount => _components.where((c) => c.isActive).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Komponen'),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Info banner
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kAccent.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: kAccent.withValues(alpha: 0.7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Maksimal 6 komponen aktif. Aktif: $_activeCount/6',
                          style: TextStyle(color: kAccent.withValues(alpha: 0.7)),
                        ),
                      ),
                    ],
                  ),
                ),
                // Component list - tampilkan SEMUA komponen (aktif dan nonaktif)
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      86,
                    ), // Padding bottom untuk navbar
                    itemCount: _components.length,
                    itemBuilder: (context, index) {
                      final component = _components[index];
                      final isActive = component.isActive;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: kCard,
                        child: ListTile(
                          leading: Icon(
                            component.icon,
                            color: isActive ? kAccent : kMuted,
                            size: 32,
                          ),
                          title: Text(
                            component.nama,
                            style: TextStyle(
                              color: isActive ? kAccent : kMuted,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '${component.lifespanKm} km / ${component.lifespanDays} hari',
                            style: TextStyle(color: kMuted),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  color: isActive ? kAccent : kMuted,
                                ),
                                onPressed: () =>
                                    _showEditComponentDialog(component),
                              ),
                              Switch(
                                value: isActive,
                                onChanged: (value) {
                                  _toggleComponent(component.id, value);
                                },
                                activeThumbColor: kAccent,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
