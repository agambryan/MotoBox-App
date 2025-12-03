import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'garage_detail_page.dart';
import '../theme.dart';

class GaragePage extends StatefulWidget {
  const GaragePage({super.key});

  @override
  State<GaragePage> createState() => _GaragePageState();
}

class _GaragePageState extends State<GaragePage> {
  final String _apiKey = "AIzaSyAR8rWB7e4RJK5TXm7xd3wPw_EbReHhw3Q";
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _garages = [];
  bool _isLoading = false;
  Position? _currentPosition;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Izin lokasi ditolak');
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Izin lokasi ditolak permanen. Aktifkan di pengaturan.');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get current position
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      // Fetch nearby garages
      await _fetchNearbyGarages();
    } catch (e) {
      _showError('Gagal mendapatkan lokasi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchNearbyGarages() async {
    if (_currentPosition == null) return;

    try {
      final lat = _currentPosition!.latitude;
      final lng = _currentPosition!.longitude;

      // Search for motorcycle repair shops nearby
      String keyword = _searchQuery.isEmpty ? 'bengkel motor' : _searchQuery;
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?'
        'location=$lat,$lng&'
        'radius=5000&'
        'keyword=$keyword&'
        'key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          if (mounted) {
            setState(() {
              _garages = List<Map<String, dynamic>>.from(data['results']);
              // Sort by distance
              _garages.sort((a, b) {
                double distA = _calculateDistance(
                  lat,
                  lng,
                  a['geometry']['location']['lat'],
                  a['geometry']['location']['lng'],
                );
                double distB = _calculateDistance(
                  lat,
                  lng,
                  b['geometry']['location']['lat'],
                  b['geometry']['location']['lng'],
                );
                return distA.compareTo(distB);
              });
            });
          }
        }
      }
    } catch (e) {
      _showError('Gagal memuat data bengkel: $e');
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openInMaps(double lat, double lng, String name) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  String _getDistanceText(Map<String, dynamic> garage) {
    if (_currentPosition == null) return '';

    double distance = _calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      garage['geometry']['location']['lat'],
      garage['geometry']['location']['lng'],
    );

    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bengkel Terdekat',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: kAccent,
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari bengkel...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          if (mounted) {
                            setState(() {
                              _searchQuery = "";
                            });
                          }
                          _fetchNearbyGarages();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (value) {
                if (mounted) {
                  setState(() {
                    _searchQuery = value;
                  });
                }
                _fetchNearbyGarages();
              },
            ),
          ),

          // List of garages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _garages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.two_wheeler, size: 80, color: kMuted),
                        const SizedBox(height: 16),
                        Text(
                          'Tidak ada bengkel ditemukan',
                          style: TextStyle(fontSize: 16, color: kMuted),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _getCurrentLocation,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Muat Ulang'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _getCurrentLocation,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _garages.length,
                      itemBuilder: (context, index) {
                        final garage = _garages[index];
                        final isOpen =
                            garage['opening_hours']?['open_now'] ?? false;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () {
                              final placeId = garage['place_id'];
                              if (placeId != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GarageDetailPage(
                                      apiKey: _apiKey,
                                      placeId: placeId,
                                      originLat: _currentPosition?.latitude,
                                      originLng: _currentPosition?.longitude,
                                    ),
                                  ),
                                );
                              } else {
                                _openInMaps(
                                  garage['geometry']['location']['lat'],
                                  garage['geometry']['location']['lng'],
                                  garage['name'],
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: kAccent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.two_wheeler,
                                      size: 32,
                                      color: kAccent,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          garage['name'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          garage['vicinity'] ??
                                              'Alamat tidak tersedia',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: kMuted,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            // Distance
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.location_on,
                                                    size: 14,
                                                    color: Colors.orange,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    _getDistanceText(garage),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.orange,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Rating
                                            if (garage['rating'] != null) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.green
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.star,
                                                      size: 14,
                                                      color: Colors.amber,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      garage['rating']
                                                          .toString(),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 8),

                                            // Open/Closed status
                                            if (garage['opening_hours'] != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: isOpen
                                                      ? Colors.green
                                                            .withValues(alpha: 0.1)
                                                      : Colors.red.withValues(
                                                          alpha: 0.1,
                                                        ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isOpen ? 'Buka' : 'Tutup',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isOpen
                                                        ? Colors.green
                                                        : Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Navigate button
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: kMuted,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
