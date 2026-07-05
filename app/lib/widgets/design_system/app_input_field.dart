import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_design_system.dart';

/// Modern input field with floating label and smooth animations
class AppInputField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? initialValue;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool enabled;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? helperText;
  final String? errorText;

  const AppInputField({
    super.key,
    required this.label,
    this.hint,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.enabled = true,
    this.controller,
    this.focusNode,
    this.helperText,
    this.errorText,
  });

  @override
  State<AppInputField> createState() => _AppInputFieldState();
}

class _AppInputFieldState extends State<AppInputField>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isFocused = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    if (_focusNode.hasFocus || (widget.controller?.text.isNotEmpty ?? false)) {
      _animationController.value = 1.0;
      _isFocused = true;
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _animationController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
      if (_isFocused) {
        _animationController.forward();
      } else if (widget.controller?.text.isEmpty ?? true) {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                border: Border.all(
                  color: _hasError
                      ? AppDesignSystem.errorColor
                      : (_isFocused
                          ? AppDesignSystem.primaryColor
                          : AppDesignSystem.borderColor),
                  width: _isFocused ? 2 : 1,
                ),
                color: AppDesignSystem.surfaceColor,
              ),
              child: Stack(
                children: [
                  // Floating label
                  Positioned(
                    left: widget.prefixIcon != null
                        ? AppDesignSystem.spacingXL
                        : AppDesignSystem.spacingM,
                    top: AppDesignSystem.spacingM +
                        (1 - _animation.value) * 8,
                    child: Opacity(
                      opacity: _isFocused || widget.controller?.text.isNotEmpty == true
                          ? 1.0
                          : 0.6,
                      child: Text(
                        widget.label,
                        style: AppDesignSystem.labelMedium.copyWith(
                          color: _hasError
                              ? AppDesignSystem.errorColor
                              : (_isFocused
                                  ? AppDesignSystem.primaryColor
                                  : AppDesignSystem.textSecondary),
                          fontSize: 12 + (1 - _animation.value) * 2,
                        ),
                      ),
                    ),
                  ),
                  // Text field
                  TextFormField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    initialValue: widget.initialValue,
                    onChanged: (value) {
                      widget.onChanged?.call(value);
                      if (value.isNotEmpty && !_isFocused) {
                        _animationController.forward();
                      }
                      setState(() {
                        _hasError = false;
                      });
                    },
                    onFieldSubmitted: widget.onSubmitted,
                    validator: (value) {
                      final error = widget.validator?.call(value);
                      setState(() {
                        _hasError = error != null;
                      });
                      return error;
                    },
                    keyboardType: widget.keyboardType,
                    obscureText: widget.obscureText,
                    maxLines: widget.maxLines,
                    maxLength: widget.maxLength,
                    enabled: widget.enabled,
                    style: AppDesignSystem.bodyMedium,
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      prefixIcon: widget.prefixIcon != null
                          ? Icon(
                              widget.prefixIcon,
                              color: _isFocused
                                  ? AppDesignSystem.primaryColor
                                  : AppDesignSystem.textSecondary,
                            )
                          : null,
                      suffixIcon: widget.suffixIcon != null
                          ? GestureDetector(
                              onTap: widget.onSuffixTap,
                              child: Icon(
                                widget.suffixIcon,
                                color: AppDesignSystem.textSecondary,
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.only(
                        left: widget.prefixIcon != null
                            ? AppDesignSystem.spacingXL
                            : AppDesignSystem.spacingM,
                        right: widget.suffixIcon != null
                            ? AppDesignSystem.spacingXL
                            : AppDesignSystem.spacingM,
                        top: AppDesignSystem.spacingL + 8,
                        bottom: AppDesignSystem.spacingM,
                      ),
                      counterText: '',
                    ),
                    inputFormatters: widget.maxLength != null
                        ? [LengthLimitingTextInputFormatter(widget.maxLength)]
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
        if (widget.helperText != null && !_hasError) ...[
          const SizedBox(height: AppDesignSystem.spacingXS),
          Padding(
            padding: const EdgeInsets.only(left: AppDesignSystem.spacingM),
            child: Text(
              widget.helperText!,
              style: AppDesignSystem.bodySmall,
            ),
          ),
        ],
        if (widget.errorText != null || _hasError) ...[
          const SizedBox(height: AppDesignSystem.spacingXS),
          Padding(
            padding: const EdgeInsets.only(left: AppDesignSystem.spacingM),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 16,
                  color: AppDesignSystem.errorColor,
                ),
                const SizedBox(width: AppDesignSystem.spacingXS),
                Expanded(
                  child: Text(
                    widget.errorText ?? '',
                    style: AppDesignSystem.bodySmall.copyWith(
                      color: AppDesignSystem.errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

