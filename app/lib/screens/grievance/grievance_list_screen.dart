import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/api_service.dart';
import '../../models/grievance.dart';
import '../../config/theme.dart';
import '../../config/app_design_system.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../widgets/base64_image_widget.dart';

class GrievanceListScreen extends StatefulWidget {
  const GrievanceListScreen({super.key});

  @override
  State<GrievanceListScreen> createState() => _GrievanceListScreenState();
}

class _GrievanceListScreenState extends State<GrievanceListScreen> {
  final ApiService _apiService = ApiService();
  List<Grievance> _grievances = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiService.init();
    // Wait a bit for token to be ready
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadMyGrievances();
    });
  }

  Future<void> _loadMyGrievances() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Ensure user is available
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _error = 'Please login to view your grievances';
          _isLoading = false;
        });
        return;
      }

      // Load only user's grievances - use 'me' to let backend handle it
      final response = await _apiService.getGrievances(
        submittedBy: 'me', // Backend will convert 'me' to current user's UID
        limit: 50,
      );
      
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        setState(() {
          _grievances = data.map((json) => Grievance.fromJson(json)).toList();
          _isLoading = false;
        });
      } else if (response.data is List) {
        final List<dynamic> data = response.data;
        setState(() {
          _grievances = data.map((json) => Grievance.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.data['message'] ?? 'Failed to load grievances';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading grievances: ${e.toString()}';
        _isLoading = false;
      });
      print('Error loading my grievances: $e');
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return AppDesignSystem.priorityUrgent;
      case 'high':
        return AppDesignSystem.priorityHigh;
      case 'medium':
        return AppDesignSystem.priorityMedium;
      case 'low':
        return AppDesignSystem.priorityLow;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return AppDesignSystem.statusSubmitted;
      case 'assigned':
        return AppDesignSystem.statusAssigned;
      case 'in_progress':
        return AppDesignSystem.statusInProgress;
      case 'resolved':
        return AppDesignSystem.statusResolved;
      case 'closed':
        return AppDesignSystem.statusClosed;
      case 'rejected':
        return AppDesignSystem.statusRejected;
      default:
        return Colors.grey;
    }
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Recently';
    
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Grievances',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              'Track your submitted issues',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMyGrievances,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 5,
                itemBuilder: (context, index) => const GrievanceCardShimmer(),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadMyGrievances,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _grievances.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No grievances yet',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Report an issue to get started',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => context.push('/submit-grievance'),
                              icon: const Icon(Icons.add),
                              label: const Text('Submit Your First Grievance'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMyGrievances,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _grievances.length,
                          itemBuilder: (context, index) {
                            final grievance = _grievances[index];
                            return _buildGrievanceCard(grievance);
                          },
                        ),
                      ),
      ),
      bottomNavigationBar: BottomNavBar(currentRoute: '/grievances'),
    );
  }

  Widget _buildGrievanceCard(Grievance grievance) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () => context.push('/grievance/${grievance.grievanceId}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and Priority
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      grievance.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(grievance.priority).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      grievance.priority.toUpperCase(),
                      style: TextStyle(
                        color: _getPriorityColor(grievance.priority),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(grievance.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  grievance.status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(grievance.status),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Description
              Text(
                grievance.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Departments
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: grievance.departments.take(2).map((dept) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          dept.length > 20 ? '${dept.substring(0, 20)}...' : dept,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              if (grievance.departments.length > 2)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '+${grievance.departments.length - 2} more',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              const SizedBox(height: 12),

              // Location and Time
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      grievance.location.length > 30
                          ? '${grievance.location.substring(0, 30)}...'
                          : grievance.location,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeAgo(grievance.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),

              // Images
              if (grievance.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: grievance.imageUrls.length > 3 ? 3 : grievance.imageUrls.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: grievance.imageUrls[index].startsWith('data:image')
                              ? Base64ImageWidget(
                                  imageUrl: grievance.imageUrls[index],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                )
                              : Image.network(
                                  grievance.imageUrls[index],
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ),
                if (grievance.imageUrls.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '+${grievance.imageUrls.length - 3} more images',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
