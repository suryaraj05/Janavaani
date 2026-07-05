import 'package:flutter/material.dart';
import '../../config/app_design_system.dart';

/// Modern progress indicator for form completion
class AppProgressIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? stepLabels;

  const AppProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.stepLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Step labels (if provided)
        if (stepLabels != null && stepLabels!.length == totalSteps)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(totalSteps, (index) {
                final isActive = index < currentStep;
                final isCurrent = index == currentStep - 1;
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        stepLabels![index],
                        style: AppDesignSystem.bodySmall.copyWith(
                          color: isActive || isCurrent
                              ? AppDesignSystem.primaryColor
                              : AppDesignSystem.textTertiary,
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDesignSystem.spacingXS),
                    ],
                  ),
                );
              }),
            ),
          ),
        // Progress bar
        Row(
          children: List.generate(totalSteps, (index) {
            final isCompleted = index < currentStep - 1;
            final isCurrent = index == currentStep - 1;
            final isPending = index >= currentStep;

            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(
                  right: index < totalSteps - 1
                      ? AppDesignSystem.spacingXS
                      : 0,
                ),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppDesignSystem.primaryColor
                      : isCurrent
                          ? AppDesignSystem.primaryColor.withOpacity(0.5)
                          : AppDesignSystem.borderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

