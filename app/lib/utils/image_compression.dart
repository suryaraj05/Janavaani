import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Compress image to reduce file size, targeting max 1MB
/// Returns compressed file path
Future<XFile> compressImage(XFile imageFile, {int maxWidth = 1280, int quality = 75}) async {
  try {
    final file = File(imageFile.path);
    final originalBytes = await file.readAsBytes();
    final originalSize = originalBytes.length;
    
    // If image is already small (< 1MB), return as is
    if (originalSize < 1024 * 1024) {
      return imageFile;
    }

    // Get temporary directory
    final tempDir = await getTemporaryDirectory();
    final targetPath = path.join(
      tempDir.path,
      '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
    );

    // Start with 75% quality and reduce until we get under 1MB
    int compressionQuality = quality;
    XFile? compressedFile;
    int compressedSize = originalSize;
    int attempts = 0;
    const maxAttempts = 5;

    while (compressedSize > 1024 * 1024 && attempts < maxAttempts && compressionQuality >= 50) {
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: compressionQuality,
        minWidth: 800,
        minHeight: 800,
        format: CompressFormat.jpeg,
      );

      if (result == null) {
        break;
      }

      compressedFile = XFile(result.path);
      compressedSize = await compressedFile.length();
      print('📸 Compression attempt ${attempts + 1}: Quality=$compressionQuality, Size=${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB');
      
      // If still too large, reduce quality more aggressively
      if (compressedSize > 1024 * 1024) {
        compressionQuality = (compressionQuality * 0.85).round(); // Reduce by 15%
        attempts++;
      } else {
        break; // Success!
      }
    }

    if (compressedFile == null) {
      print('⚠️ Compression failed, using original');
      return imageFile;
    }

    final finalSize = await compressedFile.length();
    print('✅ Image compressed: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB → ${(finalSize / 1024 / 1024).toStringAsFixed(2)}MB');
    
    return compressedFile;
  } catch (e) {
    print('❌ Error compressing image: $e');
    return imageFile; // Return original if compression fails
  }
}

/// Compress multiple images
Future<List<XFile>> compressImages(List<XFile> images, {int maxWidth = 1280, int quality = 85}) async {
  final compressedImages = <XFile>[];
  
  for (var image in images) {
    final compressed = await compressImage(image, maxWidth: maxWidth, quality: quality);
    compressedImages.add(compressed);
  }
  
  return compressedImages;
}

