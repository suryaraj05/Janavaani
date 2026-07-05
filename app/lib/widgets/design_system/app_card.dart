import 'package:flutter/material.dart';
import '../../config/app_design_system.dart';

/// Modern card component with consistent styling
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double? borderRadius;
  final List<BoxShadow>? boxShadow;
  final bool showBorder;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderRadius,
    this.boxShadow,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin ?? const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppDesignSystem.cardColor,
        borderRadius: BorderRadius.circular(
          borderRadius ?? AppDesignSystem.radiusL,
        ),
        boxShadow: boxShadow ?? AppDesignSystem.shadowSmall,
        border: showBorder
            ? Border.all(color: AppDesignSystem.borderColor, width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            borderRadius ?? AppDesignSystem.radiusL,
          ),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppDesignSystem.spacingM),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Hero(
        tag: 'card_${hashCode}',
        child: card,
      );
    }
    return card;
  }
}

/// Elevated card variant with stronger shadow
class AppElevatedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  const AppElevatedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      margin: margin,
      onTap: onTap,
      boxShadow: AppDesignSystem.shadowMedium,
      child: child,
    );
  }
}

