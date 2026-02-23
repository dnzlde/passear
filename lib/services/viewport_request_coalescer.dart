// lib/services/viewport_request_coalescer.dart

/// Coalesces duplicate in-flight viewport POI requests.
///
/// When a new [_loadPoisInView] call arrives with the same normalised viewport
/// bounds and filter descriptor as the currently in-flight request, the caller
/// should skip starting a new request — the existing one already covers the
/// same viewport.
///
/// A new key (different bounds, or changed provider/filters) always starts a
/// fresh request, independent of any in-flight state.
///
/// Usage pattern (inside MapPage._loadPoisInView):
/// ```dart
/// if (_isLoadingPois && _poiCoalescer.shouldCoalesce(key)) {
///   return; // identical request already in-flight
/// }
/// _poiCoalescer.beginRequest(key);
/// try {
///   // ... await fetchInBounds(...) ...
/// } finally {
///   _poiCoalescer.endRequest(key);
/// }
/// ```
class ViewportRequestCoalescer {
  /// Number of decimal places used when normalising lat/lon coordinates.
  /// 4 decimal places ≈ 11 m precision at the equator, which is well below
  /// the minimum POI-reload movement threshold (50 m).
  static const int boundsDecimalPlaces = 4;

  String? _inflightKey;

  /// Builds a stable string key for a viewport request from its normalised
  /// bounds and an optional filter descriptor (e.g. provider name).
  static String buildKey({
    required double north,
    required double south,
    required double east,
    required double west,
    String filtersHash = '',
  }) {
    String n(double v) => v.toStringAsFixed(boundsDecimalPlaces);
    return '${n(north)}:${n(south)}:${n(east)}:${n(west)}:$filtersHash';
  }

  /// Returns `true` when [key] matches the currently in-flight request.
  ///
  /// A `true` result means the caller should skip starting a new request
  /// because an identical one is already in-flight.
  bool shouldCoalesce(String key) => _inflightKey == key;

  /// Marks [key] as the key of the newly-started in-flight request.
  void beginRequest(String key) {
    _inflightKey = key;
  }

  /// Clears the in-flight state for [key] once the request has finished
  /// (succeeded, failed, or was cancelled).  If [key] does not match the
  /// current in-flight key this call is a no-op.
  void endRequest(String key) {
    if (_inflightKey == key) {
      _inflightKey = null;
    }
  }

  /// Resets all state.  Call this when the provider or filters change so that
  /// the next request is never incorrectly coalesced with a stale key.
  void reset() {
    _inflightKey = null;
  }
}
