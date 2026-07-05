import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_design_system.dart';
import '../../widgets/design_system/app_card.dart';
import '../../widgets/design_system/app_empty_state.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../services/api_service.dart';
import '../../services/local_notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiService.init();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getNotifications();
      
      if (response.data['success'] == true) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(response.data['data'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.data['message'] ?? 'Failed to load notifications';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading notifications: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _apiService.markNotificationAsRead(id);
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == id);
        if (index != -1) {
          _notifications[index]['read'] = true;
        }
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _apiService.deleteNotification(id);
      setState(() {
        _notifications.removeWhere((n) => n['id'] == id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting notification: $e')),
        );
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    
    try {
      DateTime date;
      if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else if (timestamp is Map && timestamp['_seconds'] != null) {
        date = DateTime.fromMillisecondsSinceEpoch(timestamp['_seconds'] * 1000);
      } else {
        return 'Just now';
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          if (difference.inMinutes == 0) {
            return 'Just now';
          }
          return '${difference.inMinutes}m ago';
        }
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM d, y').format(date);
      }
    } catch (e) {
      return 'Just now';
    }
  }

  IconData _getNotificationIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'status_update':
        return Icons.update;
      case 'assignment':
        return Icons.assignment;
      case 'resolution':
        return Icons.check_circle;
      case 'comment':
        return Icons.comment;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String? type) {
    switch (type?.toLowerCase()) {
      case 'status_update':
        return AppDesignSystem.statusInProgress;
      case 'assignment':
        return AppDesignSystem.statusAssigned;
      case 'resolution':
        return AppDesignSystem.statusResolved;
      case 'comment':
        return AppDesignSystem.primaryColor;
      default:
        return AppDesignSystem.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppDesignSystem.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_notifications.any((n) => n['read'] == false))
            TextButton(
              onPressed: () async {
                // Mark all as read
                for (var notification in _notifications) {
                  if (notification['read'] == false) {
                    await _markAsRead(notification['id']);
                  }
                }
              },
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? NotificationsShimmer()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        style: AppDesignSystem.bodyMedium.copyWith(
                          color: AppDesignSystem.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? AppEmptyState(
                      icon: Icons.notifications_none,
                      title: 'No notifications',
                      message: 'You don\'t have any notifications yet.',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          final isRead = notification['read'] == true;
                          final type = notification['type'];
                          final title = notification['title'] ?? 'Notification';
                          final message = notification['message'] ?? '';
                          final timestamp = notification['createdAt'];
                          final grievanceId = notification['grievanceId'];

                          return Dismissible(
                            key: Key(notification['id'] ?? index.toString()),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: AppDesignSystem.spacingM),
                              color: AppDesignSystem.errorColor,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (direction) {
                              _deleteNotification(notification['id']);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
                              decoration: BoxDecoration(
                                color: isRead 
                                    ? Colors.white 
                                    : AppDesignSystem.primaryColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
                                border: Border.all(
                                  color: isRead 
                                      ? Colors.grey[200]! 
                                      : AppDesignSystem.primaryColor.withOpacity(0.3),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                onTap: () {
                                  if (!isRead) {
                                    _markAsRead(notification['id']);
                                  }
                                  if (grievanceId != null) {
                                    context.push('/grievance/$grievanceId');
                                  }
                                },
                                borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
                                child: Padding(
                                  padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: _getNotificationColor(type).withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _getNotificationColor(type).withOpacity(0.3),
                                            width: 2,
                                          ),
                                        ),
                                        child: Icon(
                                          _getNotificationIcon(type),
                                          color: _getNotificationColor(type),
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: AppDesignSystem.spacingM),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    title,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                                                      color: Colors.black87,
                                                      letterSpacing: 0.2,
                                                    ),
                                                  ),
                                                ),
                                                if (!isRead)
                                                  Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                      color: AppDesignSystem.primaryColor,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: AppDesignSystem.primaryColor.withOpacity(0.5),
                                                          blurRadius: 4,
                                                          spreadRadius: 1,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            if (message.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                message,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black54,
                                                  height: 1.4,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _formatDate(timestamp),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
