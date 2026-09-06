import 'dart:io';

import 'package:path_provider/path_provider.dart';

class CacheClearResult {
  const CacheClearResult({required this.bytesFreed, required this.success});

  final int bytesFreed;
  final bool success;
}

class CacheService {
  CacheService._();

  static final CacheService instance = CacheService._();

  Future<int> getCacheSize() async {
    var total = 0;
    try {
      total += await _dirSize(await getTemporaryDirectory());
    } catch (_) {}

    try {
      total += await _dirSize(await getApplicationCacheDirectory());
    } catch (_) {}

    return total;
  }

  Future<CacheClearResult> clearCache() async {
    try {
      var bytesFreed = 0;
      bytesFreed += await _clearDirectory(await getTemporaryDirectory());

      try {
        bytesFreed += await _clearDirectory(await getApplicationCacheDirectory());
      } catch (_) {}

      return CacheClearResult(bytesFreed: bytesFreed, success: true);
    } catch (_) {
      return const CacheClearResult(bytesFreed: 0, success: false);
    }
  }

  Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;

    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (_) {
          // Some files (lock files held by another running process,
          // permission-restricted temp files, files deleted mid-scan)
          // can't be read — skip rather than crash the whole calculation.
        }
      }
    }
    return total;
  }

  Future<int> _clearDirectory(Directory dir) async {
    if (!await dir.exists()) return 0;

    var bytesFreed = 0;
    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      try {
        if (entity is File) {
          bytesFreed += await entity.length();
          await entity.delete();
        } else if (entity is Directory) {
          bytesFreed += await _dirSize(entity);
          await entity.delete(recursive: true);
        }
      } catch (_) {}
    }
    return bytesFreed;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
