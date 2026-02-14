enum PoiCategory {
  museum,
  historicalSite,
  landmark,
  religiousSite,
  park,
  monument,
  university,
  theater,
  gallery,
  architecture,
  generic,
}

enum PoiInterestLevel {
  high, // Premium markers (star-shaped, golden)
  medium, // Standard blue markers
  low, // Smaller, subtle markers
}

class Poi {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final String description;
  final String? imageUrl;
  final String audio;
  final double interestScore;
  final PoiCategory category;
  final PoiInterestLevel interestLevel;
  final bool isDescriptionLoaded;

  Poi({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.description,
    this.imageUrl,
    required this.audio,
    this.interestScore = 0.0,
    this.category = PoiCategory.generic,
    this.interestLevel = PoiInterestLevel.low,
    this.isDescriptionLoaded = true,
  });

  factory Poi.fromJson(Map<String, dynamic> json) {
    return Poi(
      id: json['id'],
      name: json['name'],
      lat: json['lat'],
      lon: json['lon'],
      description: json['description'],
      imageUrl: json['imageUrl'],
      audio: json['audio'],
      interestScore: json['interestScore']?.toDouble() ?? 0.0,
      category: PoiCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => PoiCategory.generic,
      ),
      interestLevel: PoiInterestLevel.values.firstWhere(
        (l) => l.name == json['interestLevel'],
        orElse: () => PoiInterestLevel.low,
      ),
      isDescriptionLoaded: json['isDescriptionLoaded'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lon': lon,
      'description': description,
      'imageUrl': imageUrl,
      'audio': audio,
      'interestScore': interestScore,
      'category': category.name,
      'interestLevel': interestLevel.name,
      'isDescriptionLoaded': isDescriptionLoaded,
    };
  }

  /// Creates a copy of this POI with optionally updated fields.
  /// [description], [imageUrl], and [isDescriptionLoaded] override current
  /// values when provided.
  Poi copyWith({
    String? description,
    String? imageUrl,
    bool? isDescriptionLoaded,
  }) {
    return Poi(
      id: id,
      name: name,
      lat: lat,
      lon: lon,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      audio: audio,
      interestScore: interestScore,
      category: category,
      interestLevel: interestLevel,
      isDescriptionLoaded: isDescriptionLoaded ?? this.isDescriptionLoaded,
    );
  }
}
