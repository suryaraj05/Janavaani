import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/cache_provider.dart';

/// Utility functions for refreshing app data
class RefreshUtils {
  /// Refresh user profile after login/register (single attempt).
  static Future<void> refreshUserData(WidgetRef ref) async {
    ref.invalidate(userDataProvider);
  }
  
  /// Clear all cache and refresh user data
  static Future<void> fullRefresh(WidgetRef ref) async {
    await CacheProvider.clearAll();
    await refreshUserData(ref);
  }
}

