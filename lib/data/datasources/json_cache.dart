import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small JSON cache backed by memory and by a file each.
///
/// Used for the parts of the transit data that barely change, so the app
/// does not download them again on every launch.
class JsonCache {
  final Map<String, ({DateTime savedAt, Object? value})> _memory = {};
  Directory? _directory;

  /// Cache that keeps nothing, for tests
  factory JsonCache.noop() = _NoopJsonCache;

  JsonCache();

  /// Cached value for [key], or null when missing or older than [maxAge]
  Future<Object?> read(String key, {Duration? maxAge}) async {
    final cached = _memory[key];
    if (cached != null) {
      if (!_isStale(cached.savedAt, maxAge)) return cached.value;
      _memory.remove(key);
    }

    try {
      final file = await _fileFor(key);
      if (!await file.exists()) return null;

      final decoded = json.decode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return null;

      final savedAt = DateTime.fromMillisecondsSinceEpoch(
        (decoded['savedAt'] as num).toInt(),
      );
      if (_isStale(savedAt, maxAge)) return null;

      _memory[key] = (savedAt: savedAt, value: decoded['value']);
      return decoded['value'];
    } catch (_) {
      // A cache miss is always an acceptable answer.
      return null;
    }
  }

  Future<void> write(String key, Object? value) async {
    final savedAt = DateTime.now();
    _memory[key] = (savedAt: savedAt, value: value);

    try {
      final file = await _fileFor(key);
      await file.writeAsString(
        json.encode({
          'savedAt': savedAt.millisecondsSinceEpoch,
          'value': value,
        }),
      );
    } catch (_) {
      // Memory-only is good enough when the disk is not available.
    }
  }

  bool _isStale(DateTime savedAt, Duration? maxAge) {
    if (maxAge == null) return false;
    return DateTime.now().difference(savedAt) > maxAge;
  }

  Future<File> _fileFor(String key) async {
    final directory = _directory ??= await _cacheDirectory();
    return File('${directory.path}/$key.json');
  }

  Future<Directory> _cacheDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final directory = Directory('${base.path}/cache');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }
}

class _NoopJsonCache extends JsonCache {
  @override
  Future<Object?> read(String key, {Duration? maxAge}) async => null;

  @override
  Future<void> write(String key, Object? value) async {}
}
