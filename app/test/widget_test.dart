// Smoke test: the app boots and renders its landing screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gymbuddy/main.dart';

void main() {
  testWidgets('GymBuddy app boots and shows the landing screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GymBuddyApp());

    expect(find.text('GymBuddy'), findsOneWidget);
    expect(find.text('Your AI training buddy'), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
  });
}
