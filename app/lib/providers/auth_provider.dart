import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../utils/auth_response.dart';
import '../utils/auth_session_gate.dart';
import 'cache_provider.dart';

// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  return FirebaseAuth.instance.currentUser;
});

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

class AuthService {
  final Ref _ref;

  AuthService(this._ref);

  // Check if user is authenticated
  bool get isAuthenticated {
    return FirebaseAuth.instance.currentUser != null;
  }

  // Get current user
  User? get currentUser {
    return FirebaseAuth.instance.currentUser;
  }

  // Logout
  Future<void> logout() async {
    try {
      // Clear API token
      final apiService = ApiService();
      apiService.init();
      await apiService.clearAuthToken();
      AuthSessionGate.instance.clear();
      
      // Clear all cache
      CacheProvider.clearAll();
      
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('Error logging out: $e');
      rethrow;
    }
  }

  // Get user data from backend
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final idToken = await user
          .getIdToken(false)
          .timeout(const Duration(seconds: 15));
      if (idToken == null) return null;

      final apiService = ApiService();
      apiService.init();
      await apiService.setAuthToken(idToken);

      final response = await apiService.getCurrentUser();
      if (AuthResponse.isSuccess(response)) {
        return AuthResponse.userData(response);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }
}

// User data provider - loads from cache first, then refreshes in background
final userDataProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  // Watch auth state to trigger refresh when user logs in/out
  final authState = ref.watch(authStateProvider);
  
  // Get current user from auth state
  final user = authState.value;
  
  if (user == null) {
    // Clear cache when logged out
    await CacheProvider.clear('user_data');
    return null;
  }

  // Try to load from cache first (instant)
  final cacheKey = 'user_data';
  final cachedData = await CacheProvider.get<Map<String, dynamic>>(cacheKey);
  
  if (cachedData != null) {
    print('⚡ [Auth] Loaded user data from cache');
    // Refresh in background (don't await)
    _refreshUserDataInBackground(user, cacheKey);
    return cachedData;
  }

  // No cache, fetch fresh data
  return await _fetchUserData(user, cacheKey);
});

/// Fetch user data from API
Future<Map<String, dynamic>?> _fetchUserData(
  dynamic user,
  String cacheKey,
) async {
  try {
    // Force refresh token to get latest user data
    final idToken = await user
        .getIdToken(false)
        .timeout(const Duration(seconds: 15));
    if (idToken == null) {
      print('⚠️ [Auth] No ID token available');
      return null;
    }

    final apiService = ApiService();
    apiService.init();
    await apiService.setAuthToken(idToken);

    // Clear cache before fetching to ensure fresh data
    await CacheProvider.clear(cacheKey);
    
    final response = await apiService.getCurrentUser();
    if (AuthResponse.isSuccess(response)) {
      final userData = AuthResponse.userData(response);
      if (userData != null) {
        print('✅ [Auth] User data fetched: role=${userData['role']}');
        await CacheProvider.set(cacheKey, userData);
        return userData;
      }
    }
    print('❌ [Auth] Failed to get user data');
    return null;
  } catch (e) {
    print('❌ [Auth] Error getting user data: $e');
    // Clear cache on error to force fresh fetch next time
    await CacheProvider.clear(cacheKey);
    return null;
  }
}

/// Refresh user data in background (non-blocking)
void _refreshUserDataInBackground(dynamic user, String cacheKey) {
  Future.microtask(() async {
    try {
      final userData = await _fetchUserData(user, cacheKey);
      if (userData != null) {
        print('🔄 [Auth] User data refreshed in background');
      }
    } catch (e) {
      print('⚠️ [Auth] Background refresh failed: $e');
    }
  });
}

