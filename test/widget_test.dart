// This is a basic Flutter widget test for the Passear app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:passear/main.dart';

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
}
