import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/grievance.dart';
import '../config/app_design_system.dart';
import '../widgets/design_system/app_card.dart';
import '../widgets/design_system/app_chip.dart';
import '../widgets/base64_image_widget.dart';

/// Modern grievance card with improved UI/UX
class ModernGrievanceCard extends StatefulWidget {
  final Grievance grievance;
  final VoidCallback? onUpvote;
  final bool isUpvoting;

  const ModernGrievanceCard({
    super.key,
    required this.grievance,
    this.onUpvote,
    this.isUpvoting = false,
  });

  @override
  State<ModernGrievanceCard> createState() => _ModernGrievanceCardState();
}

class _ModernGrievanceCardState extends State<ModernGrievanceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  bool _isUpvoted() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return widget.grievance.upvotedBy.contains(user.uid);
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

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Recently';
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: () => context.push('/grievance/${widget.grievance.grievanceId}'),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AppCard(
          margin: const EdgeInsets.only(
            left: AppDesignSystem.spacingM,
            right: AppDesignSystem.spacingM,
            bottom: AppDesignSystem.spacingM,
          ),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image header (if available)
              if (widget.grievance.imageUrls.isNotEmpty)
                _buildImageHeader()
              else
                const SizedBox(height: AppDesignSystem.spacingM),

              Padding(
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
                            widget.grievance.title,
                            style: AppDesignSystem.heading4,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppDesignSystem.spacingS),
                        AppChip.priority(
                          label: widget.grievance.priority.toUpperCase(),
                          priority: _getPriorityEnum(widget.grievance.priority),
                          size: AppChipSize.small,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDesignSystem.spacingS),

                    // Status and Time
                    Row(
                      children: [
                        AppChip.status(
                          label: widget.grievance.status
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          status: _getStatusEnum(widget.grievance.status),
                          size: AppChipSize.small,
                        ),
                        const SizedBox(width: AppDesignSystem.spacingS),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppDesignSystem.textSecondary,
                        ),
                        const SizedBox(width: AppDesignSystem.spacingXS),
                        Text(
                          _formatTimeAgo(widget.grievance.createdAt),
                          style: AppDesignSystem.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDesignSystem.spacingM),

                    // Description
                    Text(
                      widget.grievance.description,
                      style: AppDesignSystem.bodyMedium.copyWith(
                        color: AppDesignSystem.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDesignSystem.spacingM),

                    // Departments
                    if (widget.grievance.departments.isNotEmpty)
                      Wrap(
                        spacing: AppDesignSystem.spacingS,
                        runSpacing: AppDesignSystem.spacingS,
                        children: widget.grievance.departments.take(2).map((dept) {
                          return AppChip.category(
                            label: dept.length > 20
                                ? '${dept.substring(0, 20)}...'
                                : dept,
                            category: dept,
                            size: AppChipSize.small,
                          );
                        }).toList(),
                      ),
                    if (widget.grievance.departments.length > 2)
                      Padding(
                        padding: const EdgeInsets.only(top: AppDesignSystem.spacingS),
                        child: Text(
                          '+${widget.grievance.departments.length - 2} more',
                          style: AppDesignSystem.bodySmall,
                        ),
                      ),
                    const SizedBox(height: AppDesignSystem.spacingM),

                    // Footer: Location and Upvote
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: AppDesignSystem.textSecondary,
                        ),
                        const SizedBox(width: AppDesignSystem.spacingXS),
                        Expanded(
                          child: Text(
                            widget.grievance.location.length > 30
                                ? '${widget.grievance.location.substring(0, 30)}...'
                                : widget.grievance.location,
                            style: AppDesignSystem.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppDesignSystem.spacingM),
                        _buildUpvoteButton(),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageHeader() {
    final firstImage = widget.grievance.imageUrls.first;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(AppDesignSystem.radiusL),
        topRight: Radius.circular(AppDesignSystem.radiusL),
      ),
      child: Stack(
        children: [
          SizedBox(
            height: 180,
            width: double.infinity,
            child: firstImage.startsWith('data:image')
                ? Base64ImageWidget(
                    imageUrl: firstImage,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  )
                : CachedNetworkImage(
                    imageUrl: firstImage,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppDesignSystem.borderColor,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppDesignSystem.borderColor,
                      child: const Icon(Icons.broken_image, size: 48),
                    ),
                  ),
          ),
          if (widget.grievance.imageUrls.length > 1)
            Positioned(
              top: AppDesignSystem.spacingS,
              right: AppDesignSystem.spacingS,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.spacingS,
                  vertical: AppDesignSystem.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.photo_library, size: 14, color: Colors.white),
                    const SizedBox(width: AppDesignSystem.spacingXS),
                    Text(
                      '+${widget.grievance.imageUrls.length - 1}',
                      style: AppDesignSystem.bodySmall.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUpvoteButton() {
    final isUpvoted = _isUpvoted();
    return GestureDetector(
      onTap: widget.onUpvote,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingM,
          vertical: AppDesignSystem.spacingS,
        ),
        decoration: BoxDecoration(
          color: isUpvoted
              ? AppDesignSystem.primaryColor.withOpacity(0.1)
              : AppDesignSystem.borderColor,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
          border: Border.all(
            color: isUpvoted
                ? AppDesignSystem.primaryColor
                : AppDesignSystem.borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isUpvoting)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isUpvoted
                        ? AppDesignSystem.primaryColor
                        : AppDesignSystem.textSecondary,
                  ),
                ),
              )
            else
              Icon(
                Icons.trending_up,
                size: 18,
                color: isUpvoted
                    ? AppDesignSystem.primaryColor
                    : AppDesignSystem.textSecondary,
              ),
            const SizedBox(width: AppDesignSystem.spacingXS),
            Text(
              '${widget.grievance.upvotedBy.length}',
              style: AppDesignSystem.labelMedium.copyWith(
                color: isUpvoted
                    ? AppDesignSystem.primaryColor
                    : AppDesignSystem.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

