// lib/services/poi_telemetry.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Result of a tile cache lookup.
enum PoiCacheResult {
  /// Entry found and within TTL.
  hitFresh,

  /// Entry found but past TTL (stale-while-revalidate).
  hitStale,

  /// No entry found.
  miss,
}

/// Holds structured telemetry for a single viewport POI request lifecycle.
///
/// All logging is gated on [kDebugMode] so no metrics (including the hashed
/// viewport) are emitted in production builds.
class PoiRequestTrace {
  /// Opaque identifier unique within the process lifetime.
  final String requestId;

  /// Short hash of the viewport bounds — enables lifecycle correlation without
  /// exposing raw coordinates.
  final String viewportHash;

  final DateTime _startedAt;
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _staleHits = 0;
  int _retries = 0;
  String? _lastErrorClass;

  PoiRequestTrace({required this.requestId, required this.viewportHash})
      : _startedAt = DateTime.now() {
    if (kDebugMode) {
      debugPrint(
        '[POI Telemetry] [$requestId] START viewport=$viewportHash',
      );
    }
  }

  /// Records a tile cache lookup result.
  void recordCacheEvent(String tileKey, PoiCacheResult result) {
    switch (result) {
      case PoiCacheResult.hitFresh:
        _cacheHits++;
      case PoiCacheResult.hitStale:
        _staleHits++;
      case PoiCacheResult.miss:
        _cacheMisses++;
    }
    if (kDebugMode) {
      debugPrint(
        '[POI Telemetry] [$requestId] CACHE ${result.name} tile=$tileKey',
      );
    }
  }

  /// Records a single fetch attempt (attempt ≥ 1; attempt > 1 means retry).
  void recordFetchAttempt({required int attempt, String? errorClass}) {
    if (attempt > 1) _retries++;
    if (errorClass != null) _lastErrorClass = errorClass;
    if (kDebugMode) {
      final suffix = errorClass != null ? ' error=$errorClass' : '';
      debugPrint(
        '[POI Telemetry] [$requestId] FETCH attempt=$attempt$suffix',
      );
    }
  }

  /// Marks the request as complete and emits a summary log line.
  void complete({required int poiCount}) {
    if (!kDebugMode) return;
    final latencyMs = DateTime.now().difference(_startedAt).inMilliseconds;
    final errorSuffix =
        _lastErrorClass != null ? ' lastError=$_lastErrorClass' : '';
    debugPrint(
      '[POI Telemetry] [$requestId] DONE '
      'poiCount=$poiCount latencyMs=$latencyMs '
      'cacheHits=$_cacheHits cacheMisses=$_cacheMisses staleHits=$_staleHits '
      'retries=$_retries$errorSuffix',
    );
  }

  // Accessors exposed for testing.
  @visibleForTesting
  int get cacheHits => _cacheHits;
  @visibleForTesting
  int get cacheMisses => _cacheMisses;
  @visibleForTesting
  int get staleHits => _staleHits;
  @visibleForTesting
  int get retries => _retries;
  @visibleForTesting
  String? get lastErrorClass => _lastErrorClass;
}

/// Factory for creating [PoiRequestTrace] instances.
class PoiTelemetry {
  static int _counter = 0;

  /// Creates a new trace for a viewport request.
  ///
  /// Viewport coordinates are hashed (3-decimal precision, ~111 m) so that
  /// the log entries can be correlated without leaking exact positions.
  static PoiRequestTrace startTrace({
    required double north,
    required double south,
    required double east,
    required double west,
  }) {
    final id = 'poi_${++_counter}';
    final hash = _hashViewport(north, south, east, west);
    return PoiRequestTrace(requestId: id, viewportHash: hash);
  }

  /// Hashes viewport bounds to an 8-char hex string.
  static String _hashViewport(
    double north,
    double south,
    double east,
    double west,
  ) {
    final data = '${north.toStringAsFixed(3)}:${south.toStringAsFixed(3)}:'
        '${east.toStringAsFixed(3)}:${west.toStringAsFixed(3)}';
    final bytes = utf8.encode(data);
    return sha256.convert(bytes).toString().substring(0, 8);
  }
}
