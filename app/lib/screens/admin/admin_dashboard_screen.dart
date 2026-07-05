import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_design_system.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/design_system/app_card.dart';
import '../../widgets/design_system/app_button.dart';
import '../../widgets/design_system/app_chip.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../widgets/design_system/app_empty_state.dart';
import '../../services/api_service.dart';
import '../../models/grievance.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final ApiService _apiService = ApiService();
  List<Grievance> _grievances = [];
  bool _isLoading = true;
  String? _error;
  
  // Statistics
  int _totalGrievances = 0;
  int _pendingGrievances = 0;
  int _inProgressGrievances = 0;
  int _resolvedGrievances = 0;
  String _selectedFilter = 'all'; // all, pending, in_progress, resolved

  @override
  void initState() {
    super.initState();
    _apiService.init();
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadGrievances();
    });
  }

  Future<void> _loadGrievances() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getGrievances(limit: 100);
      
      List<Grievance> allGrievances = [];
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        allGrievances = data.map((json) => Grievance.fromJson(json)).toList();
      } else if (response.data is List) {
        final List<dynamic> data = response.data;
        allGrievances = data.map((json) => Grievance.fromJson(json)).toList();
      }

      // Calculate statistics
      _totalGrievances = allGrievances.length;
      _pendingGrievances = allGrievances.where((g) => g.status == 'submitted' || g.status == 'assigned').length;
      _inProgressGrievances = allGrievances.where((g) => g.status == 'in_progress').length;
      _resolvedGrievances = allGrievances.where((g) => g.status == 'resolved' || g.status == 'closed').length;

      // Filter grievances
      List<Grievance> filtered = allGrievances;
      if (_selectedFilter == 'pending') {
        filtered = allGrievances.where((g) => g.status == 'submitted' || g.status == 'assigned').toList();
      } else if (_selectedFilter == 'in_progress') {
        filtered = allGrievances.where((g) => g.status == 'in_progress').toList();
      } else if (_selectedFilter == 'resolved') {
        filtered = allGrievances.where((g) => g.status == 'resolved' || g.status == 'closed').toList();
      }

      setState(() {
        _grievances = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading grievances: ${e.toString()}';
        _isLoading = false;
      });
      print('Error loading grievances: $e');
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

  Future<void> _optimizeRoutes() async {
    try {
      // Get all pending/in-progress grievances with coordinates
      final grievancesWithCoords = _grievances
          .where((g) => 
              (g.status == 'submitted' || 
               g.status == 'assigned' || 
               g.status == 'in_progress') &&
              g.latitude != null && 
              g.longitude != null)
          .map((g) => {
                'grievanceId': g.grievanceId,
                'title': g.title,
                'latitude': g.latitude,
                'longitude': g.longitude,
                'status': g.status,
                'priority': g.priority,
              })
          .toList();

      if (grievancesWithCoords.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No grievances with valid coordinates found for optimization'),
            ),
          );
        }
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await _apiService.optimizeRoutes(
        grievances: grievancesWithCoords,
        maxDistance: 500,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        if (response.data['success'] == true) {
          final data = response.data['data'];
          final groups = data['groups'] as List;
          
          // Navigate to map with optimized routes
          context.push('/map?optimizedRoutes=true', extra: {
            'groups': groups,
            'summary': data['summary'],
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.data['message'] ?? 'Failed to optimize routes'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error optimizing routes: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundColor,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () => context.push('/admin/locations'),
            tooltip: 'Manage Locations',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGrievances,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Retry',
                        onPressed: _loadGrievances,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadGrievances,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Statistics Cards
                        Row(
                          children: [
                            Expanded(
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total',
                                      style: AppDesignSystem.bodySmall.copyWith(
                                        color: AppDesignSystem.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppDesignSystem.spacingXS),
                                    Text(
                                      '$_totalGrievances',
                                      style: AppDesignSystem.heading2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDesignSystem.spacingM),
                            Expanded(
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pending',
                                      style: AppDesignSystem.bodySmall.copyWith(
                                        color: AppDesignSystem.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppDesignSystem.spacingXS),
                                    Text(
                                      '$_pendingGrievances',
                                      style: AppDesignSystem.heading2.copyWith(
                                        color: AppDesignSystem.statusSubmitted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDesignSystem.spacingM),
                        Row(
                          children: [
                            Expanded(
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'In Progress',
                                      style: AppDesignSystem.bodySmall.copyWith(
                                        color: AppDesignSystem.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppDesignSystem.spacingXS),
                                    Text(
                                      '$_inProgressGrievances',
                                      style: AppDesignSystem.heading2.copyWith(
                                        color: AppDesignSystem.statusInProgress,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDesignSystem.spacingM),
                            Expanded(
                              child: AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Resolved',
                                      style: AppDesignSystem.bodySmall.copyWith(
                                        color: AppDesignSystem.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppDesignSystem.spacingXS),
                                    Text(
                                      '$_resolvedGrievances',
                                      style: AppDesignSystem.heading2.copyWith(
                                        color: AppDesignSystem.statusResolved,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDesignSystem.spacingL),
                        
                        // Quick Actions
                        Text(
                          'Quick Actions',
                          style: AppDesignSystem.heading4,
                        ),
                        const SizedBox(height: AppDesignSystem.spacingS),
                        Row(
                          children: [
                            Expanded(
                              child: AppCard(
                                child: InkWell(
                                  onTap: () => context.push('/admin/locations'),
                                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          color: AppDesignSystem.primaryColor,
                                          size: 32,
                                        ),
                                        const SizedBox(width: AppDesignSystem.spacingM),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Manage Locations',
                                                style: AppDesignSystem.bodyMedium.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                'Add campus landmarks',
                                                style: AppDesignSystem.bodySmall.copyWith(
                                                  color: AppDesignSystem.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: AppDesignSystem.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDesignSystem.spacingS),
                        Row(
                          children: [
                            Expanded(
                              child: AppCard(
                                child: InkWell(
                                  onTap: _optimizeRoutes,
                                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
                                  child: Padding(
                                    padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.route,
                                          color: AppDesignSystem.secondaryColor,
                                          size: 32,
                                        ),
                                        const SizedBox(width: AppDesignSystem.spacingM),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Optimize Routes',
                                                style: AppDesignSystem.bodyMedium.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              Text(
                                                'Get optimal route for grievances',
                                                style: AppDesignSystem.bodySmall.copyWith(
                                                  color: AppDesignSystem.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right,
                                          color: AppDesignSystem.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDesignSystem.spacingL),
                        
                        // Filter Chips
                        Text(
                          'Filters',
                          style: AppDesignSystem.heading4,
                        ),
                        const SizedBox(height: AppDesignSystem.spacingS),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('all', 'All'),
                              const SizedBox(width: AppDesignSystem.spacingS),
                              _buildFilterChip('pending', 'Pending'),
                              const SizedBox(width: AppDesignSystem.spacingS),
                              _buildFilterChip('in_progress', 'In Progress'),
                              const SizedBox(width: AppDesignSystem.spacingS),
                              _buildFilterChip('resolved', 'Resolved'),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDesignSystem.spacingL),
                        
                        // Grievances List
                        Text(
                          'Grievances (${_grievances.length})',
                          style: AppDesignSystem.heading4,
                        ),
                        const SizedBox(height: AppDesignSystem.spacingM),
                        _grievances.isEmpty
                            ? AppEmptyState(
                                icon: Icons.inbox_outlined,
                                title: 'No grievances',
                                message: 'No grievances match the selected filter.',
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _grievances.length,
                                itemBuilder: (context, index) {
                                  final grievance = _grievances[index];
                                  return _buildGrievanceCard(grievance);
                                },
                              ),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/admin'),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = value;
        });
        _loadGrievances();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingM,
          vertical: AppDesignSystem.spacingS,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppDesignSystem.primaryColor 
              : AppDesignSystem.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
          border: isSelected
              ? Border.all(color: AppDesignSystem.primaryColor, width: 1.5)
              : null,
        ),
        child: Text(
          label,
          style: AppDesignSystem.labelMedium.copyWith(
            color: isSelected 
                ? Colors.white 
                : AppDesignSystem.primaryColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildGrievanceCard(Grievance grievance) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
      child: InkWell(
        onTap: () => context.push('/grievance/${grievance.grievanceId}'),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        child: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      grievance.title,
                      style: AppDesignSystem.heading4,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppDesignSystem.spacingS),
                  AppChip(
                    label: grievance.priority.toUpperCase(),
                    backgroundColor: _getPriorityColor(grievance.priority).withOpacity(0.1),
                    textColor: _getPriorityColor(grievance.priority),
                  ),
                ],
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
              AppChip(
                label: grievance.status.replaceAll('_', ' ').toUpperCase(),
                backgroundColor: _getStatusColor(grievance.status).withOpacity(0.1),
                textColor: _getStatusColor(grievance.status),
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
              Text(
                grievance.description,
                style: AppDesignSystem.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: AppDesignSystem.textSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      grievance.location,
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: AppDesignSystem.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

