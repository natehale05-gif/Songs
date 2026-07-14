import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songs/ui/home_screen.dart';

void main() {
  testWidgets('Home screen shows the main entry points', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));

    expect(find.text('Lead a session'), findsOneWidget);
    expect(find.text('Join a session'), findsOneWidget);
    expect(find.text('Song library'), findsOneWidget);
  });
}
