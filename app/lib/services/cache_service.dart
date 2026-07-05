import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent cache service using SharedPreferences
/// Provides instant data loading with background refresh
class CacheService {
  static SharedPreferences? _prefs;
  static const String _cachePrefix = 'cache_';
  static const String _timestampPrefix = 'timestamp_';
  static const String _versionPrefix = 'version_';
  static const int _cacheVersion = 1; // Increment when cache structure changes

  /// Initialize cache service
  static Future<void> init() async {
    try {
      if (_prefs == null) {
        _prefs = await SharedPreferences.getInstance();
      }
      // Clear old cache if version changed (non-blocking, don't await)
      _checkVersion().catchError((e) {
        print('⚠️ [Cache] Version check error: $e');
      });
    } catch (e) {
      print('❌ [Cache] Initialization error: $e');
      // Don't rethrow - allow app to continue
    }
  }

  /// Check and clear cache if version changed
  static Future<void> _checkVersion() async {
    try {
      if (_prefs == null) return;
      final versionKey = '${_versionPrefix}app';
      final currentVersion = _prefs?.getInt(versionKey) ?? 0;
      if (currentVersion < _cacheVersion) {
        // Clear cache in background (don't block)
        clearAll().then((_) {
          _prefs?.setInt(versionKey, _cacheVersion);
        }).catchError((e) {
          print('⚠️ [Cache] Error clearing old cache: $e');
        });
      }
    } catch (e) {
      print('⚠️ [Cache] Version check error: $e');
    }
  }

  /// Get cached data (instant load)
  static Future<T?> get<T>(String key) async {
    // Ensure initialized, but don't block if it fails
    if (_prefs == null) {
      try {
        await init();
      } catch (e) {
        return null; // Return null if init fails
      }
    }
    if (_prefs == null) return null;

    try {
      // Check timestamp
      final timestampKey = '${_timestampPrefix}$key';
      final timestampStr = _prefs?.getString(timestampKey);
      if (timestampStr == null) return null;

      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();
      
      // Cache expiry: 30 minutes for most data, 5 minutes for user data
      final expiry = key.startsWith('user_') 
          ? const Duration(minutes: 5)
          : const Duration(minutes: 30);
      
      if (now.difference(timestamp) > expiry) {
        await clear(key);
        return null;
      }

      // Get cached data
      final cacheKey = '${_cachePrefix}$key';
      final cachedStr = _prefs?.getString(cacheKey);
      if (cachedStr == null) return null;

      // Parse JSON
      final cachedData = jsonDecode(cachedStr);
      return cachedData as T?;
    } catch (e) {
      print('❌ [Cache] Error reading cache for $key: $e');
      await clear(key);
      return null;
    }
  }

  /// Set cached data with timestamp
  static Future<void> set(String key, dynamic value) async {
    // Ensure initialized, but don't block if it fails
    if (_prefs == null) {
      try {
        await init();
      } catch (e) {
        return; // Return early if init fails
      }
    }
    if (_prefs == null) return;

    try {
      final cacheKey = '${_cachePrefix}$key';
      final timestampKey = '${_timestampPrefix}$key';
      
      // Serialize to JSON
      final jsonStr = jsonEncode(value);
      
      // Save both data and timestamp
      await _prefs?.setString(cacheKey, jsonStr);
      await _prefs?.setString(timestampKey, DateTime.now().toIso8601String());
      
      print('💾 [Cache] Saved: $key');
    } catch (e) {
      print('❌ [Cache] Error saving cache for $key: $e');
    }
  }

  /// Clear specific cache entry
  static Future<void> clear(String key) async {
    await init();
    if (_prefs == null) return;

    final cacheKey = '${_cachePrefix}$key';
    final timestampKey = '${_timestampPrefix}$key';
    
    await _prefs?.remove(cacheKey);
    await _prefs?.remove(timestampKey);
    
    print('🗑️ [Cache] Cleared: $key');
  }

  /// Clear all cache
  static Future<void> clearAll() async {
    await init();
    if (_prefs == null) return;

    try {
      final keys = _prefs!.getKeys().toList(); // Convert to list to avoid concurrent modification
      final keysToRemove = keys.where((key) => 
        key.startsWith(_cachePrefix) || key.startsWith(_timestampPrefix)
      ).toList();
      
      // Remove keys in batches to avoid blocking
      for (final key in keysToRemove) {
        _prefs?.remove(key);
      }
      
      print('🗑️ [Cache] Cleared all cache (${keysToRemove.length} keys)');
    } catch (e) {
      print('❌ [Cache] Error clearing cache: $e');
    }
  }

  /// Invalidate cache (mark as expired)
  static Future<void> invalidate(String key) async {
    await init();
    if (_prefs == null) return;

    final timestampKey = '${_timestampPrefix}$key';
    // Set timestamp to epoch to force expiry
    await _prefs?.setString(timestampKey, DateTime(1970).toIso8601String());
    
    print('⏰ [Cache] Invalidated: $key');
  }

  /// Check if cache exists and is valid
  static Future<bool> exists(String key) async {
    await init();
    if (_prefs == null) return false;

    final timestampKey = '${_timestampPrefix}$key';
    final timestampStr = _prefs?.getString(timestampKey);
    if (timestampStr == null) return false;

    try {
      final timestamp = DateTime.parse(timestampStr);
      final now = DateTime.now();
      final expiry = key.startsWith('user_') 
          ? const Duration(minutes: 5)
          : const Duration(minutes: 30);
      
      return now.difference(timestamp) <= expiry;
    } catch (e) {
      return false;
    }
  }

  /// Get cache size (approximate)
  static Future<int> getCacheSize() async {
    await init();
    if (_prefs == null) return 0;

    int size = 0;
    final keys = _prefs!.getKeys();
    for (final key in keys) {
      if (key.startsWith(_cachePrefix)) {
        final value = _prefs?.getString(key);
        if (value != null) {
          size += value.length;
        }
      }
    }
    return size;
  }
}

