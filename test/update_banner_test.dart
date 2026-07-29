import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songs_of_the_church/theme.dart';
import 'package:songs_of_the_church/update/update_banner.dart';
import 'package:songs_of_the_church/update/update_service.dart';

Widget _host(Future<AppUpdate?> Function() check) => MaterialApp(
      home: Scaffold(
        body: UpdateBanner(palette: AppPalette.light, checkOverride: check),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows nothing when there is no update', (tester) async {
    await tester.pumpWidget(_host(() async => null));
    await tester.pumpAndSettle();
    expect(find.textContaining('available'), findsNothing);
  });

  testWidgets('offers the new version when one exists', (tester) async {
    await tester.pumpWidget(_host(() async => const AppUpdate(
          version: '1.2.0',
          downloadUrl: 'https://example.test/app.apk',
        )));
    await tester.pumpAndSettle();
    expect(find.textContaining('1.2.0'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
  });

  testWidgets('dismissing hides it and remembers that version', (tester) async {
    await tester.pumpWidget(_host(() async => const AppUpdate(
          version: '1.2.0',
          downloadUrl: 'https://example.test/app.apk',
        )));
    await tester.pumpAndSettle();
    expect(find.textContaining('1.2.0'), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1.2.0'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('update_dismissed_version'), '1.2.0');
  });

  testWidgets('a previously dismissed version stays hidden', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'update_dismissed_version': '1.2.0'});
    await tester.pumpWidget(_host(() async => const AppUpdate(
          version: '1.2.0',
          downloadUrl: 'https://example.test/app.apk',
        )));
    await tester.pumpAndSettle();
    expect(find.textContaining('1.2.0'), findsNothing);
  });

  testWidgets('a newer version reappears after an older one was dismissed',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'update_dismissed_version': '1.2.0'});
    await tester.pumpWidget(_host(() async => const AppUpdate(
          version: '1.3.0',
          downloadUrl: 'https://example.test/app.apk',
        )));
    await tester.pumpAndSettle();
    expect(find.textContaining('1.3.0'), findsOneWidget);
  });
}
