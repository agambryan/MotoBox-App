import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

class LifespanService {
  static const String _endpoint = 'https://motobox-api.vercel.app/lifespan_component.json';

  static String mapTypeToCategory({required String? type, int? engineCapacity}) {
    final t = (type ?? '').toLowerCase();
    if (t == 'scooter') return 'matic';
    if (t == 'underbone') return 'bebek';
    if (t == 'sport') return 'sport';
    if ((engineCapacity ?? 0) > 150) return 'sport';
    return 'matic'; // fallback
  }

  static Future<Map<String, dynamic>> _fetchJson() async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(_endpoint));
      final res = await req.close();
      if (res.statusCode != 200) {
        throw Exception('Failed to fetch lifespan data: ${res.statusCode}');
      }
      final body = await res.transform(utf8.decoder).join();
      return json.decode(body) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  // Apply defaults for a specific category to components of a motor
  // Will not override components that were marked custom by user
  static Future<void> applyDefaultsForCategory({
    required String motorId,
    required String category, // 'matic' | 'bebek' | 'sport'
  }) async {
    try {
      final data = await _fetchJson();
      final cats = data['categories'];
      if (cats == null || cats is! Map<String, dynamic>) return;
      
      final catData = cats[category];
      if (catData == null || catData is! Map<String, dynamic>) return;
      
      final componentsRaw = catData['components'];
      if (componentsRaw == null) return;
      
      Map<String, dynamic> components;
      if (componentsRaw is Map<String, dynamic>) {
        components = componentsRaw;
      } else if (componentsRaw is List) {
        // Handle case where components is a List
        components = {};
        for (var item in componentsRaw) {
          if (item is Map<String, dynamic> && item.containsKey('id')) {
            components[item['id'].toString()] = item;
          }
        }
      } else {
        return;
      }

      final db = DatabaseHelper();
      final existing = await db.getComponents(motorId);
      final existingById = {for (final row in existing) row['id'] as String: row};

      for (final entry in components.entries) {
        final compId = entry.key;
        final comp = entry.value;
        if (comp is! Map<String, dynamic>) continue;
        
        final defaultKm = (comp['lifespan_default'] is Map<String, dynamic>)
            ? ((comp['lifespan_default'] as Map)['km'] as int?) ?? 0
            : 0;
        final timeMonths = (comp['time_months'] as int?) ?? 0;
        final defaultDays = timeMonths > 0 
            ? timeMonths * 30 
            : ((comp['lifespan_default'] is Map<String, dynamic>)
                ? ((comp['lifespan_default'] as Map)['days'] as int?) ?? 0
                : 0);

        final row = existingById[compId];
        if (row == null) {
          await db.insertComponent({
            'id': compId,
            'motor_id': motorId,
            'nama': (comp['name'] ?? compId).toString(),
            'lifespanKm': defaultKm,
            'lifespanDays': defaultDays,
            'is_active': 1,
            'keterangan': comp['note']?.toString(),
            'lifespan_source': 'default',
          });
        } else {
          final source = (row['lifespan_source'] as String?) ?? 'default';
          if (source == 'default') {
            await db.updateComponent({
              'id': compId,
              'motor_id': motorId,
              'lifespanKm': defaultKm,
              'lifespanDays': defaultDays,
              'keterangan': comp['note']?.toString(),
            });
          }
        }
      }
    } catch (e) {
      debugPrint('LifespanService.applyDefaultsForCategory error: $e');
    }
  }

  // Convenience: apply defaults from Ninjas API-like data
  static Future<void> applyFromApiData({
    required String motorId,
    required Map<String, dynamic> apiData,
  }) async {
    final type = apiData['type'] as String?;
    final cc = apiData['engine_capacity'] as int?;
    final category = mapTypeToCategory(type: type, engineCapacity: cc);
    try {
      await applyDefaultsForCategory(motorId: motorId, category: category);
    } catch (e) {
      debugPrint('LifespanService error: $e');
    }
  }
}


