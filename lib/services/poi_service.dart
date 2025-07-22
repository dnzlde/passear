// lib/services/poi_service.dart
import '../models/poi.dart';
import 'wikipedia_poi_service.dart';

class PoiService {
  final WikipediaPoiService _wikiService = WikipediaPoiService();

  Future<List<Poi>> fetchNearby(double lat, double lon, {int radius = 1000}) async {
    final wikiPois = await _wikiService.fetchNearbyWithDescriptions(lat, lon, radius: radius);

    return wikiPois.map((wikiPoi) {
      return Poi(
        id: wikiPoi.title, // используем title как ID
        name: wikiPoi.title,
        lat: wikiPoi.lat,
        lon: wikiPoi.lon,
        description: wikiPoi.description ?? '',
        audio: '', // will be generated/added later
      );
    }).toList();
  }
}
