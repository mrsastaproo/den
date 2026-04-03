import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class UpdateDownloader {
  static final Dio _dio = Dio();
  static const MethodChannel _channel = MethodChannel('com.mrsastaproo.den/updater');

  /// Downloads the APK and triggers installation via Native Method Channel.
  /// [onProgress] returns a value between 0.0 and 1.0.
  static Future<void> downloadAndInstall({
    required String url,
    required String fileName,
    required Function(double progress) onProgress,
    required Function(String error) onError,
  }) async {
    try {
      final tempDir = await getExternalStorageDirectory(); // Better for installers
      final filePath = '${tempDir!.path}/$fileName';

      // Delete existing file if any
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }

      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      // Trigger Installation via Native Bridge
      try {
        await _channel.invokeMethod('installApk', {'path': filePath});
      } on PlatformException catch (e) {
        onError('Installation failed: ${e.message}');
      }
    } catch (e) {
      onError('Download failed: $e');
    }
  }
}
