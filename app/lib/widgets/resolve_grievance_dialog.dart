import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_design_system.dart';
import '../widgets/design_system/app_button.dart';
import '../widgets/design_system/app_card.dart';
import '../utils/image_compression.dart';
import '../widgets/base64_image_widget.dart';
import 'dart:convert';

class ResolveGrievanceDialog extends StatefulWidget {
  final String grievanceId;
  final List<String> beforePhotos;

  const ResolveGrievanceDialog({
    super.key,
    required this.grievanceId,
    required this.beforePhotos,
  });

  @override
  State<ResolveGrievanceDialog> createState() => _ResolveGrievanceDialogState();
}

class _ResolveGrievanceDialogState extends State<ResolveGrievanceDialog> {
  List<String> _afterPhotos = [];
  bool _isUploading = false;

  Future<void> _pickAfterPhotos() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      
      if (images.isNotEmpty) {
        setState(() => _isUploading = true);
        
        List<String> base64Photos = [];
        for (var image in images) {
          // Compress image
          final compressed = await compressImage(image, maxWidth: 1280, quality: 75);
          final bytes = await compressed.readAsBytes();
          final base64String = base64Encode(bytes);
          base64Photos.add('data:image/jpeg;base64,$base64String');
        }
        
        setState(() {
          _afterPhotos.addAll(base64Photos);
          if (_afterPhotos.length > 5) {
            _afterPhotos = _afterPhotos.take(5).toList();
          }
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  void _removeAfterPhoto(int index) {
    setState(() {
      _afterPhotos.removeAt(index);
    });
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
                color: AppDesignSystem.successColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDesignSystem.radiusL),
                  topRight: Radius.circular(AppDesignSystem.radiusL),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppDesignSystem.successColor),
                  const SizedBox(width: AppDesignSystem.spacingS),
                  Expanded(
                    child: Text(
                      'Mark as Resolved',
                      style: AppDesignSystem.heading3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
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
                      'Upload "After" photos showing the resolved problem:',
                      style: AppDesignSystem.bodyMedium,
                    ),
                    const SizedBox(height: AppDesignSystem.spacingL),
                    
                    // Before photos preview
                    if (widget.beforePhotos.isNotEmpty) ...[
                      Text(
                        'Before:',
                        style: AppDesignSystem.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppDesignSystem.spacingS),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.beforePhotos.length,
                          itemBuilder: (context, index) {
                            return Container(
                              margin: const EdgeInsets.only(right: AppDesignSystem.spacingS),
                              width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                                border: Border.all(color: AppDesignSystem.borderColor),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                                child: Base64ImageWidget(
                                  imageUrl: widget.beforePhotos[index],
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: AppDesignSystem.spacingL),
                    ],
                    
                    // After photos
                    Text(
                      'After:',
                      style: AppDesignSystem.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppDesignSystem.spacingS),
                    if (_afterPhotos.isEmpty)
                      GestureDetector(
                        onTap: _isUploading ? null : _pickAfterPhotos,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppDesignSystem.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                            border: Border.all(
                              color: AppDesignSystem.primaryColor,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Center(
                            child: _isUploading
                                ? const CircularProgressIndicator()
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate,
                                        color: AppDesignSystem.primaryColor,
                                        size: 40,
                                      ),
                                      const SizedBox(height: AppDesignSystem.spacingS),
                                      Text(
                                        'Tap to add photos',
                                        style: AppDesignSystem.bodySmall.copyWith(
                                          color: AppDesignSystem.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _afterPhotos.length,
                              itemBuilder: (context, index) {
                                return Stack(
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: AppDesignSystem.spacingS),
                                      width: 120,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                                        border: Border.all(color: AppDesignSystem.borderColor),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                                        child: Base64ImageWidget(
                                          imageUrl: _afterPhotos[index],
                                          width: 120,
                                          height: 120,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeAfterPhoto(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          if (_afterPhotos.length < 5)
                            Padding(
                              padding: const EdgeInsets.only(top: AppDesignSystem.spacingS),
                              child: AppButton(
                                label: 'Add More Photos',
                                onPressed: _pickAfterPhotos,
                                type: AppButtonType.secondary,
                                size: AppButtonSize.small,
                              ),
                            ),
                        ],
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
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                      type: AppButtonType.text,
                    ),
                  ),
                  const SizedBox(width: AppDesignSystem.spacingS),
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: 'Mark as Resolved',
                      onPressed: _afterPhotos.isEmpty
                          ? null
                          : () => Navigator.pop(context, _afterPhotos),
                      type: AppButtonType.primary,
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
}

