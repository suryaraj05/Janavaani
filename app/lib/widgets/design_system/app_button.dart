import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_design_system.dart';

/// Modern button component with micro-interactions
class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    
    Widget button;
    
    switch (widget.type) {
      case AppButtonType.primary:
        button = _buildPrimaryButton(isEnabled);
        break;
      case AppButtonType.secondary:
        button = _buildSecondaryButton(isEnabled);
        break;
      case AppButtonType.text:
        button = _buildTextButton(isEnabled);
        break;
    }

    final content = GestureDetector(
      onTapDown: isEnabled ? _handleTapDown : null,
      onTapUp: isEnabled ? _handleTapUp : null,
      onTapCancel: isEnabled ? _handleTapCancel : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: button,
      ),
    );

    if (widget.fullWidth) {
      return SizedBox(width: double.infinity, child: content);
    }
    return content;
  }

  Widget _buildPrimaryButton(bool isEnabled) {
    return Container(
      decoration: BoxDecoration(
        gradient: isEnabled
            ? LinearGradient(
                colors: widget.backgroundColor != null
                    ? [widget.backgroundColor!, widget.backgroundColor!.withOpacity(0.8)]
                    : [AppDesignSystem.primaryColor, AppDesignSystem.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isEnabled ? null : AppDesignSystem.borderColor,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        boxShadow: isEnabled ? AppDesignSystem.shadowSmall : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? widget.onPressed : null,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          child: _buildButtonContent(
            isEnabled ? Colors.white : AppDesignSystem.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton(bool isEnabled) {
    return OutlinedButton(
      onPressed: isEnabled ? widget.onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: widget.foregroundColor ?? AppDesignSystem.primaryColor,
        side: BorderSide(
          color: isEnabled
              ? (widget.foregroundColor ?? AppDesignSystem.primaryColor)
              : AppDesignSystem.borderColor,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        ),
        padding: _getPadding(),
      ),
      child: _buildButtonContent(
        widget.foregroundColor ?? AppDesignSystem.primaryColor,
      ),
    );
  }

  Widget _buildTextButton(bool isEnabled) {
    return TextButton(
      onPressed: isEnabled ? widget.onPressed : null,
      style: TextButton.styleFrom(
        foregroundColor: widget.foregroundColor ?? AppDesignSystem.primaryColor,
        padding: _getPadding(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        ),
      ),
      child: _buildButtonContent(
        widget.foregroundColor ?? AppDesignSystem.primaryColor,
      ),
    );
  }

  Widget _buildButtonContent(Color textColor) {
    return Padding(
      padding: _getPadding(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.isLoading) ...[
            SizedBox(
              width: _getIconSize(),
              height: _getIconSize(),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(textColor),
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingS),
          ] else if (widget.icon != null) ...[
            Icon(widget.icon, size: _getIconSize(), color: textColor),
            const SizedBox(width: AppDesignSystem.spacingS),
          ],
          Text(
            widget.label,
            style: AppDesignSystem.labelLarge.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingM,
          vertical: AppDesignSystem.spacingS,
        );
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingL,
          vertical: AppDesignSystem.spacingM,
        );
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingXL,
          vertical: AppDesignSystem.spacingL,
        );
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 20;
      case AppButtonSize.large:
        return 24;
    }
  }
}

enum AppButtonType { primary, secondary, text }
enum AppButtonSize { small, medium, large }


