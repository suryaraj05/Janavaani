import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/api_service.dart';
import '../../models/grievance.dart';
import '../../config/app_design_system.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/shimmer_widgets.dart';
import '../../widgets/base64_image_widget.dart';
import '../../widgets/design_system/app_card.dart';
import '../../widgets/design_system/app_chip.dart';
import '../../widgets/design_system/app_button.dart';
import '../../widgets/design_system/app_empty_state.dart';
import '../../widgets/design_system/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/resolve_grievance_dialog.dart';
import '../../widgets/update_status_dialog.dart';

class GrievanceDetailScreen extends ConsumerStatefulWidget {
  final String grievanceId;
  
  const GrievanceDetailScreen({
    super.key,
    required this.grievanceId,
  });

  @override
  ConsumerState<GrievanceDetailScreen> createState() => _GrievanceDetailScreenState();
}

class _GrievanceDetailScreenState extends ConsumerState<GrievanceDetailScreen> {
  final ApiService _apiService = ApiService();
  Grievance? _grievance;
  bool _isLoading = true;
  String? _error;
  bool _isUpvoting = false;
  bool _isUpvoted = false;
  int _upvoteCount = 0;

  @override
  void initState() {
    super.initState();
    _apiService.init();
    _loadGrievance();
  }

  Future<void> _loadGrievance() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getGrievance(widget.grievanceId);
      
      if (response.data['success'] == true) {
        final grievance = Grievance.fromJson(response.data['data']);
        final user = FirebaseAuth.instance.currentUser;
        setState(() {
          _grievance = grievance;
          _isUpvoted = user != null && grievance.upvotedBy.contains(user.uid);
          _upvoteCount = grievance.upvotedBy.length;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response.data['message'] ?? 'Failed to load grievance';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading grievance: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleUpvote() async {
    if (_grievance == null) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      AppSnackbar.warning(context, 'Please login to upvote');
      return;
    }

    if (_isUpvoting) return;

    // Optimistic update - update UI immediately
    setState(() {
      _isUpvoting = true;
      _isUpvoted = !_isUpvoted;
      _upvoteCount = _isUpvoted ? _upvoteCount + 1 : _upvoteCount - 1;
    });

    try {
      final response = await _apiService.upvoteGrievance(_grievance!.grievanceId);
      
      if (response.data['success'] == true) {
        // Update with server response
        setState(() {
          _upvoteCount = response.data['data']['upvotes'] ?? _upvoteCount;
          _isUpvoted = response.data['data']['upvoted'] ?? _isUpvoted;
        });
      } else {
        // Revert on error
        setState(() {
          _isUpvoted = !_isUpvoted;
          _upvoteCount = _isUpvoted ? _upvoteCount - 1 : _upvoteCount + 1;
        });
        AppSnackbar.error(context, response.data['message'] ?? 'Failed to upvote');
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isUpvoted = !_isUpvoted;
        _upvoteCount = _isUpvoted ? _upvoteCount - 1 : _upvoteCount + 1;
      });
      AppSnackbar.error(context, 'Error upvoting: $e');
    } finally {
      setState(() {
        _isUpvoting = false;
      });
    }
  }

  PriorityLevel _getPriorityEnum(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return PriorityLevel.urgent;
      case 'high':
        return PriorityLevel.high;
      case 'medium':
        return PriorityLevel.medium;
      case 'low':
        return PriorityLevel.low;
      default:
        return PriorityLevel.medium;
    }
  }

