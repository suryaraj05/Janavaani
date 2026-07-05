import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../providers/auth_provider.dart';
import '../../utils/feed_algorithm.dart';

class DepartmentDashboardScreen extends ConsumerStatefulWidget {
  const DepartmentDashboardScreen({super.key});

  @override
  ConsumerState<DepartmentDashboardScreen> createState() => _DepartmentDashboardScreenState();
}

class _DepartmentDashboardScreenState extends ConsumerState<DepartmentDashboardScreen> {
  final ApiService _apiService = ApiService();
  List<Grievance> _grievances = [];
  bool _isLoading = true;
  String? _error;
  String? _userDepartment;
  
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
      _loadUserDepartment();
    });
  }

  Future<void> _loadUserDepartment() async {
    try {
      final userData = await ref.read(authServiceProvider).getUserData();
      setState(() {
        _userDepartment = userData?['department'] as String?;
      });
      _loadGrievances();
    } catch (e) {
      print('Error loading user department: $e');
      _loadGrievances();
    }
  }

  Future<void> _loadGrievances() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load all grievances first
      final response = await _apiService.getGrievances(limit: 100);
      
      List<Grievance> allGrievances = [];
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        allGrievances = data.map((json) => Grievance.fromJson(json)).toList();
      } else if (response.data is List) {
        final List<dynamic> data = response.data;
        allGrievances = data.map((json) => Grievance.fromJson(json)).toList();
      }

      // Filter by department if available
      if (_userDepartment != null && _userDepartment!.isNotEmpty) {
        allGrievances = allGrievances.where((g) => 
          g.departments.contains(_userDepartment!)
        ).toList();
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

      // Apply feed algorithm for department users
      filtered = FeedAlgorithm.sortForAdminDepartment(filtered);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Department Dashboard'),
            if (_userDepartment != null)
              Text(
                _userDepartment!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
          ],
        ),
        actions: [
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
                                message: _userDepartment != null
                                    ? 'No grievances assigned to ${_userDepartment}.'
                                    : 'No grievances match the selected filter.',
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
      bottomNavigationBar: const BottomNavBar(currentRoute: '/department'),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppDesignSystem.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = value;
          });
          _loadGrievances();
        },
        selectedColor: AppDesignSystem.primaryColor,
        backgroundColor: AppDesignSystem.cardColor,
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppDesignSystem.primaryColor : Colors.grey[300]!,
          width: 1,
        ),
        elevation: isSelected ? 2 : 0,
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

