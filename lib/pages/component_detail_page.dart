import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/motor.dart';
import '../models/component.dart';
import '../database/database_helper.dart';
import '../services/app_notification_service.dart';
import '../theme.dart';

class ComponentDetailPage extends StatefulWidget {
  final Motor motor;
  final Component component;
  final bool isNewUpdate;

  const ComponentDetailPage({
    super.key,
    required this.motor,
    required this.component,
    this.isNewUpdate = false,
  });

  @override
  State<ComponentDetailPage> createState() => _ComponentDetailPageState();
}

class _ComponentDetailPageState extends State<ComponentDetailPage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final TextEditingController _lifespanKmController = TextEditingController();
  final TextEditingController _lifespanDaysController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime? _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.isNewUpdate) {
      // New update - use current odometer and today's date
      _selectedDate = DateTime.now();
    } else {
      // Edit mode - load existing data
      _lifespanKmController.text = widget.component.lifespanKm.toString();
      _lifespanDaysController.text = (widget.component.lifespanDays ~/ 30)
          .toString();
      _selectedDate = widget.component.lastReplacementDate ?? DateTime.now();
      _notesController.text = widget.component.keterangan ?? '';
    }
  }

  Future<void> _pickDate() async {
    try {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        locale: const Locale('id', 'ID'),
      );
      if (picked != null && mounted) {
        setState(() {
          _selectedDate = picked;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kesalahan memilih tanggal. Silakan coba lagi'),
          ),
        );
      }
      debugPrint('Error picking date: $e');
    }
  }

  Future<void> _saveComponent() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tanggal harus diisi'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final lifespanKm = int.tryParse(_lifespanKmController.text);
      final lifespanDaysInput = int.tryParse(_lifespanDaysController.text);

      // If input is empty or invalid, use existing values
      final finalLifespanKm = lifespanKm ?? widget.component.lifespanKm;
      final finalLifespanDays = lifespanDaysInput != null
          ? lifespanDaysInput * 30
          : widget.component.lifespanDays;

      // For new update, set lastReplacementKm to current odometer
      // For edit, keep existing lastReplacementKm unless explicitly changed
      final lastReplacementKm = widget.isNewUpdate
          ? widget.motor.odometer
          : widget.component.lastReplacementKm;

      final lastReplacementDate = _selectedDate;
      final notes = _notesController.text.trim();

      final componentData = {
        'id': widget.component.id,
        'motor_id': widget.motor.id,
        'nama': widget.component.nama,
        'lifespanKm': finalLifespanKm,
        'lifespanDays': finalLifespanDays,
        'lastReplacementKm': lastReplacementKm,
        'lastReplacementDate': lastReplacementDate?.toIso8601String(),
        'keterangan': notes.isNotEmpty ? notes : null,
        'is_active': 1,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _dbHelper.updateComponent(componentData);

      // Reset notification tracking jika component diganti (isNewUpdate)
      if (widget.isNewUpdate) {
        AppNotificationService.instance.resetComponentTracking(widget.component.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data komponen berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving component: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kesalahan menyimpan data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _lifespanKmController.dispose();
    _lifespanDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text(
          widget.isNewUpdate
              ? 'Update ${widget.component.nama}'
              : 'Edit ${widget.component.nama}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: kAccent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with icon and title
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kAccent, width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        widget.component.icon,
                        color: kAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.component.nama,
                            style: TextStyle(
                              color: kAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.isNewUpdate
                                ? 'Catat pergantian baru'
                                : 'Edit riwayat pergantian',
                            style: TextStyle(
                              color: kMuted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Last serviced date (if editing existing)
              if (!widget.isNewUpdate &&
                  widget.component.lastReplacementDate != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Terakhir Diganti',
                        style: TextStyle(
                          color: kMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: kAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat(
                              'd MMMM yyyy',
                              'id_ID',
                            ).format(widget.component.lastReplacementDate!),
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pada ${NumberFormat('#,##0').format(widget.component.lastReplacementKm)} km',
                        style: TextStyle(
                          color: kMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Input fields - ALWAYS in consistent order: KM first, then Time
              _buildInputField(
                label: 'Masa Pakai Berdasarkan Jarak',
                controller: _lifespanKmController,
                suffix: 'km',
                keyboardType: TextInputType.number,
                hint: widget.component.lifespanKm.toString(),
              ),
              const SizedBox(height: 8),
              Text(
                'Berapa km komponen ini bisa bertahan?',
                style: TextStyle(
                  color: kMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              _buildInputField(
                label: 'Masa Pakai Berdasarkan Waktu',
                controller: _lifespanDaysController,
                suffix: 'bulan',
                keyboardType: TextInputType.number,
                hint: (widget.component.lifespanDays ~/ 30).toString(),
              ),
              const SizedBox(height: 8),
              Text(
                'Berapa bulan komponen ini bisa bertahan?',
                style: TextStyle(
                  color: kMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),

              // Info box explaining the system
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kAccent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kAccent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: kAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Komponen akan dianggap perlu diganti jika SALAH SATU kondisi terpenuhi (jarak ATAU waktu)',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Date picker
              _buildDatePicker(),
              const SizedBox(height: 8),
              Text(
                'Kapan terakhir kali komponen ini diganti? (bukan tanggal hari ini)',
                style: TextStyle(
                  color: kMuted,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),

              _buildNotesSection(),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kCardAlt.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: kBorder),
                ),
                child: Text(
                  'Estimasi umur komponen di atas bersifat umum. Untuk akurasi, cek buku manual atau konsultasi ke bengkel resmi.',
                  style: TextStyle(
                    color: kMuted,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save button
              ElevatedButton(
                onPressed: _isSaving ? null : _saveComponent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccent,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Simpan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String suffix,
    required TextInputType keyboardType,
    String? hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black87, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: kMuted),
        hintText: hint,
        hintStyle: TextStyle(color: kMuted.withValues(alpha: 0.5)),
        suffixText: suffix,
        suffixStyle: TextStyle(color: kMuted),
        filled: true,
        fillColor: kCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: kAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: InkWell(
        onTap: _pickDate,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: kAccent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tanggal Terakhir Diganti',
                      style: TextStyle(color: kMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedDate != null
                          ? DateFormat(
                              'd MMM yyyy',
                              'id_ID',
                            ).format(_selectedDate!)
                          : 'Pilih tanggal penggantian',
                      style: const TextStyle(color: Colors.black87, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: kMuted, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catatan Tambahan (Opsional)',
          style: TextStyle(
            color: kAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesController,
          maxLines: 4,
          maxLength: 500,
          style: const TextStyle(color: Colors.black87),
          decoration: InputDecoration(
            hintText: 'Catatan',
            hintStyle: TextStyle(color: kMuted.withValues(alpha: 0.5)),
            filled: true,
            fillColor: kCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: kBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: kAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
