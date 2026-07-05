import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/app_design_system.dart';
import '../models/grievance.dart';
import '../widgets/design_system/app_button.dart';
import '../widgets/design_system/app_card.dart';
import '../widgets/design_system/app_chip.dart';
import '../services/api_service.dart';
import '../widgets/base64_image_widget.dart';

class DuplicateGrievanceDialog extends StatefulWidget {
  final List<DuplicateMatch> similarGrievances;
  final Grievance newGrievance;
  final VoidCallback onContinueAnyway;
  final VoidCallback onCancel;

  const DuplicateGrievanceDialog({
    super.key,
    required this.similarGrievances,
    required this.newGrievance,
    required this.onContinueAnyway,
    required this.onCancel,
  });

  @override
  State<DuplicateGrievanceDialog> createState() => _DuplicateGrievanceDialogState();
}

class _DuplicateGrievanceDialogState extends State<DuplicateGrievanceDialog> {
  final ApiService _apiService = ApiService();
  bool _isUpvoting = false;
  bool _isReviving = false;
  String? _revivingGrievanceId;

  @override
  void initState() {
    super.initState();
    _apiService.init();
  }

  Future<void> _handleUpvote(String grievanceId) async {
    setState(() => _isUpvoting = true);
    try {
      await _apiService.upvoteGrievance(grievanceId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Upvoted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error upvoting: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpvoting = false);
      }
    }
  }

  Future<void> _handleRevive(String grievanceId) async {
    setState(() {
      _isReviving = true;
      _revivingGrievanceId = grievanceId;
    });
    try {
      // Update grievance status to "revived"
      await _apiService.updateGrievanceStatus(grievanceId, status: 'revived');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Grievance revived successfully!')),
        );
        Navigator.pop(context);
        widget.onCancel(); // Close dialog and cancel new submission
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reviving: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isReviving = false;
          _revivingGrievanceId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppDesignSystem.spacingL),
              decoration: BoxDecoration(
                color: AppDesignSystem.warningColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDesignSystem.radiusL),
                  topRight: Radius.circular(AppDesignSystem.radiusL),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppDesignSystem.warningColor),
                  const SizedBox(width: AppDesignSystem.spacingS),
                  Expanded(
                    child: Text(
                      'Similar Problem Found',
                      style: AppDesignSystem.heading3.copyWith(
                        color: AppDesignSystem.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onCancel,
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDesignSystem.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'We found similar problems that might be the same issue:',
                      style: AppDesignSystem.bodyMedium,
                    ),
                    const SizedBox(height: AppDesignSystem.spacingL),
                    ...widget.similarGrievances.map((match) => _buildSimilarGrievanceCard(match)),
                    const SizedBox(height: AppDesignSystem.spacingL),
                    Text(
                      'What would you like to do?',
                      style: AppDesignSystem.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.all(AppDesignSystem.spacingL),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppDesignSystem.borderColor),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'Continue Anyway',
                      onPressed: widget.onContinueAnyway,
                      type: AppButtonType.secondary,
                    ),
                  ),
                  const SizedBox(width: AppDesignSystem.spacingS),
                  Expanded(
                    child: AppButton(
                      label: 'Cancel',
                      onPressed: widget.onCancel,
                      type: AppButtonType.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimilarGrievanceCard(DuplicateMatch match) {
    final grievance = match.grievance;
    final isReviving = _isReviving && _revivingGrievanceId == grievance.grievanceId;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with similarity score
          Row(
            children: [
              Expanded(
                child: Text(
                  grievance.title,
                  style: AppDesignSystem.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppChip(
                label: '${(match.similarityScore * 100).toInt()}% similar',
                backgroundColor: AppDesignSystem.warningColor.withOpacity(0.1),
                textColor: AppDesignSystem.warningColor,
                size: AppChipSize.small,
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            grievance.description,
            style: AppDesignSystem.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (grievance.imageUrls.isNotEmpty) ...[
            const SizedBox(height: AppDesignSystem.spacingS),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: grievance.imageUrls.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(right: AppDesignSystem.spacingS),
                    width: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                      border: Border.all(color: AppDesignSystem.borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                      child: Base64ImageWidget(
                        imageUrl: grievance.imageUrls[index],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: AppDesignSystem.spacingS),
          Row(
            children: [
              AppChip(
                label: grievance.status.replaceAll('_', ' ').toUpperCase(),
                backgroundColor: _getStatusColor(grievance.status).withOpacity(0.1),
                textColor: _getStatusColor(grievance.status),
                size: AppChipSize.small,
              ),
              if (match.isSameLocation) ...[
                const SizedBox(width: AppDesignSystem.spacingS),
                AppChip(
                  label: 'Same Location',
                  backgroundColor: AppDesignSystem.infoColor.withOpacity(0.1),
                  textColor: AppDesignSystem.infoColor,
                  size: AppChipSize.small,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            match.reason,
            style: AppDesignSystem.bodySmall.copyWith(
              color: AppDesignSystem.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'View Details',
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/grievance/${grievance.grievanceId}');
                  },
                  type: AppButtonType.secondary,
                  size: AppButtonSize.small,
                ),
              ),
              const SizedBox(width: AppDesignSystem.spacingS),
              Expanded(
                child: AppButton(
                  label: 'Upvote',
                  onPressed: _isUpvoting ? null : () => _handleUpvote(grievance.grievanceId),
                  isLoading: _isUpvoting,
                  type: AppButtonType.primary,
                  size: AppButtonSize.small,
                ),
              ),
              if (match.canRevive) ...[
                const SizedBox(width: AppDesignSystem.spacingS),
                Expanded(
                  child: AppButton(
                    label: isReviving ? 'Reviving...' : 'Revive',
                    onPressed: isReviving ? null : () => _handleRevive(grievance.grievanceId),
                    isLoading: isReviving,
                    type: AppButtonType.secondary,
                    size: AppButtonSize.small,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return AppDesignSystem.statusSubmitted;
      case 'in_progress':
        return AppDesignSystem.statusInProgress;
      case 'resolved':
        return AppDesignSystem.statusResolved;
      case 'closed':
        return AppDesignSystem.statusClosed;
      case 'revived':
        return AppDesignSystem.warningColor;
      default:
        return AppDesignSystem.textSecondary;
    }
  }
}

class DuplicateMatch {
  final Grievance grievance;
  final double similarityScore;
  final String reason;
  final bool isSameLocation;
  final bool canRevive;
  final double? distance;

  DuplicateMatch({
    required this.grievance,
    required this.similarityScore,
    required this.reason,
    required this.isSameLocation,
    required this.canRevive,
    this.distance,
  });
}

