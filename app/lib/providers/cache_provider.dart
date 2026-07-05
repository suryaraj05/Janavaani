import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cache_service.dart';

/// Cache provider for storing frequently accessed data
/// Uses both in-memory and persistent storage for instant loading
class CacheProvider {
  // In-memory cache for ultra-fast access
  static final Map<String, dynamic> _memoryCache = {};
  static final Map<String, DateTime> _memoryTimestamps = {};
  static const Duration _memoryCacheExpiry = Duration(minutes: 1);

  /// Get cached data - checks memory first, then persistent storage
  static Future<T?> get<T>(String key) async {
    // Check memory cache first (instant)
    if (_memoryCache.containsKey(key)) {
      final timestamp = _memoryTimestamps[key];
      if (timestamp != null && DateTime.now().difference(timestamp) < _memoryCacheExpiry) {
        return _memoryCache[key] as T?;
      } else {
        _memoryCache.remove(key);
        _memoryTimestamps.remove(key);
      }
    }

    // Check persistent cache (fast)
    return await CacheService.get<T>(key);
  }

  /// Set cached data in both memory and persistent storage
  static Future<void> set(String key, dynamic value) async {
    // Set in memory (instant access)
    _memoryCache[key] = value;
    _memoryTimestamps[key] = DateTime.now();

    // Set in persistent storage (background)
    await CacheService.set(key, value);
  }

  /// Clear specific cache entry from both storages
  static Future<void> clear(String key) async {
    _memoryCache.remove(key);
    _memoryTimestamps.remove(key);
    await CacheService.clear(key);
  }

  /// Clear all cache from both storages
  static Future<void> clearAll() async {
    _memoryCache.clear();
    _memoryTimestamps.clear();
    await CacheService.clearAll();
  }

  /// Invalidate cache for a specific key
  static Future<void> invalidate(String key) async {
    _memoryCache.remove(key);
    _memoryTimestamps.remove(key);
    await CacheService.invalidate(key);
  }

  /// Check if cache exists
  static Future<bool> exists(String key) async {
    if (_memoryCache.containsKey(key)) {
      final timestamp = _memoryTimestamps[key];
      if (timestamp != null && DateTime.now().difference(timestamp) < _memoryCacheExpiry) {
        return true;
      }
    }
    return await CacheService.exists(key);
  }
}

/// Provider for cache management
final cacheProvider = Provider<CacheProvider>((ref) => CacheProvider());

