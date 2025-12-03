import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SparepartService {
  static const String baseUrl = 'https://motobox-api.vercel.app';
  static const String sparepartsEndpoint = '/spareparts.json';

  Future<List<Map<String, dynamic>>> getSpareparts() async {
    try {
      final uri = Uri.parse('$baseUrl$sparepartsEndpoint');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);
        
        // Jika langsung array
        if (jsonData is List) {
          return jsonData
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }
        
        // Jika Map dengan key data_spareparts
        if (jsonData is Map<String, dynamic>) {
          if (jsonData.containsKey('data_spareparts')) {
            final List<dynamic> data = jsonData['data_spareparts'];
            return data
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();
          }

          // Alternatif: jika ada key lain yang berisi array
          if (jsonData.isNotEmpty) {
            final firstKey = jsonData.keys.first;
            final data = jsonData[firstKey];
            if (data is List) {
              return data
                  .map((item) => Map<String, dynamic>.from(item as Map))
                  .toList();
            }
          }
        }

        return [];
      } else {
        throw Exception(
          'Failed to load spareparts: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error fetching spareparts: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSparepartsByCategory(
    String category,
  ) async {
    final allSpareparts = await getSpareparts();
    return allSpareparts
        .where((sparepart) =>
            sparepart['kategori']?.toString().toLowerCase() ==
            category.toLowerCase())
        .toList();
  }

  Future<List<Map<String, dynamic>>> getSparepartsByBrand(
    String brand,
  ) async {
    final allSpareparts = await getSpareparts();
    return allSpareparts
        .where((sparepart) =>
            sparepart['merek']?.toString().toLowerCase() ==
            brand.toLowerCase())
        .toList();
  }

  Future<List<Map<String, dynamic>>> searchSpareparts(String query) async {
    final allSpareparts = await getSpareparts();
    final lowerQuery = query.toLowerCase();
    return allSpareparts
        .where((sparepart) {
          final nama = sparepart['nama']?.toString().toLowerCase() ?? '';
          final merek = sparepart['merek']?.toString().toLowerCase() ?? '';
          final kategori = sparepart['kategori']?.toString().toLowerCase() ?? '';
          return nama.contains(lowerQuery) ||
              merek.contains(lowerQuery) ||
              kategori.contains(lowerQuery);
        })
        .toList();
  }
}

