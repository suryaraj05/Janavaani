import 'package:dio/dio.dart';

/// Parse auth API responses — supports both legacy `{ success, data }` and `{ user }`.
class AuthResponse {
  static bool isSuccess(Response<dynamic> response) {
    if (response.statusCode != 200) return false;
    final data = response.data;
    if (data is! Map) return false;
    if (data['success'] == true) return true;
    if (data['user'] != null) return true;
    if (data['data'] != null) return true;
    return false;
  }

  static Map<String, dynamic>? userData(Response<dynamic> response) {
    final data = response.data;
    if (data is! Map) return null;
    if (data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data['user'] is Map) {
      return Map<String, dynamic>.from(data['user'] as Map);
    }
    return null;
  }

  static String errorMessage(Response<dynamic>? response, {String fallback = 'Request failed'}) {
    final data = response?.data;
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg != null) return msg.toString();
    }
    return fallback;
  }
}
