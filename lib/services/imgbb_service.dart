import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service untuk upload gambar - menggunakan Imgur API (gratis, anonymous upload)
class ImageUploadService {
  // Imgur anonymous upload endpoint
  static const String _uploadUrl = 'https://api.imgur.com/3/image';
  static const String _clientId = '546c25a59c58ad7';

  /// Upload gambar ke Imgur
  /// [imageFile] - File gambar yang akan diupload
  /// Returns URL gambar jika sukses, null jika gagal
  static Future<String?> uploadImage(File imageFile) async {
    try {
      // Read file as base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      debugPrint('🔼 Upload: Starting upload, file size: ${bytes.length} bytes');

      // Create request
      final uri = Uri.parse(_uploadUrl);
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Client-ID $_clientId',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'image=${Uri.encodeComponent(base64Image)}&type=base64',
      );

      debugPrint('🔼 Upload: Response status: ${response.statusCode}');
      debugPrint('🔼 Upload: Response body: ${response.body}');

      // Parse response
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        debugPrint('🔼 Upload: JSON Response: $jsonResponse');

        if (jsonResponse['success'] == true) {
          // Try multiple possible URL fields
          String? url = jsonResponse['data']['link'];
          url ??= jsonResponse['data']['url'];

          // Ensure URL uses HTTPS
          if (url != null && url.startsWith('http:')) {
            url = url.replaceFirst('http:', 'https:');
          }

          debugPrint('🔼 Upload: ✅ Success! URL: $url');
          return url;
        } else {
          final errorMsg = jsonResponse['data']?['error'] ?? jsonResponse['data']?['message'] ?? 'Upload failed';
          debugPrint('🔼 Upload: ❌ Failed - $errorMsg');
          return null;
        }
      } else {
        debugPrint('🔼 Upload: ❌ HTTP Error: ${response.statusCode}');
        debugPrint('🔼 Upload: Error body: ${response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint('🔼 Upload: ❌ Exception: $e');
      debugPrint('🔼 Upload: StackTrace: $stackTrace');
      return null;
    }
  }

  /// Upload gambar dari path
  static Future<String?> uploadFromPath(String path) async {
    return uploadImage(File(path));
  }

  /// Upload gambar dari bytes (base64 string)
  static Future<String?> uploadFromBase64(String base64String) async {
    try {
      debugPrint('🔼 UploadBase64: Starting, size: ${base64String.length} chars');

      final uri = Uri.parse(_uploadUrl);
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Client-ID $_clientId',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'image=${Uri.encodeComponent(base64String)}&type=base64',
      );

      debugPrint('🔼 UploadBase64: Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          String? url = jsonResponse['data']['link'] ?? jsonResponse['data']['url'];
          if (url != null && url.startsWith('http:')) {
            url = url.replaceFirst('http:', 'https:');
          }
          debugPrint('🔼 UploadBase64: ✅ Success! URL: $url');
          return url;
        }
      }
      debugPrint('🔼 UploadBase64: ❌ Failed');
      return null;
    } catch (e) {
      debugPrint('🔼 UploadBase64: ❌ Error: $e');
      return null;
    }
  }
}

// Alias untuk backward compatibility
class ImgBBService {
  static Future<String?> uploadImage(File imageFile) => ImageUploadService.uploadImage(imageFile);
  static Future<String?> uploadFromBase64(String base64String) => ImageUploadService.uploadFromBase64(base64String);
}
