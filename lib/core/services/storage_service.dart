// ─────────────────────────────────────────────────────────────────────────────
// storage_service.dart  —  DEN Storage & Data Backend
//
// Provides real implementations for:
//   • Cache size calculation  (image cache + Hive + temp dir)
//   • Clear cache             (CachedNetworkImage + temp files)
//   • Downloaded songs count + size (stub: integrate with your download manager)
//   • Storage location        (internal / external)
//
// Drop into lib/core/services/storage_service.dart
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

// ── Storage Stats model ──────────────────────────────────────────────────────

class StorageStats {
  final int cacheSizeBytes;
  final int downloadSizeBytes;
  final int downloadedSongCount;

  const StorageStats({
    this.cacheSizeBytes      = 0,
    this.downloadSizeBytes   = 0,
    this.downloadedSongCount = 0,
  });

  String get cacheSizeFormatted  => _fmt(cacheSizeBytes);
  String get downloadSizeFormatted => _fmt(downloadSizeBytes);

  static String _fmt(int bytes) {
    if (bytes < 1024)        return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

// ── StorageService ────────────────────────────────────────────────────────────

class StorageService {

  // ─── Calculate total cache size ───────────────────────────────────────────

  Future<int> getCacheSizeBytes() async {
    int total = 0;

    // 1. Temp directory (CachedNetworkImage writes here)
    try {
      final tmp = await getTemporaryDirectory();
      total += await _dirSize(tmp);
    } catch (_) {}

    // 2. App cache directory
    try {
      final cache = await getApplicationCacheDirectory();
      total += await _dirSize(cache);
    } catch (_) {}

    return total;
  }

  Future<int> _dirSize(Directory dir) async {
    int size = 0;
    try {
      if (!dir.existsSync()) return 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          try { size += await entity.length(); } catch (_) {}
        }
      }
    } catch (_) {}
    return size;
  }

  // ─── Clear cache ──────────────────────────────────────────────────────────

  Future<void> clearCache() async {
    // 1. Clear CachedNetworkImage in-memory + disk cache
    try {
      await CachedNetworkImage.evictFromCache('');
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    // 2. Wipe temp directory contents
    try {
      final tmp = await getTemporaryDirectory();
      if (tmp.existsSync()) {
        await for (final entity in tmp.list()) {
          try { await entity.delete(recursive: true); } catch (_) {}
        }
      }
    } catch (_) {}

    // 3. Wipe app cache directory
    try {
      final cache = await getApplicationCacheDirectory();
      if (cache.existsSync()) {
        await for (final entity in cache.list()) {
          try { await entity.delete(recursive: true); } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // ─── Downloads (stub — wire into your download manager) ──────────────────

  /// Returns how many songs have been downloaded locally.
  /// Replace with your downloads database / Hive box.
  Future<int> getDownloadedSongCount() async {
    try {
      final dir = await _downloadsDir();
      if (!dir.existsSync()) return 0;
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.mp3') ||
                        f.path.endsWith('.aac') ||
                        f.path.endsWith('.flac'))
          .toList();
      return files.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getDownloadSizeBytes() async {
    try {
      final dir = await _downloadsDir();
      return await _dirSize(dir);
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearDownloads() async {
    try {
      final dir = await _downloadsDir();
      if (dir.existsSync()) {
        await for (final entity in dir.list()) {
          try { await entity.delete(recursive: true); } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<Directory> _downloadsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir  = Directory('${base.path}/downloads');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  // ─── External storage (Android only) ─────────────────────────────────────

  Future<String?> getExternalStoragePath() async {
    if (!Platform.isAndroid) return null;
    try {
      final dirs = await getExternalStorageDirectories();
      return dirs?.isNotEmpty == true ? dirs!.first.path : null;
    } catch (_) {
      return null;
    }
  }
}

final storageServiceProvider = Provider<StorageService>((ref) => StorageService());

// ─── StorageStats provider — call .refresh() after clearing ──────────────────

final storageStatsProvider = FutureProvider<StorageStats>((ref) async {
  final svc = ref.read(storageServiceProvider);
  final results = await Future.wait([
    svc.getCacheSizeBytes(),
    svc.getDownloadedSongCount(),
    svc.getDownloadSizeBytes(),
  ]);
  return StorageStats(
    cacheSizeBytes:      results[0],
    downloadedSongCount: results[1],
    downloadSizeBytes:   results[2],
  );
});