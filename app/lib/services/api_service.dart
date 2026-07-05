import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';
import '../utils/auth_session_gate.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;
  String? _authToken;
  bool _initialized = false;

  static bool _isAuthBootstrapPath(String path) {
    return path.contains('/auth/register') ||
        path.contains('/auth/login') ||
        path.endsWith('/health') ||
        path.contains('/config');
  }

  void init() {
    if (_initialized) return;
    _initialized = true;

    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (kDebugMode) {
            final fullUrl = '${options.baseUrl}${options.path}';
            debugPrint('API ${options.method} $fullUrl');
          }

          // Register/login carry idToken in the body — do not force-refresh Firebase
          // here (getIdToken(true) often hangs on Flutter web right after sign-up).
          if (!_isAuthBootstrapPath(options.path)) {
            await _refreshTokenFromFirebase();
            final token = _authToken;
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('API ${response.statusCode} ${response.requestOptions.path}');
          }
          return handler.next(response);
        },
        onError: (error, handler) {
          if (kDebugMode) {
            debugPrint('API error ${error.type} ${error.requestOptions.path}');
            if (error.type == DioExceptionType.connectionError) {
              debugPrint('Backend unreachable at ${ApiConfig.baseUrl}');
            }
          }

          if (error.response?.statusCode == 401) {
            clearAuthToken();
          }
          return handler.next(error);
        },
      ),
    );

    // Load saved token
    _loadAuthToken();
  }

  Future<void> _loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('auth_token');
    if (_authToken != null && _authToken!.isNotEmpty) {
      AuthSessionGate.instance.activate();
    }
    await _refreshTokenFromFirebase();
  }

  Future<void> _refreshTokenFromFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final idToken = await user
            .getIdToken(false)
            .timeout(const Duration(seconds: 15));
        if (idToken != null && idToken.isNotEmpty) {
          _authToken = idToken;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', idToken);
        }
      }
      // Keep stored token when Firebase plugin session is still syncing on web.
    } catch (e) {
      if (kDebugMode) debugPrint('Token refresh skipped: $e');
    }
  }

  Future<void> setAuthToken(String token) async {
    _authToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearAuthToken() async {
    _authToken = null;
    AuthSessionGate.instance.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Health Check
  Future<Response> healthCheck() async {
    return await _dio.get(ApiConfig.health);
  }

  // AI Analysis
  Future<Response> analyzeGrievance({
    String? title,
    String? description,
    List<String> images = const [],
  }) async {
    return await _dio.post(
      ApiConfig.aiAnalyze,
      data: {
        'title': title ?? '',
        'description': description ?? '',
        'images': images,
      },
    );
  }

  // Check for duplicate grievances
  Future<Response> checkDuplicates({
    required String title,
    required String description,
    List<String> images = const [],
    double? latitude,
    double? longitude,
    List<Map<String, dynamic>> existingGrievances = const [],
  }) async {
    return await _dio.post(
      ApiConfig.aiCheckDuplicates,
      data: {
        'title': title,
        'description': description,
        'images': images,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'existingGrievances': existingGrievances,
      },
    );
  }

  // Auth
  Future<Response> register({
    required String idToken,
    required String displayName,
    required String role,
    String? department,
    String? phoneNumber,
    String? displayLocale,
  }) async {
    final data = {
      'idToken': idToken,
      'displayName': displayName,
      'role': role,
      'phoneNumber': phoneNumber ?? '',
      if (displayLocale != null) 'displayLocale': displayLocale,
    };

    if (department != null && department.isNotEmpty) {
      data['department'] = department;
    }

    return await _dio.post(
      ApiConfig.authRegister,
      data: data,
    );
  }

  Future<Response> login(String idToken) async {
    final response = await _dio.post(
      ApiConfig.authLogin,
      data: {'idToken': idToken},
    );
    
    // Save token on successful login
    if (response.statusCode == 200) {
      await setAuthToken(idToken);
    }
    
    return response;
  }

  Future<Response> getCurrentUser() async {
    return await _dio.get(ApiConfig.authMe);
  }

  Future<Response> updateProfile(Map<String, dynamic> updates) async {
    return await _dio.put(ApiConfig.authMe, data: updates);
  }

  // Grievances
  Future<Response> createGrievance({
    required String title,
    required String description,
    required List<String> departments,
    required String priority,
    String? location,
    List<String> images = const [],
    String? contactPhone,
    double? latitude,
    double? longitude,
  }) async {
    // Ensure we have a fresh token
    await _refreshTokenFromFirebase();
    
    final data = {
      'title': title.trim(),
      'description': description.trim(),
      'departments': departments,
      'priority': priority,
      'location': location?.trim() ?? '',
      'images': images,
      if (contactPhone != null && contactPhone.isNotEmpty) 'contactPhone': contactPhone.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
    
    print('📤 Creating grievance with data:');
    print('   Title: ${data['title']}');
    print('   Departments: ${data['departments']}');
    print('   Priority: ${data['priority']}');
    print('   Location: ${data['location']}');
    print('   Images count: ${images.length}');
    
    try {
      print('📤 Sending POST request to: ${ApiConfig.grievances}');
      print('📦 Request payload keys: ${data.keys.toList()}');
      print('📦 Request payload size: ${data.toString().length} bytes');
      
      final response = await _dio.post(
        ApiConfig.grievances,
        data: data,
      );
      print('✅ Grievance created successfully: ${response.statusCode}');
      print('📥 Response: ${response.data}');
      return response;
    } catch (e) {
      print('❌ Error creating grievance: $e');
      if (e is DioException) {
        print('   Error Type: ${e.type}');
        print('   Status: ${e.response?.statusCode}');
        print('   URL: ${e.requestOptions.baseUrl}${e.requestOptions.path}');
        print('   Request Data: ${e.requestOptions.data}');
        print('   Response Data: ${e.response?.data}');
        print('   Headers: ${e.requestOptions.headers}');
        
        // Log the full error for debugging
        if (e.response?.data != null) {
          print('   Full Error Response: ${e.response?.data}');
        }
      }
      rethrow; // Re-throw to let the caller handle it
    }
  }

  Future<Response> getGrievances({
    String? department,
    String? status,
    String? priority,
    String? submittedBy, // null = all, 'me' = current user, or specific UID
    int? limit,
  }) async {
    // Ensure token is refreshed before request (interceptor will also refresh)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _authToken == null) {
      await _refreshTokenFromFirebase();
    }
    
    final queryParams = <String, dynamic>{};
    if (department != null) queryParams['department'] = department;
    if (status != null) queryParams['status'] = status;
    if (priority != null) queryParams['priority'] = priority;
    // Only add submittedBy if explicitly set (not null)
    // null = get all grievances (community feed)
    // 'me' = get current user's grievances
    // specific UID = get that user's grievances
    if (submittedBy != null) {
      queryParams['submittedBy'] = submittedBy;
    }
    if (limit != null) queryParams['limit'] = limit;

    print('📋 Getting grievances with params: $queryParams');
    print('   submittedBy was: $submittedBy (null means get all)');
    print('   Final query params: $queryParams');
    
    final response = await _dio.get(
      ApiConfig.grievances,
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
    
    print('✅ Response received: ${response.statusCode}');
    print('   Count: ${response.data['count'] ?? response.data['data']?.length ?? 0}');
    if (response.data['data'] != null && (response.data['data'] as List).isNotEmpty) {
      print('   First grievance submittedBy: ${(response.data['data'] as List)[0]['submittedBy']}');
    }
    
    return response;
  }

  Future<Response> getGrievance(String id) async {
    return await _dio.get('${ApiConfig.grievances}/$id');
  }

  Future<Response> updateGrievance(
    String id, {
    String? title,
    String? description,
    String? location,
    String? contactPhone,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (location != null) data['location'] = location;
    if (contactPhone != null) data['contactPhone'] = contactPhone;

    return await _dio.put('${ApiConfig.grievances}/$id', data: data);
  }

  Future<Response> updateGrievanceStatus(
    String id, {
    String? status,
    String? priority,
    List<String>? afterPhotos,
  }) async {
    return await _dio.patch(
      '${ApiConfig.grievances}/$id/status',
      data: {
        if (status != null) 'status': status,
        if (priority != null) 'priority': priority,
        if (afterPhotos != null) 'afterPhotos': afterPhotos,
      },
    );
  }

  Future<Response> deleteGrievance(String id) async {
    await _refreshTokenFromFirebase();
    return await _dio.delete('${ApiConfig.grievances}/$id');
  }

  // Upvote
  Future<Response> upvoteGrievance(String id) async {
    await _refreshTokenFromFirebase();
    return await _dio.post('${ApiConfig.grievances}/$id/upvote');
  }

  // Comments
  Future<Response> getComments(String grievanceId) async {
    return await _dio.get('${ApiConfig.grievances}/$grievanceId/comments');
  }

  Future<Response> addComment(String grievanceId, String comment) async {
    return await _dio.post(
      '${ApiConfig.grievances}/$grievanceId/comments',
      data: {'comment': comment},
    );
  }

  // Notifications
  Future<Response> getNotifications({int? limit}) async {
    return await _dio.get(
      ApiConfig.notifications,
      queryParameters: limit != null ? {'limit': limit} : null,
    );
  }

  Future<Response> markNotificationAsRead(String id) async {
    return await _dio.put('${ApiConfig.notifications}/$id/read');
  }

  Future<Response> deleteNotification(String id) async {
    return await _dio.delete('${ApiConfig.notifications}/$id');
  }

  // Location
  Future<Response> getMapMarkers({
    String? status,
    String? department,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status;
    if (department != null) queryParams['department'] = department;

    return await _dio.get(
      ApiConfig.locationMarkers,
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );
  }

  Future<Response> geocodeAddress(String address) async {
    return await _dio.post(
      ApiConfig.locationGeocode,
      data: {'address': address},
    );
  }

  Future<Response> getRoute({
    required Map<String, double> from,
    required Map<String, double> to,
  }) async {
    return await _dio.post(
      ApiConfig.locationRoute,
      data: {
        'from': from,
        'to': to,
      },
    );
  }

  // Config
  Future<Response> getConfig() async {
    return await _dio.get(ApiConfig.config);
  }
  
  // Version Info
  Future<Response> getVersionInfo() async {
    return await _dio.get(ApiConfig.version);
  }

  // Users (Admin only)
  Future<Response> getUsers() async {
    return await _dio.get(ApiConfig.users);
  }

  // Campus Locations
  Future<Response> getCampusLocations() async {
    return await _dio.get(ApiConfig.campusLocations);
  }

  Future<Response> getNearbyCampusLocations({
    required double latitude,
    required double longitude,
    int maxDistance = 500,
  }) async {
    return await _dio.get(
      ApiConfig.campusLocationsNearby,
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'maxDistance': maxDistance,
      },
    );
  }

  Future<Response> createCampusLocation({
    required String name,
    String? description,
    required double latitude,
    required double longitude,
    String? category,
    String? icon,
  }) async {
    return await _dio.post(
      ApiConfig.campusLocations,
      data: {
        'name': name,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'category': category,
        'icon': icon,
      },
    );
  }

  Future<Response> updateCampusLocation(
    String id, {
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    String? category,
    String? icon,
  }) async {
    return await _dio.put(
      '${ApiConfig.campusLocations}/$id',
      data: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (category != null) 'category': category,
        if (icon != null) 'icon': icon,
      },
    );
  }

  Future<Response> deleteCampusLocation(String id) async {
    return await _dio.delete('${ApiConfig.campusLocations}/$id');
  }

  // Route Optimization (TSP)
  Future<Response> optimizeRoutes({
    required List<Map<String, dynamic>> grievances,
    Map<String, double>? startLocation,
    int maxDistance = 500,
  }) async {
    return await _dio.post(
      ApiConfig.optimizeRoutes,
      data: {
        'grievances': grievances,
        if (startLocation != null) 'startLocation': startLocation,
        'maxDistance': maxDistance,
      },
    );
  }

  // People's Priorities — submissions & clusters
  Future<Response> createSubmission({
    required Map<String, dynamic> draft,
    String? audioBase64,
    List<String>? imagesBase64,
  }) async {
    await _refreshTokenFromFirebase();
    return await _dio.post(
      ApiConfig.submissions,
      data: {
        'draft': draft,
        if (audioBase64 != null)
          'mediaBase64': {
            'audio': audioBase64,
            if (imagesBase64 != null) 'images': imagesBase64,
          }
        else if (imagesBase64 != null)
          'mediaBase64': {'images': imagesBase64},
      },
    );
  }

  Future<Response> getSubmissions({int? limit}) async {
    await _refreshTokenFromFirebase();
    return await _dio.get(
      ApiConfig.submissions,
      queryParameters: limit != null ? {'limit': limit} : null,
    );
  }

  Future<Response> getClusters() async {
    await _refreshTokenFromFirebase();
    return await _dio.get(ApiConfig.clusters);
  }
}

