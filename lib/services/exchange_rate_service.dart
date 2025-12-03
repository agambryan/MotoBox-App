import 'dart:convert';
import 'package:http/http.dart' as http;

class ExchangeRateService {
  static const String _apiKey = '0df0d526c4f50b4fbe480020';
  static const String _baseUrl = 'https://v6.exchangerate-api.com/v6';
  
  // Cache untuk menyimpan rate agar tidak perlu request terus
  static Map<String, dynamic>? _cachedRates;
  static DateTime? _cacheTime;
  static const Duration _cacheDuration = Duration(hours: 1);

  Future<Map<String, dynamic>> getExchangeRates(String baseCurrency) async {
    // Cek cache
    if (_cachedRates != null && 
        _cacheTime != null && 
        DateTime.now().difference(_cacheTime!) < _cacheDuration &&
        _cachedRates!['base_code'] == baseCurrency) {
      return _cachedRates!;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$_apiKey/latest/$baseCurrency'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['result'] == 'success') {
          _cachedRates = data;
          _cacheTime = DateTime.now();
          return data;
        } else {
          throw Exception('API Error: ${data['error-type']}');
        }
      } else {
        throw Exception('Failed to load exchange rates: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<double> convertCurrency({
    required double amount,
    required String from,
    required String to,
  }) async {
    if (from == to) return amount;

    try {
      final rates = await getExchangeRates(from);
      final conversionRates = rates['conversion_rates'] as Map<String, dynamic>;
      
      if (conversionRates.containsKey(to)) {
        final rate = conversionRates[to];
        return amount * rate;
      } else {
        throw Exception('Currency $to not found');
      }
    } catch (e) {
      throw Exception('Conversion error: $e');
    }
  }

  // Clear cache jika diperlukan
  void clearCache() {
    _cachedRates = null;
    _cacheTime = null;
  }
}