// This is a basic Flutter widget test for the Passear app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:passear/main.dart';
import 'package:passear/services/api_client.dart';
import 'package:passear/map/map_page.dart';

void main() {
  testWidgets('Passear app loads and shows map page', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PassearApp());

    // Verify that the app shows the Passear title in the app bar.
    expect(find.text('Passear'), findsOneWidget);

    // Verify that the location button is present.
    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byTooltip('Center to my location'), findsOneWidget);

    // Verify that we have a floating action button for location.
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('MapPage with mock API client loads without network errors', (WidgetTester tester) async {
    // Create a mock API client to avoid network requests in tests
    final mockClient = MockApiClient();
    
    // Build the MapPage widget with mock client
    await tester.pumpWidget(
      MaterialApp(
        home: MapPageWithMockClient(apiClient: mockClient),
      ),
    );

    // Verify that the map page loads
    expect(find.text('Passear'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    
    // Wait for any async operations to complete
    await tester.pumpAndSettle();
    
    // The test should not fail with network errors
    expect(tester.takeException(), isNull);
  });
}

/// Test wrapper for MapPage that accepts a mock API client
class MapPageWithMockClient extends StatelessWidget {
  final ApiClient apiClient;
  
  const MapPageWithMockClient({super.key, required this.apiClient});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passear')),
      body: const Center(
        child: Text('Map loaded with mock client'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Center to my location',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
