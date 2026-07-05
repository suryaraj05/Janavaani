import 'package:flutter/material.dart';
import '../config/app_design_system.dart';
import '../widgets/design_system/app_button.dart';

class UpdateStatusDialog extends StatefulWidget {
  final String currentStatus;
  final List<String> availableStatuses;

  const UpdateStatusDialog({
    super.key,
    required this.currentStatus,
    this.availableStatuses = const ['submitted', 'assigned', 'in_progress', 'resolved', 'closed', 'rejected'],
  });

  @override
  State<UpdateStatusDialog> createState() => _UpdateStatusDialogState();
}

class _UpdateStatusDialogState extends State<UpdateStatusDialog> {
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.currentStatus;
  }

  String _getStatusLabel(String status) {
    switch (status) {
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

  Color _getStatusColor(String status) {
    switch (status) {
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update Status',
              style: AppDesignSystem.heading3,
            ),
            const SizedBox(height: AppDesignSystem.spacingM),
            Text(
              'Select the new status for this grievance:',
              style: AppDesignSystem.bodyMedium,
            ),
            const SizedBox(height: AppDesignSystem.spacingL),
            // Status options
            ...widget.availableStatuses.map((status) {
              final isSelected = _selectedStatus == status;
              final isCurrentStatus = status == widget.currentStatus;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingS),
                child: InkWell(
                  onTap: isCurrentStatus ? null : () {
                    setState(() {
                      _selectedStatus = status;
                    });
                  },
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                  child: Container(
                    padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _getStatusColor(status).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                      border: Border.all(
                        color: isSelected
                            ? _getStatusColor(status)
                            : AppDesignSystem.borderColor,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppDesignSystem.spacingM),
                        Expanded(
                          child: Text(
                            _getStatusLabel(status),
                            style: AppDesignSystem.bodyMedium.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isCurrentStatus ? Colors.grey : AppDesignSystem.textPrimary,
                            ),
                          ),
                        ),
                        if (isCurrentStatus)
                          Padding(
                            padding: const EdgeInsets.only(left: AppDesignSystem.spacingS),
                            child: Text(
                              '(Current)',
                              style: AppDesignSystem.bodySmall.copyWith(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        if (isSelected && !isCurrentStatus)
                          Icon(
                            Icons.check_circle,
                            color: _getStatusColor(status),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: AppDesignSystem.spacingL),
            // Actions
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                    type: AppButtonType.text,
                  ),
                ),
                const SizedBox(width: AppDesignSystem.spacingS),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    label: 'Update Status',
                    onPressed: _selectedStatus != null && _selectedStatus != widget.currentStatus
                        ? () => Navigator.pop(context, _selectedStatus)
                        : null,
                    type: AppButtonType.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

