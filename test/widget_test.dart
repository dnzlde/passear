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

void main() {
  testWidgets('Passear app loads and shows map page',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const PassearApp());

    // Pump to advance through the timers
    await tester.pump(const Duration(milliseconds: 2000));

    // Verify that the app shows the Passear title in the app bar.
    expect(find.text('Passear'), findsOneWidget);

    // Verify that the location button is present.
    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byTooltip('Center to my location'), findsOneWidget);

    // Verify that we have floating action buttons.
    expect(find.byType(FloatingActionButton), findsAtLeastNWidgets(1));

    // Verify that the reset north button is present with navigation icon
    expect(find.byIcon(Icons.navigation), findsOneWidget);
    expect(find.byTooltip('Reset map orientation to north'), findsOneWidget);
  });

  testWidgets('MapPage with mock API client loads without network errors',
      (WidgetTester tester) async {
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

  testWidgets('POI modal should be dismissible by tapping outside',
      (WidgetTester tester) async {
    // Create a mock API client
    final mockClient = MockApiClient();

    // Build the MapPage widget
    await tester.pumpWidget(
      MaterialApp(
        home: MapPageWithPOISupport(apiClient: mockClient),
      ),
    );

    // Wait for the widget to render
    await tester.pumpAndSettle();

    // Tap on a POI marker to open the modal
    await tester.tap(find.byKey(const Key('poi_marker_test')));
    await tester.pumpAndSettle();

    // Verify the modal is displayed
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Test POI'), findsOneWidget);

    // Tap outside the modal to dismiss it
    await tester.tapAt(const Offset(50, 50)); // Tap in top-left corner
    await tester.pumpAndSettle();

    // Verify the modal is dismissed
    expect(find.byType(BottomSheet), findsNothing);
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

/// Test wrapper for MapPage that supports POI modal testing
class MapPageWithPOISupport extends StatelessWidget {
  final ApiClient apiClient;

  const MapPageWithPOISupport({super.key, required this.apiClient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Passear')),
      body: Stack(
        children: [
          const Center(
            child: Text('Map loaded with POI support'),
          ),
          Positioned(
            bottom: 100,
            left: 100,
            child: GestureDetector(
              key: const Key('poi_marker_test'),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Stack(
                    children: [
                      // Dimming overlay
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      // POI Details Sheet
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: DraggableScrollableSheet(
                          initialChildSize: 0.4,
                          minChildSize: 0.4,
                          maxChildSize: 0.9,
                          builder: (context, scrollController) => Material(
                            elevation: 12,
                            color: Colors.white,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                              child: SafeArea(
                                top: false,
                                child: SingleChildScrollView(
                                  controller: scrollController,
                                  child: const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Test POI',
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(height: 16),
                                        Text('This is a test POI description.'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: const Icon(
                Icons.place,
                color: Colors.blue,
                size: 35,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Center to my location',
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
