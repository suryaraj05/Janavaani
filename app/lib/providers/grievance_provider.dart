import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/grievance.dart';
import '../services/api_service.dart';
import 'cache_provider.dart';
import 'dart:convert';

/// Provider for grievances list with instant cache loading
final grievancesProvider = FutureProvider.autoDispose<List<Grievance>>((ref) async {
  const cacheKey = 'grievances_list';
  
  // Try to load from cache first (instant)
  final cached = await CacheProvider.get<List<dynamic>>(cacheKey);
  if (cached != null) {
    try {
      final grievances = cached.map((json) => Grievance.fromJson(json)).toList();
      print('⚡ [Grievances] Loaded ${grievances.length} grievances from cache');
      
      // Refresh in background (don't await)
      _refreshGrievancesInBackground(cacheKey);
      
      return grievances;
    } catch (e) {
      print('⚠️ [Grievances] Error parsing cached data: $e');
      await CacheProvider.clear(cacheKey);
    }
  }
  
  // No cache, fetch fresh data
  return await _fetchGrievances(cacheKey);
});

/// Fetch grievances from API
Future<List<Grievance>> _fetchGrievances(String cacheKey) async {
  try {
    final apiService = ApiService();
    apiService.init();
    final response = await apiService.getGrievances(limit: 100);
    
    List<Grievance> grievances = [];
    if (response.data['success'] == true) {
      final List<dynamic> data = response.data['data'] ?? [];
      grievances = data.map((json) => Grievance.fromJson(json)).toList();
    } else if (response.data is List) {
      final List<dynamic> data = response.data;
      grievances = data.map((json) => Grievance.fromJson(json)).toList();
    }
    
    // Cache the result (convert to JSON-serializable format)
    final cacheData = grievances.map((g) => g.toJson()).toList();
    await CacheProvider.set(cacheKey, cacheData);
    
    print('✅ [Grievances] Fetched ${grievances.length} grievances from API');
    return grievances;
  } catch (e) {
    print('❌ [Grievances] Error loading: $e');
    rethrow;
  }
}

/// Refresh grievances in background (non-blocking)
void _refreshGrievancesInBackground(String cacheKey) {
  Future.microtask(() async {
    try {
      await _fetchGrievances(cacheKey);
      print('🔄 [Grievances] Refreshed in background');
    } catch (e) {
      print('⚠️ [Grievances] Background refresh failed: $e');
    }
  });
}

/// Provider for a single grievance by ID with instant cache loading
final grievanceProvider = FutureProvider.autoDispose.family<Grievance?, String>((ref, grievanceId) async {
  final cacheKey = 'grievance_$grievanceId';
  
  // Try to load from cache first (instant)
  final cached = await CacheProvider.get<Map<String, dynamic>>(cacheKey);
  if (cached != null) {
    try {
      final grievance = Grievance.fromJson(cached);
      print('⚡ [Grievance] Loaded $grievanceId from cache');
      
      // Refresh in background
      _refreshGrievanceInBackground(grievanceId, cacheKey);
      
      return grievance;
    } catch (e) {
      print('⚠️ [Grievance] Error parsing cached data: $e');
      await CacheProvider.clear(cacheKey);
    }
  }
  
  // No cache, fetch fresh data
  return await _fetchGrievance(grievanceId, cacheKey);
});

/// Fetch single grievance from API
Future<Grievance?> _fetchGrievance(String grievanceId, String cacheKey) async {
  try {
    final apiService = ApiService();
    apiService.init();
    final response = await apiService.getGrievance(grievanceId);
    
    if (response.data['success'] == true && response.data['data'] != null) {
      final grievance = Grievance.fromJson(response.data['data']);
      
      // Cache the result
      await CacheProvider.set(cacheKey, grievance.toJson());
      
      return grievance;
    }
    return null;
  } catch (e) {
    print('❌ [Grievance] Error loading: $e');
    return null;
  }
}

/// Refresh grievance in background
void _refreshGrievanceInBackground(String grievanceId, String cacheKey) {
  Future.microtask(() async {
    try {
      await _fetchGrievance(grievanceId, cacheKey);
      print('🔄 [Grievance] Refreshed $grievanceId in background');
    } catch (e) {
      print('⚠️ [Grievance] Background refresh failed: $e');
    }
  });
}

/// Provider for user's own grievances with instant cache loading
final myGrievancesProvider = FutureProvider.autoDispose<List<Grievance>>((ref) async {
  const cacheKey = 'my_grievances';
  
  // Try to load from cache first (instant)
  final cached = await CacheProvider.get<List<dynamic>>(cacheKey);
  if (cached != null) {
    try {
      final grievances = cached.map((json) => Grievance.fromJson(json)).toList();
      print('⚡ [MyGrievances] Loaded ${grievances.length} grievances from cache');
      
      // Refresh in background
      _refreshMyGrievancesInBackground(cacheKey);
      
      return grievances;
    } catch (e) {
      print('⚠️ [MyGrievances] Error parsing cached data: $e');
      await CacheProvider.clear(cacheKey);
    }
  }
  
  // No cache, fetch fresh data
  return await _fetchMyGrievances(cacheKey);
});

/// Fetch user's grievances from API
Future<List<Grievance>> _fetchMyGrievances(String cacheKey) async {
  try {
    final apiService = ApiService();
    apiService.init();
    final response = await apiService.getGrievances(limit: 100);
    
    List<Grievance> grievances = [];
    if (response.data['success'] == true) {
      final List<dynamic> data = response.data['data'] ?? [];
      grievances = data.map((json) => Grievance.fromJson(json)).toList();
    }
    
    // Cache the result
    final cacheData = grievances.map((g) => g.toJson()).toList();
    await CacheProvider.set(cacheKey, cacheData);
    
    return grievances;
  } catch (e) {
    print('❌ [MyGrievances] Error loading: $e');
    rethrow;
  }
}

/// Refresh user's grievances in background
void _refreshMyGrievancesInBackground(String cacheKey) {
  Future.microtask(() async {
    try {
      await _fetchMyGrievances(cacheKey);
      print('🔄 [MyGrievances] Refreshed in background');
    } catch (e) {
      print('⚠️ [MyGrievances] Background refresh failed: $e');
    }
  });
}

