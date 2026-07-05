import 'package:dio/dio.dart';
import '../config/api_config.dart';

/// Service to fetch dynamic configuration from backend
class ConfigService {
  static final ConfigService _instance = ConfigService._internal();
  factory ConfigService() => _instance;
  ConfigService._internal();

  List<String>? _departments;
  List<String>? _priorities;
  List<String>? _statuses;
  bool _isLoaded = false;

  /// Fetch configuration from backend
  Future<void> loadConfig() async {
    if (_isLoaded) return;

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: ApiConfig.connectTimeout,
          receiveTimeout: ApiConfig.receiveTimeout,
        ),
      );
      
      final response = await dio.get(ApiConfig.config);
      
      if (response.data['success'] == true) {
        final data = response.data['data'];
        _departments = List<String>.from(data['departments'] ?? []);
        _priorities = List<String>.from(data['priorities'] ?? []);
        _statuses = List<String>.from(data['statuses'] ?? []);
        _isLoaded = true;
      } else {
        throw Exception('Failed to load config');
      }
    } catch (e) {
      // Use fallback values on error
      print('⚠️ Failed to load config from backend, using fallback values: $e');
      _departments = [
        'Municipal Cleanliness',
        'Electrical Department',
        'Water Department',
        'Roads & Infrastructure',
        'Health & Sanitation',
      ];
      _priorities = ['low', 'medium', 'high', 'urgent'];
      _statuses = [
        'submitted',
        'assigned',
        'in_progress',
        'resolved',
        'closed',
        'rejected',
      ];
      _isLoaded = true;
    }
  }

  /// Get departments (loads if not already loaded)
  Future<List<String>> getDepartments() async {
    if (!_isLoaded) await loadConfig();
    return _departments ?? [];
  }

  /// Get priorities (loads if not already loaded)
  Future<List<String>> getPriorities() async {
    if (!_isLoaded) await loadConfig();
    return _priorities ?? [];
  }

  /// Get statuses (loads if not already loaded)
  Future<List<String>> getStatuses() async {
    if (!_isLoaded) await loadConfig();
    return _statuses ?? [];
  }

  /// Refresh configuration from backend
  Future<void> refresh() async {
    _isLoaded = false;
    await loadConfig();
  }
}

