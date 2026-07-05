import 'package:flutter/material.dart';
import '../config/app_design_system.dart';
import '../widgets/base64_image_widget.dart';
import 'design_system/app_card.dart';

class BeforeAfterComparison extends StatelessWidget {
  final List<String> beforePhotos;
  final List<String> afterPhotos;
  final ComparisonLayout layout;

  const BeforeAfterComparison({
    super.key,
    required this.beforePhotos,
    required this.afterPhotos,
    this.layout = ComparisonLayout.sideBySide,
  });

  @override
  Widget build(BuildContext context) {
    if (beforePhotos.isEmpty && afterPhotos.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows, color: AppDesignSystem.primaryColor),
              const SizedBox(width: AppDesignSystem.spacingS),
              Text(
                'Before & After',
                style: AppDesignSystem.heading4,
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          if (layout == ComparisonLayout.sideBySide)
            _buildSideBySide()
          else
            _buildStacked(),
        ],
      ),
    );
  }

  Widget _buildSideBySide() {
    final maxCount = beforePhotos.length > afterPhotos.length
        ? beforePhotos.length
        : afterPhotos.length;

    return Column(
      children: List.generate(maxCount, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
          child: Row(
            children: [
              // Before
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDesignSystem.spacingS,
                        vertical: AppDesignSystem.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
                      ),
                      child: Text(
                        'BEFORE',
                        style: AppDesignSystem.labelSmall.copyWith(
                          color: AppDesignSystem.errorColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDesignSystem.spacingS),
                    if (index < beforePhotos.length)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                        child: Base64ImageWidget(
                          imageUrl: beforePhotos[index],
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppDesignSystem.borderColor,
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                        ),
                        child: const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppDesignSystem.spacingM),
              // After
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDesignSystem.spacingS,
                        vertical: AppDesignSystem.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
                      ),
                      child: Text(
                        'AFTER',
                        style: AppDesignSystem.labelSmall.copyWith(
                          color: AppDesignSystem.successColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDesignSystem.spacingS),
                    if (index < afterPhotos.length)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                        child: Base64ImageWidget(
                          imageUrl: afterPhotos[index],
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: AppDesignSystem.borderColor,
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                        ),
                        child: const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStacked() {
    return Column(
      children: [
        // Before section
        if (beforePhotos.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesignSystem.spacingS,
              vertical: AppDesignSystem.spacingXS,
            ),
            decoration: BoxDecoration(
              color: AppDesignSystem.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
            ),
            child: Text(
              'BEFORE',
              style: AppDesignSystem.labelSmall.copyWith(
                color: AppDesignSystem.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: beforePhotos.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: AppDesignSystem.spacingS),
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                    child: Base64ImageWidget(
                      imageUrl: beforePhotos[index],
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingL),
        ],
        // After section
        if (afterPhotos.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesignSystem.spacingS,
              vertical: AppDesignSystem.spacingXS,
            ),
            decoration: BoxDecoration(
              color: AppDesignSystem.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
            ),
            child: Text(
              'AFTER',
              style: AppDesignSystem.labelSmall.copyWith(
                color: AppDesignSystem.successColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: afterPhotos.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: AppDesignSystem.spacingS),
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                    child: Base64ImageWidget(
                      imageUrl: afterPhotos[index],
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

enum ComparisonLayout { sideBySide, stacked }

