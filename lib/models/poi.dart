class Poi {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final String description;
  final String audio;

  Poi({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.description,
    required this.audio,
  });

  factory Poi.fromJson(Map<String, dynamic> json) {
    return Poi(
      id: json['id'],
      name: json['name'],
      lat: json['lat'],
      lon: json['lon'],
      description: json['description'],
      audio: json['audio'],
    );
  }
}