  GrievanceStatus _getStatusEnum(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return GrievanceStatus.submitted;
      case 'in_progress':
      case 'in-progress':
        return GrievanceStatus.inProgress;
      case 'resolved':
        return GrievanceStatus.resolved;
      case 'closed':
        return GrievanceStatus.closed;
      case 'rejected':
        return GrievanceStatus.rejected;
      default:
        return GrievanceStatus.submitted;
    }
  }

  String _formatDateTime(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundColor,
      appBar: AppBar(
        title: const Text('Grievance Details'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGrievance,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const GrievanceDetailShimmer()
            : _error != null
                ? AppEmptyState(
                    icon: Icons.error_outline,
                    title: 'Error Loading Grievance',
                    message: _error!,
                    actionLabel: 'Retry',
                    onAction: _loadGrievance,
                    iconColor: AppDesignSystem.errorColor,
                  )
                : _grievance == null
                    ? AppEmptyState(
                        icon: Icons.inbox_outlined,
                        title: 'Grievance not found',
                        message: 'The grievance you are looking for does not exist',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadGrievance,
                        color: AppDesignSystem.primaryColor,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and Priority
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _grievance!.title,
                                      style: AppDesignSystem.heading2,
                                    ),
                                  ),
                                  const SizedBox(width: AppDesignSystem.spacingS),
                                  AppChip.priority(
                                    label: _grievance!.priority.toUpperCase(),
                                    priority: _getPriorityEnum(_grievance!.priority),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDesignSystem.spacingM),

                              // Status
                              AppChip.status(
                                label: _grievance!.status.replaceAll('_', ' ').toUpperCase(),
                                status: _getStatusEnum(_grievance!.status),
                              ),
                              const SizedBox(height: AppDesignSystem.spacingL),

                              // Description
                              AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Description',
                                      style: AppDesignSystem.heading4,
                                    ),
                                    const SizedBox(height: AppDesignSystem.spacingM),
                                    Text(
                                      _grievance!.description,
                                      style: AppDesignSystem.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppDesignSystem.spacingM),

                              // Departments
                              AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Departments',
                                      style: AppDesignSystem.heading4,
                                    ),
                                    const SizedBox(height: AppDesignSystem.spacingM),
                                    Wrap(
                                      spacing: AppDesignSystem.spacingS,
                                      runSpacing: AppDesignSystem.spacingS,
                                      children: _grievance!.departments.map((dept) {
                                        return AppChip.category(
                                          label: dept,
                                          category: dept,
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppDesignSystem.spacingM),

                              // Location
                              AppCard(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      color: AppDesignSystem.primaryColor,
                                    ),
                                    const SizedBox(width: AppDesignSystem.spacingM),
                                    Expanded(
                                      child: Text(
                                        _grievance!.location,
                                        style: AppDesignSystem.bodyMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Before/After Images for Resolved, or regular Images for others
                              if (_grievance!.status == 'resolved' || _grievance!.status == 'closed') ...[
                                // Before/After View
                                if (_grievance!.imageUrls.isNotEmpty || _grievance!.afterPhotos.isNotEmpty) ...[
                                  _buildBeforeAfterView(),
                                  const SizedBox(height: 16),
                                ],
                              ] else ...[
                                // Regular Images View
                                if (_grievance!.imageUrls.isNotEmpty) ...[
                                  _buildImagesView('Images (${_grievance!.imageUrls.length})', _grievance!.imageUrls),
                                  const SizedBox(height: 16),
                                ],
                              ],

                              // Status Timeline (for resolved problems)
                              if ((_grievance!.status == 'resolved' || _grievance!.status == 'closed') && 
                                  _grievance!.statusHistory != null && 
                                  _grievance!.statusHistory!.isNotEmpty) ...[
                                _buildStatusTimeline(),
                                const SizedBox(height: 16),
                              ],

                              // Metadata
                              Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey[200]!),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Details',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildDetailRow(Icons.person, 'Submitted by', _grievance!.submittedByName),
                                      _buildDetailRow(Icons.access_time, 'Created', _formatDateTime(_grievance!.createdAt)),
                                      if (_grievance!.updatedAt != _grievance!.createdAt)
                                        _buildDetailRow(Icons.update, 'Last updated', _formatDateTime(_grievance!.updatedAt)),
                                      if (_grievance!.resolvedAt != null)
                                        _buildDetailRow(Icons.check_circle, 'Resolved', _formatDateTime(_grievance!.resolvedAt)),
                                      if (_grievance!.contactPhone.isNotEmpty)
                                        _buildDetailRow(Icons.phone, 'Contact', _grievance!.contactPhone),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Action Buttons - Different for admin/department vs citizen
                              _buildActionButtons(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
      ),
      bottomNavigationBar: BottomNavBar(currentRoute: '/home'),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final userDataAsync = ref.watch(userDataProvider);
    final userRole = userDataAsync.value?['role'] as String? ?? 'citizen';
    final isResolved = _grievance != null && 
        (_grievance!.status == 'resolved' || _grievance!.status == 'closed');
    
    // For admin and department - show action buttons
    if (userRole == 'admin' || userRole == 'department') {
      return Column(
        children: [
          // Status update buttons for department
          if (userRole == 'department' && _grievance != null) ...[
            // Show status update dialog button for all statuses
            AppButton(
              label: 'Update Status',
              onPressed: () => _showStatusUpdateDialog(),
              icon: Icons.update,
            ),
            const SizedBox(height: AppDesignSystem.spacingS),
            // Quick action buttons for common statuses
            if (_grievance!.status == 'submitted' || _grievance!.status == 'assigned') ...[
              AppButton(
                label: 'Start Working',
                onPressed: () => _updateStatus('in_progress'),
                icon: Icons.play_arrow,
                type: AppButtonType.secondary,
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
            ],
            if (_grievance!.status == 'in_progress') ...[
              AppButton(
                label: 'Resolve Issue',
                onPressed: () => _showResolveDialog(),
                icon: Icons.check_circle,
                backgroundColor: AppDesignSystem.statusResolved,
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
            ],
          ],
          // Admin actions
          if (userRole == 'admin' && _grievance != null) ...[
            AppButton(
              label: 'Assign to Department',
              onPressed: () => _assignToDepartment(),
              icon: Icons.assignment,
            ),
            const SizedBox(height: AppDesignSystem.spacingS),
            AppButton(
              label: 'Update Status',
              onPressed: () => _showStatusUpdateDialog(),
              icon: Icons.update,
              type: AppButtonType.secondary,
            ),
            const SizedBox(height: AppDesignSystem.spacingS),
            if (!isResolved) ...[
              AppButton(
                label: 'Mark as Resolved',
                onPressed: () => _updateStatus('resolved'),
                icon: Icons.check_circle,
                backgroundColor: AppDesignSystem.statusResolved,
              ),
            ],
          ],
        ],
      );
    }
    
    // For citizens - show upvote button (disabled for resolved) or revive button
    if (isResolved) {
      // Show Revive button for resolved problems
      return Column(
        children: [
          AppButton(
            label: 'Revive This Issue',
            onPressed: () => _reviveGrievance(),
            icon: Icons.refresh,
            backgroundColor: Colors.orange,
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          // Show disabled upvote button to show count
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: null,
              icon: Icon(
                Icons.trending_up_outlined,
                color: Colors.grey[400],
              ),
              label: Text(
                'Resolved • $_upvoteCount upvotes',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[200],
                foregroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    // Regular upvote button for active issues
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isUpvoting ? null : _handleUpvote,
        icon: Icon(
          _isUpvoted ? Icons.trending_up : Icons.trending_up_outlined,
          color: _isUpvoted ? Colors.white : AppDesignSystem.primaryColor,
        ),
        label: Text(
          '${_isUpvoted ? 'Pushing' : 'Push'} This Issue • $_upvoteCount',
          style: TextStyle(
            color: _isUpvoted ? Colors.white : AppDesignSystem.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isUpvoted ? AppDesignSystem.primaryColor : Colors.white,
          foregroundColor: _isUpvoted ? Colors.white : AppDesignSystem.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _isUpvoted ? AppDesignSystem.primaryColor : AppDesignSystem.primaryColor,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateStatus(String status) async {
    if (_grievance == null) return;
    
    try {
      final response = await _apiService.updateGrievanceStatus(
        _grievance!.grievanceId,
        status: status,
      );
      
      if (response.data['success'] == true) {
        AppSnackbar.success(context, 'Status updated successfully');
        _loadGrievance();
      } else {
        AppSnackbar.error(context, response.data['message'] ?? 'Failed to update status');
      }
    } catch (e) {
      AppSnackbar.error(context, 'Error updating status: $e');
    }
  }

  Future<void> _showResolveDialog() async {
    if (_grievance == null) return;
    
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => ResolveGrievanceDialog(
        grievanceId: _grievance!.grievanceId,
        beforePhotos: _grievance!.imageUrls,
      ),
    );
    
    if (result != null && result.isNotEmpty) {
      // Update grievance status with after photos
      try {
        final response = await _apiService.updateGrievanceStatus(
          _grievance!.grievanceId,
          status: 'resolved',
          afterPhotos: result,
        );
        
        if (response.data['success'] == true) {
          AppSnackbar.success(context, 'Grievance marked as resolved');
          _loadGrievance();
        } else {
          AppSnackbar.error(context, response.data['message'] ?? 'Failed to resolve grievance');
        }
      } catch (e) {
        AppSnackbar.error(context, 'Error resolving grievance: $e');
      }
    }
  }

  Future<void> _assignToDepartment() async {
    // TODO: Implement department assignment dialog
    AppSnackbar.info(context, 'Department assignment feature coming soon');
  }

  Future<void> _showStatusUpdateDialog() async {
    if (_grievance == null) return;
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => UpdateStatusDialog(
        currentStatus: _grievance!.status,
      ),
    );
    
    if (result != null && result != _grievance!.status) {
      await _updateStatus(result);
    }
  }

  Future<void> _reviveGrievance() async {
    if (_grievance == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revive Issue'),
        content: const Text(
          'Are you sure you want to revive this issue? It will be reopened and assigned to the relevant department.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revive'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        final response = await _apiService.updateGrievanceStatus(
          _grievance!.grievanceId,
          status: 'submitted',
        );
        
        if (response.data['success'] == true) {
          AppSnackbar.success(context, 'Issue revived successfully');
          _loadGrievance();
        } else {
          AppSnackbar.error(context, response.data['message'] ?? 'Failed to revive issue');
        }
      } catch (e) {
        AppSnackbar.error(context, 'Error reviving issue: $e');
      }
    }
  }

  Widget _buildBeforeAfterView() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Before & After',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            // Before Images
            if (_grievance!.imageUrls.isNotEmpty) ...[
              Text(
                'Before',
                style: AppDesignSystem.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              _buildImageGrid(_grievance!.imageUrls),
              const SizedBox(height: 16),
            ],
            // After Images
            if (_grievance!.afterPhotos.isNotEmpty) ...[
              Text(
                'After',
                style: AppDesignSystem.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppDesignSystem.successColor,
                ),
              ),
              const SizedBox(height: 8),
              _buildImageGrid(_grievance!.afterPhotos),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagesView(String title, List<String> images) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildImageGrid(images),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String> images) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            // TODO: Show full screen image viewer
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: images[index].startsWith('data:image')
                ? Base64ImageWidget(
                    imageUrl: images[index],
                    fit: BoxFit.cover,
                  )
                : CachedNetworkImage(
                    imageUrl: images[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image, color: Colors.grey, size: 24),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildStatusTimeline() {
    if (_grievance == null || 
        _grievance!.statusHistory == null || 
        _grievance!.statusHistory!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by date (oldest first)
    final sortedHistory = List<Map<String, dynamic>>.from(_grievance!.statusHistory!);
    sortedHistory.sort((a, b) {
      final dateA = _parseHistoryDate(a['changedAt']);
      final dateB = _parseHistoryDate(b['changedAt']);
      return dateA.compareTo(dateB);
    });

    // Calculate average solving time
    DateTime? submittedDate;
    DateTime? resolvedDate;
    for (final entry in sortedHistory) {
      final status = entry['status'] as String? ?? '';
      final date = _parseHistoryDate(entry['changedAt']);
      if (status == 'submitted' && submittedDate == null) {
        submittedDate = date;
      }
      if ((status == 'resolved' || status == 'closed') && resolvedDate == null) {
        resolvedDate = date;
      }
    }

    String? avgTimeText;
    if (submittedDate != null && resolvedDate != null) {
      final duration = resolvedDate.difference(submittedDate);
      final days = duration.inDays;
      final hours = duration.inHours % 24;
      if (days > 0) {
        avgTimeText = '$days day${days > 1 ? 's' : ''}';
        if (hours > 0) {
          avgTimeText += ' $hours hour${hours > 1 ? 's' : ''}';
        }
      } else {
        avgTimeText = '$hours hour${hours > 1 ? 's' : ''}';
      }
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status Timeline',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (avgTimeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Solved in $avgTimeText',
                      style: AppDesignSystem.bodySmall.copyWith(
                        color: AppDesignSystem.successColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedHistory.asMap().entries.map((entry) {
              final index = entry.key;
              final historyItem = entry.value;
              final status = historyItem['status'] as String? ?? '';
              final changedAt = _parseHistoryDate(historyItem['changedAt']);
              final changedBy = historyItem['changedByName'] as String? ?? 'Unknown';
              final isLast = index == sortedHistory.length - 1;
              
              return _buildTimelineItem(
                status: status,
                date: changedAt,
                changedBy: changedBy,
                isLast: isLast,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required String status,
    required DateTime date,
    required String changedBy,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: Colors.grey[300],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getStatusLabel(status),
                        style: AppDesignSystem.bodySmall.copyWith(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(date),
                  style: AppDesignSystem.bodySmall.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                if (changedBy.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'by $changedBy',
                    style: AppDesignSystem.bodySmall.copyWith(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  DateTime _parseHistoryDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    if (value is Map) {
      if (value.containsKey('seconds') || value.containsKey('_seconds')) {
        final seconds = value['seconds'] ?? value['_seconds'] ?? 0;
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    }
    return DateTime.now();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.blue;
      case 'assigned':
        return Colors.orange;
      case 'in_progress':
        return Colors.purple;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      default:
        return AppDesignSystem.primaryColor;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return 'Submitted';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }
}
