import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../theme.dart';

class MotorPhotoAlbum extends StatefulWidget {
  final String motorId;
  final String? currentPhoto;

  const MotorPhotoAlbum({super.key, required this.motorId, this.currentPhoto});

  @override
  State<MotorPhotoAlbum> createState() => _MotorPhotoAlbumState();
}

class _MotorPhotoAlbumState extends State<MotorPhotoAlbum> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _photos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    final photos = await _dbHelper.getMotorPhotos(widget.motorId);
    setState(() {
      _photos = photos;
      _isLoading = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      final photoData = {
        'motor_id': widget.motorId,
        'photo_path': image.path,
        'is_primary': _photos.isEmpty ? 1 : 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      await _dbHelper.insertMotorPhoto(photoData);
      _loadPhotos();
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_library, color: kAccent),
              title: const Text('Pilih dari Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.camera_alt, color: kAccent),
              title: const Text('Ambil Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _deletePhoto(int photoId, {bool showConfirm = true}) async {
    if (showConfirm) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Hapus Foto'),
          content: const Text('Apakah Anda yakin ingin menghapus foto ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Hapus', style: TextStyle(color: kDanger)),
            ),
          ],
        ),
      );

      if (confirm != true) {
        return false;
      }
    }

    await _dbHelper.deleteMotorPhoto(photoId);
    _loadPhotos();
    return true;
  }

  void _showPhotoViewer(int initialIndex) {
    final pageController = PageController(initialPage: initialIndex);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.white),
                tooltip: 'Hapus Foto',
                onPressed: () async {
                  final deleted = await _deletePhoto(_photos[initialIndex]['id'], showConfirm: true);
                  if (deleted) {
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
          body: PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              final photo = _photos[index];
              return PhotoViewGalleryPageOptions(
                imageProvider: FileImage(File(photo['photo_path'])),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              );
            },
            itemCount: _photos.length,
            loadingBuilder: (context, event) =>
                const Center(child: CircularProgressIndicator()),
            pageController: pageController,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _photos.isEmpty
          ? _buildEmptyState()
          : _buildPhotoCarousel(),
    );
  }

  Widget _buildEmptyState() {
    return InkWell(
      onTap: _showImageSourceDialog,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade100,
              Colors.grey.shade200,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.two_wheeler, size: 48, color: kAccent),
            ),
            const SizedBox(height: 16),
            Text(
              'Tambah Foto Motor',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ketuk untuk menambah foto',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoCarousel() {
    int currentPhotoIndex = 0;

    return StatefulBuilder(
      builder: (context, setStateLocal) {
        return Stack(
          children: [
            // Photo carousel with full cover
            PageView.builder(
              itemCount: _photos.length,
              onPageChanged: (index) {
                setStateLocal(() {
                  currentPhotoIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final photo = _photos[index];
                final photoFile = File(photo['photo_path']);
                final fileExists = photoFile.existsSync();

                return InkWell(
                  onTap: fileExists ? () => _showPhotoViewer(index) : null,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      color: fileExists ? null : kCardAlt.withValues(alpha: 0.3),
                    ),
                    child: fileExists
                        ? ClipRRect(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            child: Image.file(
                              photoFile,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.broken_image, color: kMuted, size: 32),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Gambar error',
                                        style: TextStyle(color: kMuted, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_not_supported, color: kMuted, size: 32),
                                const SizedBox(height: 4),
                                Text(
                                  'File tidak ada',
                                  style: TextStyle(color: kMuted, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                  ),
                );
              },
            ),

            // Top overlay with gradient background for better visibility
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Delete button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _deletePhoto(_photos[currentPhotoIndex]['id'], showConfirm: true),
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.delete, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),

                    // Add button
                    Container(
                      decoration: BoxDecoration(
                        color: kAccent.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: _showImageSourceDialog,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.add, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Page indicator at bottom
            if (_photos.length > 1)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _photos.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == currentPhotoIndex ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: index == currentPhotoIndex
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
