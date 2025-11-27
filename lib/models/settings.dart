// lib/models/settings.dart
import 'poi.dart';

/// Map provider options
enum MapProvider {
  openStreetMap, // Free
  googleMaps, // Requires API key
}

/// Routing/Navigation provider options
enum RoutingProvider {
  osrm, // Free - Open Source Routing Machine
  googleDirections, // Requires API key
}

/// POI (Points of Interest) provider options
enum PoiProvider {
  wikipedia, // Free
  overpass, // Free - OpenStreetMap data
  googlePlaces, // Requires API key
}

/// AI Tour Guide provider options
enum AiTourGuideProvider {
  mock, // Built-in mock implementation (free)
  openAi, // OpenAI API (requires API key)
}

class AppSettings {
  final Map<PoiCategory, bool> enabledCategories;
  final int maxPoiCount;
  final bool voiceGuidanceEnabled;
  final MapProvider mapProvider;
  final RoutingProvider routingProvider;
  final PoiProvider poiProvider;
  final bool aiTourGuidingEnabled;
  final AiTourGuideProvider aiTourGuideProvider;

  AppSettings({
    Map<PoiCategory, bool>? enabledCategories,
    this.maxPoiCount = 20,
    this.voiceGuidanceEnabled = true,
    this.mapProvider = MapProvider.openStreetMap,
    this.routingProvider = RoutingProvider.osrm,
    this.poiProvider = PoiProvider.wikipedia,
    this.aiTourGuidingEnabled = false,
    this.aiTourGuideProvider = AiTourGuideProvider.mock,
  }) : enabledCategories = enabledCategories ?? _defaultEnabledCategories();

  static Map<PoiCategory, bool> _defaultEnabledCategories() {
    return {for (PoiCategory category in PoiCategory.values) category: true};
  }

  AppSettings copyWith({
    Map<PoiCategory, bool>? enabledCategories,
    int? maxPoiCount,
    bool? voiceGuidanceEnabled,
    MapProvider? mapProvider,
    RoutingProvider? routingProvider,
    PoiProvider? poiProvider,
    bool? aiTourGuidingEnabled,
    AiTourGuideProvider? aiTourGuideProvider,
  }) {
    return AppSettings(
      enabledCategories: enabledCategories ?? this.enabledCategories,
      maxPoiCount: maxPoiCount ?? this.maxPoiCount,
      voiceGuidanceEnabled: voiceGuidanceEnabled ?? this.voiceGuidanceEnabled,
      mapProvider: mapProvider ?? this.mapProvider,
      routingProvider: routingProvider ?? this.routingProvider,
      poiProvider: poiProvider ?? this.poiProvider,
      aiTourGuidingEnabled: aiTourGuidingEnabled ?? this.aiTourGuidingEnabled,
      aiTourGuideProvider: aiTourGuideProvider ?? this.aiTourGuideProvider,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final enabledCategoriesJson =
        json['enabledCategories'] as Map<String, dynamic>? ?? {};
    final enabledCategories = <PoiCategory, bool>{};

    for (PoiCategory category in PoiCategory.values) {
      enabledCategories[category] =
          enabledCategoriesJson[category.name] as bool? ?? true;
    }

    return AppSettings(
      enabledCategories: enabledCategories,
      maxPoiCount: json['maxPoiCount'] as int? ?? 20,
      voiceGuidanceEnabled: json['voiceGuidanceEnabled'] as bool? ?? true,
      mapProvider: MapProvider.values.firstWhere(
        (e) => e.name == json['mapProvider'],
        orElse: () => MapProvider.openStreetMap,
      ),
      routingProvider: RoutingProvider.values.firstWhere(
        (e) => e.name == json['routingProvider'],
        orElse: () => RoutingProvider.osrm,
      ),
      poiProvider: PoiProvider.values.firstWhere(
        (e) => e.name == json['poiProvider'],
        orElse: () => PoiProvider.wikipedia,
      ),
      aiTourGuidingEnabled: json['aiTourGuidingEnabled'] as bool? ?? false,
      aiTourGuideProvider: AiTourGuideProvider.values.firstWhere(
        (e) => e.name == json['aiTourGuideProvider'],
        orElse: () => AiTourGuideProvider.mock,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabledCategories': {
        for (var entry in enabledCategories.entries)
          entry.key.name: entry.value,
      },
      'maxPoiCount': maxPoiCount,
      'voiceGuidanceEnabled': voiceGuidanceEnabled,
      'mapProvider': mapProvider.name,
      'routingProvider': routingProvider.name,
      'poiProvider': poiProvider.name,
      'aiTourGuidingEnabled': aiTourGuidingEnabled,
      'aiTourGuideProvider': aiTourGuideProvider.name,
    };
  }

  /// Get count of enabled categories
  int get enabledCategoryCount =>
      enabledCategories.values.where((enabled) => enabled).length;

  /// Check if a category is enabled
  bool isCategoryEnabled(PoiCategory category) =>
      enabledCategories[category] ?? true;

  /// Check if the current map provider is free
  bool get isMapProviderFree => mapProvider == MapProvider.openStreetMap;

  /// Check if the current routing provider is free
  bool get isRoutingProviderFree => routingProvider == RoutingProvider.osrm;

  /// Check if the current POI provider is free
  bool get isPoiProviderFree =>
      poiProvider == PoiProvider.wikipedia ||
      poiProvider == PoiProvider.overpass;

  /// Check if all providers are free
  bool get areAllProvidersFree =>
      isMapProviderFree && isRoutingProviderFree && isPoiProviderFree;
}

/// Extension methods for provider enums
extension MapProviderExtension on MapProvider {
  String get displayName {
    switch (this) {
      case MapProvider.openStreetMap:
        return 'OpenStreetMap';
      case MapProvider.googleMaps:
        return 'Google Maps';
    }
  }

