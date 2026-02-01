import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class ProfilePhotoService {
  
  /// Generate a unique filename with timestamp
  static String _generateFileName() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'profile_photo_$timestamp.jpg';
  }

  /// Delete old profile photos to prevent clutter
  static Future<void> _deleteOldPhotos(Directory dir) async {
    try {
      final List<FileSystemEntity> entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is File && path.basename(entity.path).startsWith('profile_photo_')) {
          await entity.delete();
        }
      }
    } catch (e) {
      print('Error cleaning old photos: $e');
    }
  }

  /// Download photo from URL and save locally
  static Future<String?> downloadAndSavePhoto(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final appDir = await getApplicationDocumentsDirectory();
        
        // Clean up old photos first
        await _deleteOldPhotos(appDir);
        
        final filePath = path.join(appDir.path, _generateFileName());
        final file = File(filePath);
        
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
    } catch (e) {
      print('Error downloading profile photo: $e');
    }
    return null;
  }

  /// Pick photo from gallery
  static Future<String?> pickAndSavePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        
        // Clean up old photos first
        await _deleteOldPhotos(appDir);
        
        final filePath = path.join(appDir.path, _generateFileName());
        
        // Copy to app dir with new name
        await File(image.path).copy(filePath);
        return filePath;
      }
    } catch (e) {
      print('Error picking profile photo: $e');
    }
    return null;
  }

  /// Take photo with camera
  static Future<String?> takeAndSavePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        
        // Clean up old photos first
        await _deleteOldPhotos(appDir);
        
        final filePath = path.join(appDir.path, _generateFileName());
        
        // Copy to app dir with new name
        await File(image.path).copy(filePath);
        return filePath;
      }
    } catch (e) {
      print('Error taking profile photo: $e');
    }
    return null;
  }

  /// Delete local photo
  static Future<void> deleteLocalPhoto() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      await _deleteOldPhotos(appDir);
    } catch (e) {
      print('Error deleting local photo: $e');
    }
  }
}
