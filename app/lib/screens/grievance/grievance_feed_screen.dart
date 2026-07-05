import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import '../../models/grievance.dart';
import '../../config/app_design_system.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../widgets/grievance_card.dart';
import '../../widgets/design_system/app_fab.dart';
import '../../widgets/design_system/app_empty_state.dart';
import '../../widgets/design_system/app_snackbar.dart';
import '../../widgets/design_system/app_chip.dart';
import '../../utils/feed_algorithm.dart';
import '../../providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GrievanceFeedScreen extends ConsumerStatefulWidget {
  const GrievanceFeedScreen({super.key});

  @override
  ConsumerState<GrievanceFeedScreen> createState() => _GrievanceFeedScreenState();
}

class _GrievanceFeedScreenState extends ConsumerState<GrievanceFeedScreen> {
  final ApiService _apiService = ApiService();
  List<Grievance> _grievances = [];
  List<Grievance> _filteredGrievances = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedStatus; // Filter by status
  final Map<String, bool> _upvotingGrievances = {}; // Track which grievances are being upvoted

  @override
  void initState() {
    super.initState();
    _apiService.init();
    _filteredGrievances = [];
    // Wait a bit for token to be ready
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
      // Ensure user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Please login to view grievances';
          _isLoading = false;
        });
        return;
      }

      // Get ALL grievances for community feed (don't filter by user)
      final response = await _apiService.getGrievances(
        limit: 50,
        submittedBy: null, // Explicitly set to null to get all grievances
      );
      
      // Handle both success format and direct array format
      List<Grievance> grievances = [];
      if (response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        grievances = data.map((json) => Grievance.fromJson(json)).toList();
      } else if (response.data is List) {
        // Handle direct array response
        final List<dynamic> data = response.data;
        grievances = data.map((json) => Grievance.fromJson(json)).toList();
      } else {
        setState(() {
          _error = response.data['message'] ?? 'Failed to load grievances';
          _isLoading = false;
        });
        return;
      }
      
      // Apply feed algorithm based on user role
      final userDataAsync = ref.read(userDataProvider);
      final userRole = userDataAsync.value?['role'] as String? ?? 'citizen';
      
      if (userRole == 'admin' || userRole == 'department') {
        grievances = FeedAlgorithm.sortForAdminDepartment(grievances);
      } else {
        grievances = FeedAlgorithm.sortForCitizens(grievances);
      }
      
      setState(() {
        _grievances = grievances;
        _applyFilter();
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

  void _applyFilter() {
    if (_selectedStatus == null || _selectedStatus!.isEmpty) {
      _filteredGrievances = _grievances;
    } else {
      _filteredGrievances = _grievances.where((g) => g.status == _selectedStatus).toList();
    }
  }

  bool _isUpvoted(Grievance grievance) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return grievance.upvotedBy.contains(user.uid);
  }

  Future<void> _handleUpvote(Grievance grievance) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppSnackbar.warning(context, 'Please login to upvote');
      return;
    }

    if (_upvotingGrievances[grievance.grievanceId] == true) return; // Prevent double-tap

    final index = _grievances.indexWhere((g) => g.grievanceId == grievance.grievanceId);
    if (index == -1) return;

    final wasUpvoted = _isUpvoted(grievance);
    final currentUpvotes = grievance.upvotedBy.length;

    // Optimistic update - update UI immediately
    setState(() {
      _upvotingGrievances[grievance.grievanceId] = true;
      final updatedGrievance = Grievance(
        grievanceId: _grievances[index].grievanceId,
        title: _grievances[index].title,
        description: _grievances[index].description,
        departments: _grievances[index].departments,
        status: _grievances[index].status,
        priority: _grievances[index].priority,
        location: _grievances[index].location,
        imageUrls: _grievances[index].imageUrls,
        submittedBy: _grievances[index].submittedBy,
        submittedByName: _grievances[index].submittedByName,
        contactPhone: _grievances[index].contactPhone,
        contactEmail: _grievances[index].contactEmail,
        createdAt: _grievances[index].createdAt,
        updatedAt: _grievances[index].updatedAt,
        resolvedAt: _grievances[index].resolvedAt,
        assignedTo: _grievances[index].assignedTo,
        latitude: _grievances[index].latitude,
        longitude: _grievances[index].longitude,
        upvotes: wasUpvoted ? currentUpvotes - 1 : currentUpvotes + 1,
        upvotedBy: wasUpvoted
            ? _grievances[index].upvotedBy.where((uid) => uid != user.uid).toList()
            : [..._grievances[index].upvotedBy, user.uid],
      );
      _grievances[index] = updatedGrievance;
    });

    try {
      final response = await _apiService.upvoteGrievance(grievance.grievanceId);
      
      if (response.data['success'] == true) {
        // Update with server response
        setState(() {
          final updatedGrievance = Grievance(
            grievanceId: _grievances[index].grievanceId,
            title: _grievances[index].title,
            description: _grievances[index].description,
            departments: _grievances[index].departments,
            status: _grievances[index].status,
            priority: _grievances[index].priority,
            location: _grievances[index].location,
            imageUrls: _grievances[index].imageUrls,
            submittedBy: _grievances[index].submittedBy,
            submittedByName: _grievances[index].submittedByName,
            contactPhone: _grievances[index].contactPhone,
            contactEmail: _grievances[index].contactEmail,
            createdAt: _grievances[index].createdAt,
            updatedAt: _grievances[index].updatedAt,
            resolvedAt: _grievances[index].resolvedAt,
            assignedTo: _grievances[index].assignedTo,
            latitude: _grievances[index].latitude,
            longitude: _grievances[index].longitude,
            upvotes: response.data['data']['upvotes'] ?? _grievances[index].upvotes,
            upvotedBy: response.data['data']['upvoted'] 
                ? [..._grievances[index].upvotedBy.where((uid) => uid != user.uid), user.uid]
                : _grievances[index].upvotedBy.where((uid) => uid != user.uid).toList(),
          );
          _grievances[index] = updatedGrievance;
        });
      } else {
        // Revert on error
        setState(() {
          final revertedGrievance = Grievance(
            grievanceId: _grievances[index].grievanceId,
            title: _grievances[index].title,
            description: _grievances[index].description,
            departments: _grievances[index].departments,
            status: _grievances[index].status,
            priority: _grievances[index].priority,
            location: _grievances[index].location,
            imageUrls: _grievances[index].imageUrls,
            submittedBy: _grievances[index].submittedBy,
            submittedByName: _grievances[index].submittedByName,
            contactPhone: _grievances[index].contactPhone,
            contactEmail: _grievances[index].contactEmail,
            createdAt: _grievances[index].createdAt,
            updatedAt: _grievances[index].updatedAt,
            resolvedAt: _grievances[index].resolvedAt,
            assignedTo: _grievances[index].assignedTo,
            latitude: _grievances[index].latitude,
            longitude: _grievances[index].longitude,
            upvotes: currentUpvotes,
            upvotedBy: wasUpvoted
                ? [..._grievances[index].upvotedBy, user.uid]
                : _grievances[index].upvotedBy.where((uid) => uid != user.uid).toList(),
          );
          _grievances[index] = revertedGrievance;
        });
        AppSnackbar.error(context, response.data['message'] ?? 'Failed to upvote');
      }
    } catch (e) {
      // Revert on error
      setState(() {
        final revertedGrievance = Grievance(
          grievanceId: _grievances[index].grievanceId,
          title: _grievances[index].title,
          description: _grievances[index].description,
          departments: _grievances[index].departments,
          status: _grievances[index].status,
          priority: _grievances[index].priority,
          location: _grievances[index].location,
          imageUrls: _grievances[index].imageUrls,
          submittedBy: _grievances[index].submittedBy,
          submittedByName: _grievances[index].submittedByName,
          contactPhone: _grievances[index].contactPhone,
          contactEmail: _grievances[index].contactEmail,
          createdAt: _grievances[index].createdAt,
          updatedAt: _grievances[index].updatedAt,
          resolvedAt: _grievances[index].resolvedAt,
          assignedTo: _grievances[index].assignedTo,
          latitude: _grievances[index].latitude,
          longitude: _grievances[index].longitude,
          upvotes: currentUpvotes,
          upvotedBy: wasUpvoted
              ? [..._grievances[index].upvotedBy, user.uid]
              : _grievances[index].upvotedBy.where((uid) => uid != user.uid).toList(),
        );
        _grievances[index] = revertedGrievance;
      });
      AppSnackbar.error(context, 'Error upvoting: $e');
    } finally {
      setState(() {
        _upvotingGrievances[grievance.grievanceId] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? ListView.builder(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            itemCount: 5,
            itemBuilder: (context, index) => const GrievanceCardShimmer(),
          )
        : _error != null
            ? AppEmptyState(
                icon: Icons.error_outline,
                title: 'Error Loading Grievances',
                message: _error!,
                actionLabel: 'Retry',
                onAction: _loadGrievances,
                iconColor: AppDesignSystem.errorColor,
              )
            : _grievances.isEmpty
                ? AppEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No grievances yet',
                    message: 'Report an issue to get started',
                    actionLabel: 'Submit Your First Grievance',
                    onAction: () => context.push('/submit-grievance'),
                  )
                : RefreshIndicator(
                    onRefresh: _loadGrievances,
                    color: AppDesignSystem.primaryColor,
                    child: Column(
                      children: [
                        // Status Filter Chips
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDesignSystem.spacingM,
                            vertical: AppDesignSystem.spacingS,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildStatusChip('All', null),
                                const SizedBox(width: AppDesignSystem.spacingS),
                                _buildStatusChip('Submitted', 'submitted'),
                                const SizedBox(width: AppDesignSystem.spacingS),
                                _buildStatusChip('In Progress', 'in_progress'),
                                const SizedBox(width: AppDesignSystem.spacingS),
                                _buildStatusChip('Resolved', 'resolved'),
                                const SizedBox(width: AppDesignSystem.spacingS),
                                _buildStatusChip('Closed', 'closed'),
                              ],
                            ),
                          ),
                        ),
                        // Grievances List
                        Expanded(
                          child: _filteredGrievances.isEmpty
                              ? AppEmptyState(
                                  icon: Icons.filter_alt_outlined,
                                  title: 'No grievances found',
                                  message: 'Try selecting a different status filter',
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppDesignSystem.spacingM,
                                  ),
                                  itemCount: _filteredGrievances.length,
                                  itemBuilder: (context, index) {
                                    final grievance = _filteredGrievances[index];
                                    return ModernGrievanceCard(
                                      grievance: grievance,
                                      onUpvote: () => _handleUpvote(grievance),
                                      isUpvoting: _upvotingGrievances[grievance.grievanceId] == true,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  );
  }

  Widget _buildStatusChip(String label, String? status) {
    final isSelected = _selectedStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStatus = status;
          _applyFilter();
        });
      },
      child: AppChip(
        label: label,
        backgroundColor: isSelected
            ? AppDesignSystem.primaryColor
            : AppDesignSystem.primaryColor.withOpacity(0.1),
        textColor: isSelected
            ? Colors.white
            : AppDesignSystem.primaryColor,
        isSelected: isSelected,
      ),
    );
  }

}
