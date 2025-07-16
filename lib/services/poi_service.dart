// lib/services/poi_service.dart
import '../models/poi.dart';
import 'wikipedia_poi_service.dart';

class PoiService {
  final WikipediaPoiService _wikiService = WikipediaPoiService();

  Future<List<Poi>> fetchNearby(double lat, double lon) async {
    final wikiPois = await _wikiService.fetchNearbyWithDescriptions(lat, lon);

    return wikiPois.map((wikiPoi) {
      return Poi(
        id: wikiPoi.title, // используем title как ID
        name: wikiPoi.title,
        lat: wikiPoi.lat,
        lon: wikiPoi.lon,
        description: wikiPoi.description ?? '',
        audio: '', // позже можно будет сгенерировать/добавить
      );
    }).toList();
  }
}
