import 'package:flutter/material.dart';
import '../../config/app_design_system.dart';

/// Empty state widget with illustration and message
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingXXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesignSystem.spacingXL),
              decoration: BoxDecoration(
                color: (iconColor ?? AppDesignSystem.primaryColor)
                    .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: iconColor ?? AppDesignSystem.primaryColor,
              ),
            ),
            const SizedBox(height: AppDesignSystem.spacingL),
            Text(
              title,
              style: AppDesignSystem.heading3,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppDesignSystem.spacingM),
              Text(
                message!,
                style: AppDesignSystem.bodyMedium.copyWith(
                  color: AppDesignSystem.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppDesignSystem.spacingXL),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
                style: AppDesignSystem.primaryButtonStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

