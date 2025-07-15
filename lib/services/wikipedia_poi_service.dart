import 'dart:convert';
import 'package:http/http.dart' as http;

class WikipediaPoi {
  final String title;
  final double lat;
  final double lon;

  WikipediaPoi({required this.title, required this.lat, required this.lon});
}

class WikipediaPoiService {
  final String lang;

  WikipediaPoiService({this.lang = 'en'});

  Future<List<WikipediaPoi>> fetchNearbyPois(double lat, double lon,
      {int radius = 1000, int limit = 10}) async {
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
}
