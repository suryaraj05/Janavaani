import 'package:flutter/material.dart';
import '../../config/app_design_system.dart';

/// Modern chip component for tags, categories, and status indicators
class AppChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final VoidCallback? onTap;
  final bool isSelected;
  final AppChipSize size;

  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.onTap,
    this.isSelected = false,
    this.size = AppChipSize.medium,
  });

  // Predefined chip variants
  AppChip.status({
    super.key,
    required String label,
    required GrievanceStatus status,
    this.onTap,
    this.size = AppChipSize.medium,
  })  : this.label = label,
        this.icon = _getStatusIcon(status),
        this.backgroundColor = _getStatusColor(status).withOpacity(0.1),
        this.textColor = _getStatusColor(status),
        this.isSelected = false;

  AppChip.priority({
    super.key,
    required String label,
    required PriorityLevel priority,
    this.onTap,
    this.size = AppChipSize.medium,
  })  : this.label = label,
        this.icon = _getPriorityIcon(priority),
        this.backgroundColor = _getPriorityColor(priority).withOpacity(0.1),
        this.textColor = _getPriorityColor(priority),
        this.isSelected = false;

  AppChip.category({
    super.key,
    required String label,
    required String category,
    this.onTap,
    this.size = AppChipSize.medium,
  })  : this.label = label,
        this.icon = Icons.category_outlined,
        this.backgroundColor = AppDesignSystem.primaryColor.withOpacity(0.1),
        this.textColor = AppDesignSystem.primaryColor,
        this.isSelected = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ??
        (isSelected
            ? AppDesignSystem.primaryColor
            : AppDesignSystem.primaryColor.withOpacity(0.1));
    final txtColor = textColor ??
        (isSelected ? Colors.white : AppDesignSystem.primaryColor);

    final content = Container(
      padding: _getPadding(),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        border: isSelected
            ? Border.all(color: AppDesignSystem.primaryColor, width: 1.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: _getIconSize(), color: txtColor),
            const SizedBox(width: AppDesignSystem.spacingXS),
          ],
          Text(
            label,
            style: _getTextStyle().copyWith(color: txtColor),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case AppChipSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingS,
          vertical: AppDesignSystem.spacingXS,
        );
      case AppChipSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingM,
          vertical: AppDesignSystem.spacingS,
        );
      case AppChipSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingL,
          vertical: AppDesignSystem.spacingM,
        );
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppChipSize.small:
        return 12;
      case AppChipSize.medium:
        return 16;
      case AppChipSize.large:
        return 20;
    }
  }

  TextStyle _getTextStyle() {
    switch (size) {
      case AppChipSize.small:
        return AppDesignSystem.labelSmall;
      case AppChipSize.medium:
        return AppDesignSystem.labelMedium;
      case AppChipSize.large:
        return AppDesignSystem.bodyMedium;
    }
  }

  static IconData _getStatusIcon(GrievanceStatus status) {
    switch (status) {
      case GrievanceStatus.submitted:
        return Icons.pending_outlined;
      case GrievanceStatus.inProgress:
        return Icons.work_outline;
      case GrievanceStatus.resolved:
        return Icons.check_circle_outline;
      case GrievanceStatus.closed:
        return Icons.close;
      case GrievanceStatus.rejected:
        return Icons.cancel_outlined;
    }
  }

  static Color _getStatusColor(GrievanceStatus status) {
    switch (status) {
      case GrievanceStatus.submitted:
        return AppDesignSystem.statusSubmitted;
      case GrievanceStatus.inProgress:
        return AppDesignSystem.statusInProgress;
      case GrievanceStatus.resolved:
        return AppDesignSystem.statusResolved;
      case GrievanceStatus.closed:
        return AppDesignSystem.statusClosed;
      case GrievanceStatus.rejected:
        return AppDesignSystem.statusRejected;
    }
  }

  static IconData _getPriorityIcon(PriorityLevel priority) {
    switch (priority) {
      case PriorityLevel.urgent:
        return Icons.priority_high;
      case PriorityLevel.high:
        return Icons.trending_up;
      case PriorityLevel.medium:
        return Icons.remove;
      case PriorityLevel.low:
        return Icons.trending_down;
    }
  }

  static Color _getPriorityColor(PriorityLevel priority) {
    switch (priority) {
      case PriorityLevel.urgent:
        return AppDesignSystem.priorityUrgent;
      case PriorityLevel.high:
        return AppDesignSystem.priorityHigh;
      case PriorityLevel.medium:
        return AppDesignSystem.priorityMedium;
      case PriorityLevel.low:
        return AppDesignSystem.priorityLow;
    }
  }
}

enum AppChipSize { small, medium, large }
enum GrievanceStatus { submitted, inProgress, resolved, closed, rejected }
enum PriorityLevel { urgent, high, medium, low }

