import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_service.dart';
import '../utils/auth_response.dart';
import '../utils/auth_session_gate.dart';

/// Complete backend login/register and navigate home immediately on web.
Future<void> completeAuthAndGoHome({
  required BuildContext context,
  required WidgetRef ref,
  required String idToken,
  required Future<dynamic> Function(String token) apiCall,
  required String failureFallback,
}) async {
  final response = await apiCall(idToken).timeout(
    const Duration(seconds: 25),
    onTimeout: () => throw Exception('Backend request timed out. Is intake-api running?'),
  );

  if (!AuthResponse.isSuccess(response)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthResponse.errorMessage(response, fallback: failureFallback)),
        ),
      );
    }
    return;
  }

  ApiService().init();
  await ApiService().setAuthToken(idToken);
  AuthSessionGate.instance.activate();

  if (!context.mounted) return;
  context.go('/home');
}
