import 'package:flutter/material.dart';
import '../models/sparepart.dart';
import '../services/sparepart_service.dart';
import 'sparepart_detail_page.dart';
import '../theme.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final SparepartService _sparepartService = SparepartService();
  List<Sparepart> _spareparts = [];
  List<Sparepart> _filteredSpareparts = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _selectedBrand = 'all';
  String _searchQuery = '';
  String _errorMessage = '';

  List<String> _categories = ['all', 'Loading...'];
  List<String> _brands = ['all', 'Loading...'];

  @override
  void initState() {
    super.initState();
    _loadSpareparts();
  }

  Future<void> _loadSpareparts() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final List<Map<String, dynamic>> apiData = await _sparepartService
          .getSpareparts();

      if (!mounted) return;

      // Convert API data to Sparepart model
      final spareparts = apiData.map((e) => Sparepart.fromMap(e)).toList();

      // Extract unique categories and brands
      final categories =
          spareparts
              .map((s) => s.kategori)
              .where((k) => k.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final brands =
          spareparts
              .map((s) => s.merek)
              .where((m) => m.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      setState(() {
        _spareparts = spareparts;
        _filteredSpareparts = spareparts;
        _categories = ['all', ...categories];
        _brands = ['all', ...brands];
        _isLoading = false;
      });

      _applyFilters();
    } catch (e) {
      debugPrint('API Error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat data sparepart: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Sparepart> filtered = List.from(_spareparts);

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((sparepart) {
        return sparepart.nama.toLowerCase().contains(query) ||
            sparepart.merek.toLowerCase().contains(query) ||
            sparepart.kategori.toLowerCase().contains(query);
      }).toList();
    }

    // Apply category filter
    if (_selectedCategory != 'all') {
      filtered = filtered
          .where((sparepart) => sparepart.kategori == _selectedCategory)
          .toList();
    }

    // Apply brand filter
    if (_selectedBrand != 'all') {
      filtered = filtered
          .where((sparepart) => sparepart.merek == _selectedBrand)
          .toList();
    }

    setState(() {
      _filteredSpareparts = filtered;
    });
  }

  // Fungsi untuk navigasi ke halaman detail
  void _navigateToDetail(Sparepart sparepart) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SparepartDetailPage(sparepart: sparepart),
      ),
    );
  }

  Widget _buildSparepartsList() {
    if (_filteredSpareparts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: kMuted),
            const SizedBox(height: 16),
            Text(
              'Tidak ada sparepart ditemukan',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: kMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 86.0),
      itemCount: _filteredSpareparts.length,
      itemBuilder: (context, index) {
        final sparepart = _filteredSpareparts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () =>
                _navigateToDetail(sparepart), // Navigasi ke detail page
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image with Hero animation
                  Hero(
                    tag: 'sparepart-${sparepart.idProduk}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          sparepart.gambarUrl != null &&
                              sparepart.gambarUrl!.isNotEmpty
                          ? Image.network(
                              sparepart.gambarUrl!,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey[300],
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 100,
                                  height: 100,
                                  color: kCardAlt,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: kMuted,
                                  ),
                                );
                              },
                            )
                          : Container(
                              width: 100,
                              height: 100,
                              color: kCardAlt,
                              child: Icon(
                                Icons.bike_scooter,
                                color: kMuted,
                                size: 40,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            sparepart.kategori,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Name
                        Text(
                          sparepart.nama,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Brand
                        Row(
                          children: [
                            Icon(Icons.label, size: 14, color: kMuted),
                            const SizedBox(width: 4),
                            Text(
                              sparepart.merek,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Motor Type
                        if (sparepart.tipeMotor.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.two_wheeler, size: 14, color: kMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  sparepart.tipeMotorString,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[600]),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        // Price
                        if (sparepart.harga != null)
                          Text(
                            sparepart.hargaFormatted,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                          )
                        else
                          Text(
                            'Harga tidak tersedia',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        // Stock
                        if (sparepart.stok != null)
                          Row(
                            children: [
                              Icon(Icons.inventory_2, size: 14, color: kMuted),
                              const SizedBox(width: 4),
                              Text(
                                'Stok: ${sparepart.stok} ${sparepart.satuan ?? ''}',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: sparepart.stok! > 0
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jelajahi Sparepart'),
        titleTextStyle: TextStyle(
          color: kAccent,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSpareparts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Cari sparepart...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                          _applyFilters();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applyFilters();
              },
            ),
          ),
          // Combined Filter (Category and Brand in dropdown)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(
                          category == 'all' ? 'Semua Kategori' : category,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedCategory = value;
                        });
                        _applyFilters();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBrand,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Merek',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: _brands.map((brand) {
                      return DropdownMenuItem(
                        value: brand,
                        child: Text(
                          brand == 'all' ? 'Semua Merek' : brand,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedBrand = value;
                        });
                        _applyFilters();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Results count
          if (!_isLoading && _errorMessage.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ditemukan ${_filteredSpareparts.length} sparepart',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ),
            ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSpareparts,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  )
                : _buildSparepartsList(),
          ),
        ],
      ),
    );
  }
}
