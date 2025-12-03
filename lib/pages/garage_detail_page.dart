import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

class GarageDetailPage extends StatefulWidget {
  final String apiKey;
  final String placeId;
  final double? originLat;
  final double? originLng;

  const GarageDetailPage({
    super.key,
    required this.apiKey,
    required this.placeId,
    this.originLat,
    this.originLng,
  });

  @override
  State<GarageDetailPage> createState() => _GarageDetailPageState();
}

class _GarageDetailPageState extends State<GarageDetailPage> {
  late Future<Map<String, dynamic>> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _fetchPlaceDetails();
  }

  Future<Map<String, dynamic>> _fetchPlaceDetails() async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=${widget.placeId}'
      '&fields=name,formatted_address,geometry,photos,rating,review,user_ratings_total,opening_hours,formatted_phone_number,website,url'
      '&key=${widget.apiKey}',
    );

    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      throw Exception('Gagal memuat detail tempat');
    }
    final data = json.decode(resp.body);
    if (data['status'] != 'OK') {
      throw Exception(data['status'] ?? 'Gagal memuat detail');
    }
    return Map<String, dynamic>.from(data['result']);
  }

  String _photoUrl(String photoReference, {int maxWidth = 800}) {
    return 'https://maps.googleapis.com/maps/api/place/photo'
        '?maxwidth=$maxWidth&photo_reference=$photoReference&key=${widget.apiKey}';
  }

  Future<void> _openInMaps(String placeId) async {
    final url = Uri.parse(
      'https://www.google.com/maps/place/?q=place_id:$placeId',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Bengkel'),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        backgroundColor: kAccent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: kBg,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat detail: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _detailFuture = _fetchPlaceDetails();
                        });
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            );
          }

          final detail = snapshot.data!;
          final photos = (detail['photos'] as List?)?.cast<Map>() ?? const [];
          final opening = detail['opening_hours'] as Map<String, dynamic>?;
          final openNow = opening != null
              ? (opening['open_now'] ?? false)
              : null;
          final weekdayText =
              (opening != null ? opening['weekday_text'] : null) as List?;
          final rating = detail['rating'];
          final ratingsTotal = detail['user_ratings_total'];
          final name = detail['name'] ?? 'Bengkel';
          final address = detail['formatted_address'] ?? '';
          final phone = detail['formatted_phone_number'];
          final website = detail['website'];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Photos carousel (simple horizontal list)
                if (photos.isNotEmpty)
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, index) {
                        final ref = photos[index]['photo_reference'] as String?;
                        if (ref == null) return const SizedBox();
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            _photoUrl(ref),
                            width: 320,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemCount: photos.length.clamp(0, 8),
                    ),
                  )
                else
                  Container(
                    height: 160,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: const Center(child: Text('Tidak ada foto')),
                  ),

                // Header info
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kCardAlt),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(address, style: TextStyle(color: kMuted)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (rating != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text('$rating (${ratingsTotal ?? 0})'),
                                ],
                              ),
                            ),
                          const SizedBox(width: 8),
                          if (openNow != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (openNow ? Colors.green : Colors.red)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                openNow ? 'Buka sekarang' : 'Tutup',
                                style: TextStyle(
                                  color: openNow ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (phone != null)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final tel = Uri.parse('tel:$phone');
                                if (await canLaunchUrl(tel)) {
                                  await launchUrl(tel);
                                }
                              },
                              icon: const Icon(Icons.phone, size: 18),
                              label: Text(phone),
                            ),
                          if (website != null)
                            OutlinedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(website);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                              icon: const Icon(Icons.public, size: 18),
                              label: const Text('Website'),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _openInMaps(widget.placeId),
                            icon: const Icon(Icons.map, size: 18),
                            label: const Text('Buka di Maps'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Opening hours
                if (weekdayText != null)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Jam Operasional',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...weekdayText.map(
                          (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(e.toString()),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Reviews (limited)
                if ((detail['reviews'] as List?) != null)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ulasan',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...((detail['reviews'] as List).cast<Map>())
                            .take(5)
                            .map((r) {
                              final author = r['author_name'] ?? 'Anonim';
                              final text = r['text'] ?? '';
                              final rate = r['rating'];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.person, size: 18),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            author.toString(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (rate != null)
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(rate.toString()),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(text.toString()),
                                  ],
                                ),
                              );
                            }),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
