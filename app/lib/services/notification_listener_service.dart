import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'local_notification_service.dart';
import 'api_service.dart';

/// Service to listen for new notifications and trigger push notifications
class NotificationListenerService {
  static final NotificationListenerService _instance = NotificationListenerService._internal();
  factory NotificationListenerService() => _instance;
  NotificationListenerService._internal();

  final ApiService _apiService = ApiService();
  bool _isListening = false;
  List<String> _processedNotificationIds = [];
  Timer? _pollTimer;

  /// Start listening for new notifications
  void startListening() {
    if (_isListening) return;
    
    _isListening = true;
    _apiService.init();
    
    // Initial check
    _checkForNewNotifications();
    
    // Poll every 30 seconds for new notifications
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkForNewNotifications();
    });
    
    print('📱 [NotificationListener] Started listening for new notifications');
  }

  /// Stop listening for new notifications
  void stopListening() {
    _isListening = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    print('📱 [NotificationListener] Stopped listening');
  }

  /// Check for new notifications and show push notifications
  Future<void> _checkForNewNotifications() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final response = await _apiService.getNotifications();
      
      if (response.data['success'] == true) {
        final notifications = List<Map<String, dynamic>>.from(response.data['data'] ?? []);
        final unreadNotifications = notifications.where((n) => n['read'] != true).toList();
        
        // Find truly new notifications (not processed before)
        final newNotifications = unreadNotifications.where((n) {
          final id = n['id'] as String? ?? '';
          return !_processedNotificationIds.contains(id);
        }).toList();
        
        // Show push notification for each new notification
        for (var notif in newNotifications) {
          final notifId = notif['id'] as String? ?? '';
          if (notifId.isNotEmpty) {
            _processedNotificationIds.add(notifId);
            
            // Keep only last 100 IDs to prevent memory issues
            if (_processedNotificationIds.length > 100) {
              _processedNotificationIds.removeAt(0);
            }
            
            final grievanceId = notif['grievanceId'] as String?;
            final payload = grievanceId != null ? '/grievance/$grievanceId' : '/notifications';
            
            await LocalNotificationService().showNotification(
              id: notifId.hashCode.abs() % 100000,
              title: notif['title'] ?? 'New Notification',
              body: notif['message'] ?? '',
              payload: payload,
            );
            
            print('📱 [NotificationListener] Push notification sent: ${notif['title']}');
          }
        }
        
        // Update processed IDs with all current notifications
        _processedNotificationIds = notifications
            .map((n) => n['id'] as String? ?? '')
            .where((id) => id.isNotEmpty)
            .toList();
      }
    } catch (e) {
      print('⚠️ [NotificationListener] Error checking for new notifications: $e');
    }
  }

  /// Reset processed IDs (call when user logs out)
  void reset() {
    _processedNotificationIds.clear();
  }
}