  bool get isFree => this == MapProvider.openStreetMap;

  String get description {
    switch (this) {
      case MapProvider.openStreetMap:
        return 'Free, community-driven map';
      case MapProvider.googleMaps:
        return 'Requires API key';
    }
  }
}

extension RoutingProviderExtension on RoutingProvider {
  String get displayName {
    switch (this) {
      case RoutingProvider.osrm:
        return 'OSRM';
      case RoutingProvider.googleDirections:
        return 'Google Directions';
    }
  }

  bool get isFree => this == RoutingProvider.osrm;

  String get description {
    switch (this) {
      case RoutingProvider.osrm:
        return 'Free, open-source routing';
      case RoutingProvider.googleDirections:
        return 'Requires API key';
    }
  }
}

extension PoiProviderExtension on PoiProvider {
  String get displayName {
    switch (this) {
      case PoiProvider.wikipedia:
        return 'Wikipedia';
      case PoiProvider.overpass:
        return 'OpenStreetMap POIs';
      case PoiProvider.googlePlaces:
        return 'Google Places';
    }
  }

  bool get isFree =>
      this == PoiProvider.wikipedia || this == PoiProvider.overpass;

  String get description {
    switch (this) {
      case PoiProvider.wikipedia:
        return 'Free, encyclopedia-based POIs';
      case PoiProvider.overpass:
        return 'Free, OpenStreetMap data';
      case PoiProvider.googlePlaces:
        return 'Requires API key';
    }
  }
}

extension AiTourGuideProviderExtension on AiTourGuideProvider {
  String get displayName {
    switch (this) {
      case AiTourGuideProvider.mock:
        return 'Built-in Guide';
      case AiTourGuideProvider.openAi:
        return 'OpenAI';
    }
  }

  bool get isFree => this == AiTourGuideProvider.mock;

  String get description {
    switch (this) {
      case AiTourGuideProvider.mock:
        return 'Free, contextual narrations';
      case AiTourGuideProvider.openAi:
        return 'Requires API key';
    }
  }
}
