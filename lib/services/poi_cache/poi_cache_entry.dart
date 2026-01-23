// lib/services/poi_cache/poi_cache_entry.dart
import '../../models/poi.dart';

/// Cache entry for a tile of POIs with metadata for TTL and LRU eviction
class PoiCacheEntry {
  final List<Poi> pois;
  final DateTime updatedAt;
  final DateTime lastAccessedAt;

  PoiCacheEntry({
    required this.pois,
    required this.updatedAt,
    required this.lastAccessedAt,
  });

  /// Check if this cache entry is still valid based on TTL
  bool isValid(Duration ttl) {
    final age = DateTime.now().difference(updatedAt);
    return age <= ttl;
  }

  /// Create a copy with updated lastAccessedAt timestamp
  PoiCacheEntry copyWithAccess() {
    return PoiCacheEntry(
      pois: pois,
      updatedAt: updatedAt,
      lastAccessedAt: DateTime.now(),
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'pois': pois.map((poi) => poi.toJson()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastAccessedAt': lastAccessedAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory PoiCacheEntry.fromJson(Map<String, dynamic> json) {
    return PoiCacheEntry(
      pois: (json['pois'] as List)
          .map((poiJson) => Poi.fromJson(poiJson as Map<String, dynamic>))
          .toList(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastAccessedAt: DateTime.parse(json['lastAccessedAt'] as String),
    );
  }
}
