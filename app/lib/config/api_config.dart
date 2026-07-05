import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Resolves the intake-api base URL for the current platform.
///
/// Override at build time: `--dart-define=API_BASE_URL=http://192.168.1.5:8092`
class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const int _envPort = int.fromEnvironment('INTAKE_PORT', defaultValue: 8092);

  static const String localBaseUrl = 'http://localhost:8092';
  static const String androidEmulatorUrl = 'http://10.0.2.2:8092';
  static const String apiVersion = 'v1';

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://localhost:$_envPort';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$_envPort';
    }
    return 'http://localhost:$_envPort';
  }

  static const String health = '/health';
  static const String submissions = '/api/v1/submissions';
  static const String clusters = '/api/v1/clusters';
  static const String authRegister = '/api/v1/auth/register';
  static const String authLogin = '/api/v1/auth/login';

  // Legacy campus-connect endpoints (compile compat)
  static const String version = '/api/version';
  static const String aiAnalyze = '/api/v1/ai/analyze';
  static const String aiCheckDuplicates = '/api/v1/ai/check-duplicates';
  static const String grievances = '/api/v1/grievances';
  static const String authMe = '/api/v1/auth/me';
  static const String notifications = '/api/v1/notifications';
  static const String locationMarkers = '/api/v1/location/markers';
  static const String locationGeocode = '/api/v1/location/geocode';
  static const String locationRoute = '/api/v1/location/route';
  static const String config = '/api/v1/config';
  static const String campusLocations = '/api/v1/campus-locations';
  static const String campusLocationsNearby = '/api/v1/campus-locations/nearby';
  static const String optimizeRoutes = '/api/v1/grievances/optimize-routes';
  static const String users = '/api/v1/users';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
