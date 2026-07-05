import 'dart:async' show TimeoutException, unawaited;

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint, kIsWeb;

import '../config/firebase_config.dart';

/// Result of email/password auth — always includes an ID token for the backend.
class AuthSession {
  const AuthSession({required this.idToken, this.user});

  final String idToken;
  final User? user;
}

/// Firebase email/password auth.
///
/// **Web:** REST API first (SDK [createUserWithEmailAndPassword] freezes the browser tab).
/// **Mobile:** Firebase Auth SDK.
class FirebaseAuthHelper {
  static const Duration _opTimeout = Duration(seconds: 20);
  static const String _identityBase =
      'https://identitytoolkit.googleapis.com/v1';

  static Future<AuthSession> registerEmail({
    required String email,
    required String password,
  }) async {
    if (kIsWeb) {
      return _webRestAuth(
        endpoint: 'accounts:signUp',
        email: email,
        password: password,
      );
    }

    final user = await _pluginCreateUser(email: email, password: password);
    final idToken = await idTokenFor(user);
    return AuthSession(idToken: idToken, user: user);
  }

  static Future<AuthSession> signInEmail({
    required String email,
    required String password,
  }) async {
    if (kIsWeb) {
      return _webRestAuth(
        endpoint: 'accounts:signInWithPassword',
        email: email,
        password: password,
      );
    }

    final user = await _pluginSignIn(email: email, password: password);
    final idToken = await idTokenFor(user);
    return AuthSession(idToken: idToken, user: user);
  }

  static Future<AuthSession> _webRestAuth({
    required String endpoint,
    required String email,
    required String password,
  }) async {
    final apiKey = DefaultFirebaseOptions.web.apiKey;
    final dio = Dio(
      BaseOptions(
        connectTimeout: _opTimeout,
        receiveTimeout: _opTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );

    try {
      final res = await dio.post<Map<String, dynamic>>(
        '$_identityBase/$endpoint?key=$apiKey',
        data: {
          'email': email,
          'password': password,
          'returnSecureToken': true,
        },
      );
      final idToken = res.data?['idToken'] as String?;
      if (idToken == null || idToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Authentication succeeded but no token was returned.',
        );
      }

      // Sync Firebase plugin session in background — never block UI on web.
      unawaited(_syncPluginSessionBackground(email, password));

      return AuthSession(
        idToken: idToken,
        user: FirebaseAuth.instance.currentUser,
      );
    } on DioException catch (e) {
      throw _mapRestError(e);
    }
  }

  static Future<void> _syncPluginSessionBackground(
    String email,
    String password,
  ) async {
    if (FirebaseAuth.instance.currentUser != null) return;
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      if (kDebugMode) debugPrint('Background plugin session sync: $e');
    }
  }

  static FirebaseAuthException _mapRestError(DioException e) {
    final err = e.response?.data;
    if (err is Map && err['error'] is Map) {
      final error = err['error'] as Map;
      final message = (error['message'] as String?) ?? 'Authentication failed';
      return FirebaseAuthException(
        code: _restCodeToAuthCode(message),
        message: _restMessage(message),
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return FirebaseAuthException(
        code: 'timeout',
        message: 'Connection timed out. Check your network and try again.',
      );
    }
    return FirebaseAuthException(
      code: 'network-request-failed',
      message: e.message ?? 'Network error during authentication.',
    );
  }

  static String _restCodeToAuthCode(String restMessage) {
    switch (restMessage) {
      case 'EMAIL_EXISTS':
        return 'email-already-in-use';
      case 'OPERATION_NOT_ALLOWED':
        return 'operation-not-allowed';
      case 'INVALID_EMAIL':
        return 'invalid-email';
      case 'WEAK_PASSWORD':
      case 'PASSWORD_DOES_NOT_MEET_REQUIREMENTS':
        return 'weak-password';
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'wrong-password';
      case 'USER_DISABLED':
        return 'user-disabled';
      default:
        return 'unknown';
    }
  }

  static String _restMessage(String restMessage) {
    switch (restMessage) {
      case 'EMAIL_EXISTS':
        return 'This email is already registered. Try logging in instead.';
      case 'OPERATION_NOT_ALLOWED':
        return 'Email/password sign-in is disabled in Firebase Console → Authentication → Sign-in method.';
      case 'INVALID_EMAIL':
        return 'Invalid email address.';
      case 'WEAK_PASSWORD':
      case 'PASSWORD_DOES_NOT_MEET_REQUIREMENTS':
        return 'Password is too weak. Use at least 6 characters.';
      case 'INVALID_PASSWORD':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect email or password.';
      default:
        return restMessage.replaceAll('_', ' ').toLowerCase();
    }
  }

  static Future<User> _pluginCreateUser({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(_opTimeout);
      final user = cred.user;
      if (user != null) return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') rethrow;
      final recovered = _currentUserIfEmailMatches(email);
      if (recovered != null) return recovered;
      rethrow;
    } catch (e) {
      final recovered = _currentUserIfEmailMatches(email);
      if (recovered != null) return recovered;
      if (e is TimeoutException) {
        throw FirebaseAuthException(
          code: 'timeout',
          message: 'Registration timed out. Check your connection and try again.',
        );
      }
      rethrow;
    }

    final recovered = _currentUserIfEmailMatches(email);
    if (recovered != null) return recovered;
    throw FirebaseAuthException(
      code: 'user-not-found',
      message: 'Account creation failed. Please try again.',
    );
  }

  static Future<User> _pluginSignIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(_opTimeout);
      final user = cred.user;
      if (user != null) return user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      final recovered = _currentUserIfEmailMatches(email);
      if (recovered != null) return recovered;
      if (e is TimeoutException) {
        throw FirebaseAuthException(
          code: 'timeout',
          message: 'Sign-in timed out. Check your connection and try again.',
        );
      }
      rethrow;
    }

    final recovered = _currentUserIfEmailMatches(email);
    if (recovered != null) return recovered;
    throw FirebaseAuthException(
      code: 'invalid-credential',
      message: 'Sign-in failed. Please try again.',
    );
  }

  static User? _currentUserIfEmailMatches(String email) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email?.toLowerCase() == email.toLowerCase()) {
      return user;
    }
    return null;
  }

  static Future<String> idTokenFor(User user) async {
    final token = await user.getIdToken(false).timeout(_opTimeout);
    if (token == null || token.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-credential',
        message: 'Could not obtain sign-in token. Try logging in.',
      );
    }
    return token;
  }

  static Future<void> tryUpdateDisplayName(User user, String name) async {
    try {
      await user.updateDisplayName(name.trim()).timeout(const Duration(seconds: 8));
    } catch (_) {
      // Non-fatal — backend stores displayName from register payload.
    }
  }
}
