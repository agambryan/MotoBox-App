import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../services/encryption_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../auth/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _feedback = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final db = DatabaseHelper();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
    var p = await db.getUserProfile(userId: userId);

    // Set default profile jika belum ada
    if (p == null || p['name'] == null || p['name'].toString().isEmpty) {
      await db.upsertUserProfile(
        userId: userId,
        name: 'Muhammad Agam Febryan',
        nim: '124230093',
        placeOfBirth: 'Bantul',
        dateOfBirth: '2005-02-11',
        hobbies: 'Mancing dan Bermain Game',
      );
      p = await db.getUserProfile(userId: userId);
    }

    // Load username dari Supabase profiles
    String? username;
    try {
      final supabaseService = SupabaseService();
      final profile = await supabaseService.getUserProfile();
      username = profile?['username'] as String?;
    } catch (e) {
      debugPrint('Error loading username: $e');
    }

    // Buat mutable copy dan tambahkan username
    final profileWithUsername = p != null ? Map<String, dynamic>.from(p) : <String, dynamic>{};
    profileWithUsername['username'] = username;

    final f = await db.listFeedback(category: 'saran_kesan');
    setState(() {
      _profile = profileWithUsername;
      _feedback = f;
      _loading = false;
    });
  }

  Future<void> _editProfile() async {
    final nameCtrl = TextEditingController(text: _profile?['name'] ?? '');
    final nimCtrl = TextEditingController(text: _profile?['nim'] ?? '');
    final placeCtrl = TextEditingController(
      text: _profile?['place_of_birth'] ?? '',
    );
    final hobbiesCtrl = TextEditingController(text: _profile?['hobbies'] ?? '');
    String? photoPath = _profile?['photo_path'];
    DateTime? selectedDate;

    // Parse existing date if available
    if (_profile?['date_of_birth'] != null && _profile!['date_of_birth'].toString().isNotEmpty) {
      try {
        selectedDate = DateTime.parse(_profile!['date_of_birth']);
      } catch (e) {
        selectedDate = null;
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage:
                            (photoPath?.isNotEmpty ?? false) &&
                                File(photoPath!).existsSync()
                            ? FileImage(File(photoPath!))
                            : null,
                        child: (photoPath?.isNotEmpty ?? false) != true
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (picked != null) {
                                final encryptionService = EncryptionService.instance;
                                final validatedPath = encryptionService.validatePhotoPath(picked.path);

                                if (validatedPath != null) {
                                  setModalState(() {
                                    photoPath = validatedPath;
                                  });
                                } else {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('File foto tidak valid'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galeri'),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.camera,
                              );
                              if (picked != null) {
                                final encryptionService = EncryptionService.instance;
                                final validatedPath = encryptionService.validatePhotoPath(picked.path);

                                if (validatedPath != null) {
                                  setModalState(() {
                                    photoPath = validatedPath;
                                  });
                                } else {
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('File foto tidak valid'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Kamera'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _field('Nama', nameCtrl),
                  _field('NIM', nimCtrl, keyboard: TextInputType.number),
                  _field('Tempat Lahir', placeCtrl),
                  // Date picker field
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(1900),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Lahir',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          selectedDate != null
                              ? '${selectedDate!.day.toString().padLeft(2, '0')}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.year}'
                              : 'Pilih tanggal lahir',
                          style: TextStyle(
                            color: selectedDate != null ? Colors.black87 : Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _field('Hobi (pisahkan dengan koma)', hobbiesCtrl),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final db = DatabaseHelper();
                        final userId = Supabase.instance.client.auth.currentUser?.id ?? 'local';
                        await db.upsertUserProfile(
                          userId: userId,
                          name: nameCtrl.text.trim(),
                          nim: nimCtrl.text.trim(),
                          placeOfBirth: placeCtrl.text.trim(),
                          dateOfBirth: selectedDate != null
                              ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                              : '',
                          hobbies: hobbiesCtrl.text.trim(),
                          photoPath: photoPath,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await _loadAll();
                      },
                      child: const Text('Simpan'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatCategoryLabel(String category) {
    // Convert 'saran_kesan' to 'Saran & Kesan'
    if (category == 'saran_kesan') return 'Saran & Kesan';
    return category;
  }

  Future<void> _addOrEditFeedback({
    int? id,
    required String category,
    String initial = '',
  }) async {
    final ctrl = TextEditingController(text: initial);
    final label = _formatCategoryLabel(category);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          id == null ? 'Tambah $label' : 'Edit $label',
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Tulis di sini...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final db = DatabaseHelper();
              if (id == null) {
                await db.addFeedback(
                  category: category,
                  content: ctrl.text.trim(),
                );
              } else {
                await db.updateFeedback(id: id, content: ctrl.text.trim());
              }
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              await _loadAll();
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text(
          'Anda yakin ingin keluar? Data lokal akan dihapus dan akan dimuat ulang saat login kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Sign out from Supabase (data motor tetap tersimpan di local)
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saat logout: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (!mounted) return;
    await Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _deleteFeedback(int id) async {
    final db = DatabaseHelper();
    await db.deleteFeedback(id);
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        centerTitle: true,
        backgroundColor: kAccent,
        actions: [
          IconButton(
            onPressed: _editProfile,
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profil',
            color: Colors.white,
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            color: Colors.white,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildAvatar(_profile?['photo_path']),
                    const SizedBox(height: 30),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildProfileItem('Nama', _profile?['name'] ?? '-'),
                            const Divider(),
                            _buildProfileItem('Username', _profile?['username'] ?? '-'),
                            const Divider(),
                            _buildProfileItem('NIM', _profile?['nim'] ?? '-'),
                            const Divider(),
                            _buildProfileItem(
                              'Tempat dan Tanggal Lahir',
                              _composeTtl(_profile),
                            ),
                            const Divider(),
                            _buildProfileItem(
                              'Hobi',
                              _profile?['hobbies'] ?? '-',
                            ),
                            const Divider(),
                            _buildProfileItem(
                              'Email',
                              Supabase.instance.client.auth.currentUser?.email ?? '-',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _feedbackSection('Saran & Kesan', _feedback, 'saran_kesan'),
                    const SizedBox(height: 86),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar(String? photoPath) {
    final hasFile =
        (photoPath?.isNotEmpty ?? false) && File(photoPath!).existsSync();
    return CircleAvatar(
      radius: 60,
      backgroundImage: hasFile ? FileImage(File(photoPath)) : null,
      child: hasFile ? null : const Icon(Icons.person, size: 60),
    );
  }

  String _composeTtl(Map<String, dynamic>? p) {
    final place = p?['place_of_birth'];
    final date = p?['date_of_birth'];
    if ((place == null || place.toString().isEmpty) &&
        (date == null || date.toString().isEmpty)) {
      return '-';
    }
    if (place == null || place.toString().isEmpty) return _formatDate(date.toString());
    if (date == null || date.toString().isEmpty) return place.toString();
    return '$place, ${_formatDate(date.toString())}';
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Text(': '),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _feedbackSection(
    String title,
    List<Map<String, dynamic>> items,
    String category,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccent, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: kAccent.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.feedback, color: kAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kAccent,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _addOrEditFeedback(category: category),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.note_add, size: 48, color: kMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 8),
                      Text(
                        'Belum ada $title',
                        style: TextStyle(color: kMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...items.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kCardAlt.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item['content'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: kMuted, size: 20),
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await _addOrEditFeedback(
                                id: item['id'] as int,
                                category: category,
                                initial: item['content'] ?? '',
                              );
                            } else if (v == 'delete') {
                              await _deleteFeedback(item['id'] as int);
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 18, color: kAccent),
                                  const SizedBox(width: 8),
                                  const Text('Edit'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 18, color: kDanger),
                                  const SizedBox(width: 8),
                                  const Text('Hapus'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (item['updated_at'] != null && item['updated_at'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: kMuted),
                          const SizedBox(width: 4),
                          Text(
                            item['updated_at'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: kMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
