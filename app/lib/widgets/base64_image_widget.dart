import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Widget to display base64 images (data URLs)
class Base64ImageWidget extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  const Base64ImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // Check if it's a base64 data URL
    if (imageUrl.startsWith('data:image')) {
      try {
        // Extract base64 string from data URL
        final base64String = imageUrl.contains(',') 
            ? imageUrl.split(',')[1] 
            : imageUrl.replaceFirst('data:image/', '').split(';')[0];
        
        // Decode base64 to bytes
        final bytes = base64Decode(base64String);
        
        return Image.memory(
          Uint8List.fromList(bytes),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: width,
              height: height,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.broken_image, color: Colors.grey),
              ),
            );
          },
        );
      } catch (e) {
        print('❌ Error decoding base64 image: $e');
        return Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.grey),
          ),
        );
      }
    }
    
    // If it's a regular URL, return placeholder (should use CachedNetworkImage instead)
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Center(
        child: Icon(Icons.image, color: Colors.grey),
      ),
    );
  }
}

