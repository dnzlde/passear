// lib/services/poi_cache/poi_tile_storage.dart
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'poi_cache_entry.dart';

/// Storage layer for POI tile cache using Hive
class PoiTileStorage {
  static const String _boxName = 'poi_tile_cache';
  Box<String>? _box;
  bool _isInitialized = false;

  /// Initialize Hive storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
    _isInitialized = true;
  }

  /// Ensure storage is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// Get a cache entry by key
  Future<PoiCacheEntry?> get(String key) async {
    await _ensureInitialized();
    final jsonString = _box!.get(key);
    if (jsonString == null) return null;

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return PoiCacheEntry.fromJson(json);
    } catch (e) {
      // If deserialization fails, remove the corrupted entry
      await _box!.delete(key);
      return null;
    }
  }

  /// Put a cache entry
  Future<void> put(String key, PoiCacheEntry entry) async {
    await _ensureInitialized();
    final jsonString = jsonEncode(entry.toJson());
    await _box!.put(key, jsonString);
  }

  /// Delete a cache entry
  Future<void> delete(String key) async {
    await _ensureInitialized();
    await _box!.delete(key);
  }

  /// Get all cache keys
  Future<List<String>> getAllKeys() async {
    await _ensureInitialized();
    return _box!.keys.cast<String>().toList();
  }

  /// Get the number of entries in cache
  Future<int> getSize() async {
    await _ensureInitialized();
    return _box!.length;
  }

  /// Clear all cache entries
  Future<void> clear() async {
    await _ensureInitialized();
    if (_box?.isOpen == true) {
      await _box!.clear();
    }
  }

  /// Close the storage (cleanup)
  Future<void> close() async {
    if (_isInitialized && _box?.isOpen == true) {
      await _box?.close();
      _isInitialized = false;
    }
  }
}
