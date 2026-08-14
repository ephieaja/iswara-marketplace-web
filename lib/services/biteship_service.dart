import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BiteshipService {
  /// Singleton
  static final BiteshipService _instance = BiteshipService._internal();
  factory BiteshipService() => _instance;
  BiteshipService._internal();

  // ==========================================
  // Biteship API Configuration
  // ==========================================
  // API key dibaca dari env var BITESHIP_API_KEY yang di-pass saat build:
  //   flutter build web --dart-define=BITESHIP_API_KEY=your_key
  // Fallback ke hardcoded key lokal kalau env var kosong (untuk development).
  static const String _apiKey = String.fromEnvironment(
    'BITESHIP_API_KEY',
    defaultValue: '6a5563bca9c1409538cf0406',
  );

  // Base URL Biteship API
  static const String _baseUrl = 'https://api.bitship.id/v1';

  // Cache settings
  static const Duration _cacheDuration = Duration(hours: 1);
  static const String _cacheKey = 'biteship_cache';

  // Cache storage
  Map<String, dynamic>? _cache;

  /// Initialize cache from local storage
  Future<void> initCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheString = prefs.getString(_cacheKey);
      if (cacheString != null) {
        _cache = jsonDecode(cacheString) as Map<String, dynamic>;
        debugPrint('Biteship cache loaded');
      }
    } catch (e) {
      debugPrint('Error loading Biteship cache: $e');
      _cache = {};
    }
  }

  /// Save cache to local storage
  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(_cache));
    } catch (e) {
      debugPrint('Error saving Biteship cache: $e');
    }
  }

  /// Generate cache key
  String _getCacheKey(String originArea, String destinationArea, int weight) {
    return '${originArea}_${destinationArea}_$weight';
  }

  /// Check if cache is still valid
  bool _isCacheValid(String cacheKey) {
    if (_cache == null || !_cache!.containsKey(cacheKey)) {
      return false;
    }

    final cacheData = _cache![cacheKey] as Map<String, dynamic>;
    final timestamp = cacheData['timestamp'] as int;
    final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    return now.difference(cachedTime) < _cacheDuration;
  }

  /// Get cached shipping cost
  Map<String, dynamic>? _getCachedResult(String cacheKey) {
    if (_isCacheValid(cacheKey)) {
      final cacheData = _cache![cacheKey] as Map<String, dynamic>;
      debugPrint('Biteship: Using cached result for $cacheKey');
      return cacheData['results'] as Map<String, dynamic>;
    }
    return null;
  }

  /// Save to cache
  Future<void> _saveToCache(String cacheKey, Map<String, dynamic> results) async {
    _cache ??= {};
    _cache![cacheKey] = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'results': results,
    };
    await _saveCache();
    debugPrint('Biteship: Cached result for $cacheKey');
  }

  /// Get available areas from Biteship API
  Future<List<Map<String, dynamic>>> getAreas() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/maps/areas'),
        headers: {
          'Authorization': _apiKey,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle different response formats from Biteship
        List<dynamic> areas = [];
        if (data['areas'] != null) {
          areas = data['areas'] as List;
        } else if (data['data'] != null) {
          areas = data['data'] as List;
        } else if (data['results'] != null) {
          areas = data['results'] as List;
        }

        return areas.cast<Map<String, dynamic>>();
      } else {
        debugPrint('Biteship Areas API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching areas: $e');
    }
    return [];
  }

  /// Get available couriers from Biteship API
  Future<List<Map<String, dynamic>>> getCouriers() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/couriers'),
        headers: {
          'Authorization': _apiKey,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle different response formats from Biteship
        List<dynamic> couriers = [];
        if (data['couriers'] != null) {
          couriers = data['couriers'] as List;
        } else if (data['data'] != null) {
          couriers = data['data'] as List;
        } else if (data['results'] != null) {
          couriers = data['results'] as List;
        }

        return couriers.cast<Map<String, dynamic>>();
      } else {
        debugPrint('Biteship Couriers API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching couriers: $e');
    }
    return [];
  }

  /// Get shipping cost - calls Biteship API directly
  Future<Map<String, dynamic>> getShippingCost({
    required String originAreaId,
    required String destinationAreaId,
    required int weight,
    String couriers = 'jne,jnt,sicepat',
  }) async {
    // Generate cache key
    final cacheKey = _getCacheKey(originAreaId, destinationAreaId, weight);

    // Check cache first
    final cachedResult = _getCachedResult(cacheKey);
    if (cachedResult != null) {
      return cachedResult;
    }

    debugPrint('Biteship: Calling API for $cacheKey');

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/rates/couriers'),
        headers: {
          'Authorization': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'origin_area_id': originAreaId,
          'destination_area_id': destinationAreaId,
          'weight': weight,
          'couriers': couriers,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Save to cache
        await _saveToCache(cacheKey, data);

        return data;
      } else {
        debugPrint('Biteship API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching shipping cost: $e');
    }

    return {};
  }

  /// Clear all cache
  Future<void> clearCache() async {
    _cache = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      debugPrint('Biteship cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Get cache info
  Map<String, int> getCacheInfo() {
    if (_cache == null) return {'count': 0, 'valid': 0};

    int validCount = 0;
    for (final key in _cache!.keys) {
      if (_isCacheValid(key)) validCount++;
    }

    return {
      'count': _cache!.length,
      'valid': validCount,
    };
  }
}
