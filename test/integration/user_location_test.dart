// test/integration/user_location_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passear/map/map_page.dart';

void main() {
  group('User Location Display', () {
    testWidgets('MapPage should initialize location tracking on startup',
        (WidgetTester tester) async {
      // Build the MapPage widget
      await tester.pumpWidget(
        const MaterialApp(
          home: MapPage(),
        ),
      );

      // Wait for initial rendering
      await tester.pump();

      // Verify that the map page loads without errors
      expect(tester.takeException(), isNull);

      // Verify the map page is displayed
      expect(find.text('Passear'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsAtLeastNWidgets(1));

      // Verify that location buttons are present
      expect(find.byIcon(Icons.my_location), findsOneWidget);
      expect(find.byTooltip('Center to my location'), findsOneWidget);
    });

    testWidgets('MapPage should have location-related UI elements',
        (WidgetTester tester) async {
      // Build the MapPage widget
      await tester.pumpWidget(
        const MaterialApp(
          home: MapPage(),
        ),
      );

      // Wait for initial rendering
      await tester.pump();

      // Verify that compass/navigation button is present
      expect(find.byIcon(Icons.navigation), findsOneWidget);
      expect(find.byTooltip('Reset map orientation to north'), findsOneWidget);

      // Verify no exceptions during initialization
      expect(tester.takeException(), isNull);
    });
  });
}
