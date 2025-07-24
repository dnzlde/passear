// example/test_mock_demo.dart
// Simple demonstration that the mock API client works
// Run with: dart example/test_mock_demo.dart

import '../lib/services/api_client.dart';
import '../lib/services/wikipedia_poi_service.dart';
import '../lib/services/poi_service.dart';
import 'dart:convert';

void main() async {
  print('🚀 Testing Mock API Client Implementation\n');
  
  // Test 1: Direct MockApiClient usage
  print('Test 1: Direct MockApiClient usage');
  final mockClient = MockApiClient();
  
  try {
    final url = Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json', 
      'list': 'geosearch',
      'gscoord': '32.0741|34.7924',
      'gsradius': '1000',
      'gslimit': '10',
    });
    
    final response = await mockClient.get(url);
    final data = jsonDecode(response);
    
    print('✅ Mock API returned ${data['query']['geosearch'].length} test locations');
    for (var location in data['query']['geosearch']) {
      print('   📍 ${location['title']} at ${location['lat']}, ${location['lon']}');
    }
  } catch (e) {
    print('❌ Test 1 failed: $e');
    return;
  }
  
  print('\nTest 2: WikipediaPoiService with MockApiClient');
  
  try {
    final wikiService = WikipediaPoiService(apiClient: mockClient);
    final pois = await wikiService.fetchNearbyPois(32.0741, 34.7924);
    
    print('✅ WikipediaPoiService returned ${pois.length} POIs');
    for (var poi in pois) {
      print('   📍 ${poi.title} at ${poi.lat}, ${poi.lon}');
    }
  } catch (e) {
    print('❌ Test 2 failed: $e');
    return;
  }
  
  print('\nTest 3: Full PoiService with MockApiClient');
  
  try {
    final poiService = PoiService(apiClient: mockClient);
    final pois = await poiService.fetchNearby(32.0741, 34.7924);
    
    print('✅ PoiService returned ${pois.length} POIs');
    for (var poi in pois) {
      print('   📍 ${poi.name} - ${poi.description}');
    }
  } catch (e) {
    print('❌ Test 3 failed: $e');
    return;
  }
  
  print('\n🎉 All tests passed! Mock API client is working correctly.');
  print('✅ Tests now run without making real network requests');
  print('✅ Deterministic responses for reliable testing');
  print('✅ Fast test execution without network delays');
}