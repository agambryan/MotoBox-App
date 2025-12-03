import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MotorcycleApiService {
  // Using API Ninjas direct endpoint
  static const String baseUrl = 'https://api.api-ninjas.com/v1/motorcycles';
  static const String apiKey = 'TCTJ1iI3/0BQhNGX3mw8yw==24A27P5doczokQIQ';

  // Popular motorcycle manufacturers list as fallback
  static const List<String> popularMakes = [
    'Honda',
    'Yamaha',
    'Suzuki',
    'Kawasaki',
    'Ducati',
    'Harley-Davidson',
    'BMW',
    'Triumph',
    'KTM',
    'Aprilia',
    'Moto Guzzi',
    'Indian',
    'Royal Enfield',
    'Bajaj',
    'TVS',
    'Hero',
    'Kymco',
    'Piaggio',
    'Vespa',
    'Husqvarna',
  ];

  // Get list of all motorcycle manufacturers
  Future<List<String>> getMakes() async {
    try {
      // Simple approach: Just return popular makes list
      // This is instant and doesn't require API call
      // API will be used when user selects a make to get models
      debugPrint('Returning popular makes list (no API call needed)');
      return List<String>.from(popularMakes)..sort();
    } catch (e) {
      debugPrint('Error getting makes: $e');
      return List<String>.from(popularMakes)..sort();
    }
  }

  // Get list of available years for a specific make and model
  Future<List<int>> getYears(String make, String model) async {
    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: {
        'make': make,
        'model': model,
      });
      final response = await http.get(
        uri,
        headers: {
          'X-Api-Key': apiKey,
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Years API timeout');
          throw TimeoutException('API request timeout');
        },
      );

      debugPrint('Years API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);
        if (jsonData is List) {
          // Extract unique years from the motorcycle data
          final Set<int> years = {};
          for (var item in jsonData) {
            if (item is Map && item.containsKey('year') && item['year'] != null) {
              final yearValue = item['year'];
              if (yearValue is int) {
                years.add(yearValue);
              } else if (yearValue is String) {
                final yearInt = int.tryParse(yearValue);
                if (yearInt != null) {
                  years.add(yearInt);
                }
              }
            }
          }
          final yearsList = years.toList()..sort((a, b) => b.compareTo(a)); // Sort descending (newest first)
          // If API returns years, use them. Otherwise return recent years as fallback.
          if (yearsList.isNotEmpty) {
            return yearsList;
          }
        }
      }

      // Fallback: return years from 2010 to current year
      final currentYear = DateTime.now().year;
      return List.generate(currentYear - 2009, (i) => currentYear - i);
    } on TimeoutException {
      debugPrint('Years API timeout, using fallback');
      final currentYear = DateTime.now().year;
      return List.generate(currentYear - 2009, (i) => currentYear - i);
    } catch (e) {
      debugPrint('Error fetching years, using fallback: $e');
      // Fallback: return years from 2010 to current year
      final currentYear = DateTime.now().year;
      return List.generate(currentYear - 2009, (i) => currentYear - i);
    }
  }

  // Get list of models for a specific manufacturer
  Future<List<String>> getModels(String make) async {
    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: {'make': make});
      final response = await http.get(
        uri,
        headers: {
          'X-Api-Key': apiKey,
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Models API timeout');
          throw TimeoutException('API request timeout');
        },
      );

      debugPrint('Models API Response Status: ${response.statusCode}');
      debugPrint('Models API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);
        if (jsonData is List) {
          // Extract unique models from the motorcycle data
          final Set<String> models = {};
          for (var item in jsonData) {
            if (item is Map && item.containsKey('model') && item['model'] != null) {
              models.add(item['model'].toString());
            }
          }
          return models.toList()..sort();
        }
        return [];
      } else {
        final errorBody = response.body;
        debugPrint('Error response body: $errorBody');
        throw Exception('Failed to load models: ${response.statusCode} - $errorBody');
      }
    } on TimeoutException {
      debugPrint('Models API timeout');
      throw Exception('Koneksi timeout. Periksa internet Anda.');
    } catch (e) {
      debugPrint('Error fetching models: $e');
      rethrow;
    }
  }

  // Search motorcycles by make, model, and optionally year
  Future<List<Map<String, dynamic>>> searchMotorcycles({
    String? make,
    String? model,
    int? year,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (make != null && make.isNotEmpty) queryParams['make'] = make;
      if (model != null && model.isNotEmpty) queryParams['model'] = model;
      if (year != null) queryParams['year'] = year.toString();
      // API Ninjas may not support limit/offset, so we only add if needed
      // Most APIs support these but let's be safe
      if (limit > 0 && limit <= 1000) {
        queryParams['limit'] = limit.toString();
      }

      final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'X-Api-Key': apiKey,
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Search API timeout');
          throw TimeoutException('API request timeout');
        },
      );

      debugPrint('Search API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic jsonData = json.decode(response.body);
        if (jsonData is List) {
          return jsonData.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        }
        return [];
      } else {
        final errorBody = response.body;
        debugPrint('Error response body: $errorBody');
        throw Exception('Failed to search motorcycles: ${response.statusCode} - $errorBody');
      }
    } on TimeoutException {
      debugPrint('Search API timeout');
      throw Exception('Koneksi timeout. Periksa internet Anda.');
    } catch (e) {
      debugPrint('Error searching motorcycles: $e');
      rethrow;
    }
  }
}

