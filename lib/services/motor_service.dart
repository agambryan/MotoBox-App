import 'package:http/http.dart' as http;
import 'dart:convert';
import '../database/database_helper.dart';
import 'package:flutter/foundation.dart';

class MotorService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String apiKey =
      'TCTJ1iI3/0BQhNGX3mw8yw==24A27P5doczokQIQ'; // API key from motorcycle_api_service.dart

  // Fetch data dari Ninjas API
  Future<List<Map<String, dynamic>>> fetchMotorsFromApi({
    required String make,
    String? model,
    int? year,
  }) async {
    try {
      // Buat query string
      String query = 'make=$make';
      if (model != null && model.isNotEmpty) query += '&model=$model';
      if (year != null) query += '&year=$year';

      final url = Uri.parse('https://api.api-ninjas.com/v1/motorcycles?$query');

      final response = await http.get(url, headers: {'X-Api-Key': apiKey});

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching from API: $e');
      rethrow;
    }
  }

  // Simpan motor dari API ke database lokal
  Future<void> saveMotorFromApi({
    required Map<String, dynamic> apiData,
    String? customName,
  }) async {
    try {
      // Ambil hanya data yang dibutuhkan dari API
      final String make = apiData['make'] ?? '';
      final String model = apiData['model'] ?? '';
      final int year = apiData['year'] ?? 0;

      // Generate ID unik
      final String motorId = DateTime.now().millisecondsSinceEpoch.toString();

      // Buat data motor untuk disimpan
      // Estimasi harga berdasarkan data dari API (ini contoh logika sederhana)
      int estimatedPrice = _calculateEstimatedPrice(apiData);

      // URL gambar default berdasarkan make dan model
      String imageUrl = await _getMotorcycleImage(make, model, year);

      final motorData = {
        'id': motorId,
        'nama': customName ?? '$make $model $year',
        'merk': make,
        'model': model,
        'gambar': null,
        'gambar_url': imageUrl,
        'harga_estimasi': estimatedPrice,
        'odometer': 0,
        'odometerLastUpdate': 0,
        'fuelLevel': 0.0,
        'fuelLastUpdate': null,
        'autoIncrementEnabled': 0,
        'dailyKm': 0,
        'autoIncrementEnabledDate': null,
        'locationTrackingEnabled': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Simpan ke database
      await _dbHelper.insertMotor(motorData);

      // Insert default components
      await _dbHelper.insertDefaultComponents(motorId);

      debugPrint('Motor saved successfully: ${motorData['nama']}');
    } catch (e) {
      debugPrint('Error saving motor: $e');
      rethrow;
    }
  }

  // Get motors dari database lokal
  Future<List<Map<String, dynamic>>> getLocalMotors() async {
    try {
      return await _dbHelper.getMotors();
    } catch (e) {
      debugPrint('Error getting motors: $e');
      rethrow;
    }
  }

  // Fungsi gabungan: fetch dari API dan langsung simpan
  // Helper function untuk menghitung estimasi harga
  int _calculateEstimatedPrice(Map<String, dynamic> apiData) {
    // Ini adalah logika sederhana, Anda bisa menggantinya dengan logika yang lebih kompleks
    int basePrice = 15000000; // Base price 15 juta

    // Faktor tahun
    int year = apiData['year'] ?? DateTime.now().year;
    int yearFactor = DateTime.now().year - year;
    int yearAdjustment = yearFactor * 1000000; // Kurang 1 juta per tahun

    // Faktor engine size
    int engineSize =
        int.tryParse(
          apiData['engine']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ??
              '0',
        ) ??
        0;
    int engineFactor =
        (engineSize / 100).round() * 500000; // Tambah 500rb per 100cc

    // Faktor merek
    String make = apiData['make']?.toString().toLowerCase() ?? '';
    int brandFactor = 0;
    if (['honda', 'yamaha', 'suzuki', 'kawasaki'].contains(make)) {
      brandFactor = 5000000; // Tambah 5 juta untuk merek Jepang
    } else if (['ducati', 'bmw', 'triumph'].contains(make)) {
      brandFactor = 15000000; // Tambah 15 juta untuk merek premium
    }

    int estimatedPrice =
        basePrice + engineFactor + brandFactor - yearAdjustment;
    return estimatedPrice > 5000000
        ? estimatedPrice
        : 5000000; // Minimum 5 juta
  }

  // Helper function untuk mendapatkan URL gambar
  Future<String> _getMotorcycleImage(
    String make,
    String model,
    int? year,
  ) async {
    try {
      // Coba cari gambar dari unsplash
      final query = Uri.encodeComponent('$make $model motorcycle');
      final unsplashApiKey =
          'YOUR_UNSPLASH_API_KEY'; // Ganti dengan API key Unsplash Anda
      final url = Uri.parse(
        'https://api.unsplash.com/search/photos?query=$query&per_page=1',
      );

      final response = await http.get(
        url,
        headers: {'Authorization': 'Client-ID $unsplashApiKey'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['urls']['regular'];
        }
      }

      // Fallback ke gambar default jika tidak ada hasil dari Unsplash
      return 'https://via.placeholder.com/400x300.png?text=$make+$model';
    } catch (e) {
      debugPrint('Error getting motorcycle image: $e');
      return 'https://via.placeholder.com/400x300.png?text=$make+$model';
    }
  }

  Future<void> fetchAndSaveMotor({
    required String make,
    required String model,
    int? year,
    String? customName,
  }) async {
    try {
      // 1. Fetch dari API
      final results = await fetchMotorsFromApi(
        make: make,
        model: model,
        year: year,
      );

      if (results.isEmpty) {
        throw Exception('No motorcycle found with the given criteria');
      }

      // 2. Ambil data pertama (atau bisa kasih pilihan ke user)
      final selectedMotor = results.first;

      // 3. Simpan ke database
      await saveMotorFromApi(apiData: selectedMotor, customName: customName);
    } catch (e) {
      debugPrint('Error in fetchAndSaveMotor: $e');
      rethrow;
    }
  }
}
