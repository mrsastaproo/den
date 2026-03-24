import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import 'settings_service.dart';
import 'api_service.dart';

class DownloadService {
  final Dio _dio = Dio();
  final Ref _ref;
  Box? _box;

  DownloadService(this._ref);

  Future<Box> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox('downloaded_songs');
    return _box!;
  }

  Future<Directory> _downloadsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/downloads');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<String> getDownloadPath(String songId) async {
    final dir = await _downloadsDir();
    return '${dir.path}/$songId.mp3';
  }

  Future<bool> isDownloaded(String songId) async {
    final path = await getDownloadPath(songId);
    final exists = File(path).existsSync();
    if (!exists) return false;

    final box = await _getBox();
    return box.containsKey(songId);
  }

  Future<void> downloadSong(Song song, {String? resolvedUrl, Function(double)? onProgress}) async {
    if (await isDownloaded(song.id)) return;

    try {
      final path = await getDownloadPath(song.id);
      
      // 1. Resolve the correct quality URL if not provided
      String downloadUrl = resolvedUrl ?? '';
      
      if (downloadUrl.isEmpty) {
        final quality = _ref.read(downloadQualityProvider);
        _log('Resolving $quality URL for download: ${song.title}');
        downloadUrl = await _ref.read(apiServiceProvider).getStreamUrl(song.id, quality: quality);
      }

      if (downloadUrl.isEmpty) {
         throw Exception('Could not resolve download URL');
      }

      await _dio.download(
        downloadUrl,
        path,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress?.call(received / total);
          }
        },
      );

      // 2. Save metadata to Hive
      final box = await _getBox();
      await box.put(song.id, song.toJson());
      _log('Download complete: ${song.title}');

    } catch (e) {
      _log('Error downloading ${song.id}: $e');
      // Cleanup on failure
      final path = await getDownloadPath(song.id);
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
      rethrow;
    }
  }

  Future<List<Song>> getDownloadedSongs() async {
    final box = await _getBox();
    final list = <Song>[];
    for (final key in box.keys) {
      final json = box.get(key);
      if (json != null) {
         try {
           // Hive stores as Map<dynamic, dynamic> sometimes
           final map = Map<String, dynamic>.from(json);
           list.add(Song.fromJson(map));
         } catch (e) {
           print('Error parsing downloaded song $key: $e');
         }
      }
    }
    // Verify file exists for each metadata entry
    final verified = <Song>[];
    for (final s in list) {
       final path = await getDownloadPath(s.id);
       if (File(path).existsSync()) {
          verified.add(s);
       } else {
          // Cleanup orphan metadata
          final box = await _getBox();
          await box.delete(s.id);
       }
    }
    return verified;
  }

  Future<void> deleteDownload(String songId) async {
    try {
      final path = await getDownloadPath(songId);
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
      final box = await _getBox();
      await box.delete(songId);
    } catch (e) {
      print('Error deleting download $songId: $e');
    }
  }

  Future<void> clearAllDownloads() async {
    try {
      final dir = await _downloadsDir();
      if (dir.existsSync()) {
        await for (final entity in dir.list()) {
          try {
            await entity.delete(recursive: true);
          } catch (e) {
            _log('Error deleting file ${entity.path}: $e');
          }
        }
      }
      final box = await _getBox();
      await box.clear();
      _log('All downloads cleared from disk and database');
    } catch (e) {
      _log('Error clearing downloads: $e');
    }
  }
  void _log(String msg) => print('[DOWNLOAD] $msg');
}

final downloadServiceProvider = Provider<DownloadService>((ref) => DownloadService(ref));

final downloadedSongsProvider = FutureProvider<List<Song>>((ref) async {
  return ref.watch(downloadServiceProvider).getDownloadedSongs();
});
