// lib/services/wikipedia_poi_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class WikipediaPoi {
  final String title;
  final double lat;
  final double lon;
  String? description;

  WikipediaPoi({
    required this.title,
    required this.lat,
    required this.lon,
    this.description,
  });
}

class WikipediaPoiService {
  final String lang;

  WikipediaPoiService({this.lang = 'en'});

  Future<List<WikipediaPoi>> fetchNearbyPois(double lat, double lon,
      {int radius = 1000, int limit = 10}) async {
    if (radius > 10000) radius = 10000;
    final url = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'list': 'geosearch',
      'gscoord': '$lat|$lon',
      'gsradius': radius.toString(),
      'gslimit': limit.toString(),
    });

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['query']['geosearch'] as List;
      return results.map((e) {
        return WikipediaPoi(
          title: e['title'],
          lat: e['lat'],
          lon: e['lon'],
        );
      }).toList();
    } else {
      throw Exception('Failed to fetch POIs from Wikipedia');
    }
  }

  Future<String?> fetchDescription(String title) async {
    final url = Uri.https('$lang.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'prop': 'extracts',
      'exintro': '1',
      'explaintext': '1',
      'titles': title,
    });

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final pages = data['query']['pages'] as Map<String, dynamic>;
      final page = pages.values.first;
      return page['extract'];
    } else {
      return null;
    }
  }

  Future<List<WikipediaPoi>> fetchNearbyWithDescriptions(double lat, double lon,
      {int radius = 1000, int limit = 10}) async {
    final pois = await fetchNearbyPois(lat, lon, radius: radius, limit: limit);
    for (final poi in pois) {
      poi.description = await fetchDescription(poi.title);
    }
    return pois;
  }
}
