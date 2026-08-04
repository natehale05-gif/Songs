import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songs_of_the_church/billing/billing_config.dart';
import 'package:songs_of_the_church/billing/paywall_sheet.dart';
import 'package:songs_of_the_church/theme.dart';

/// Opens the paywall. The returned box holds what the sheet eventually popped
/// with — it is still empty when this returns, since the sheet has only just
/// opened and nothing has been tapped yet.
Future<List<bool?>> _open(
  WidgetTester tester, {
  required Future<bool> Function() onSubscribe,
  Future<bool> Function()? onRestore,
  PlusOffer offer = const PlusOffer.fallback(),
}) async {
  final List<bool?> outcome = <bool?>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              outcome.add(await showPaywall(
                context,
                AppPalette.light,
                feature: PlusFeature.setList,
                offer: offer,
                onSubscribe: onSubscribe,
                onRestore: onRestore ?? () async => false,
              ));
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return outcome;
}

void main() {
  testWidgets('shows everything App Review requires next to the price',
      (tester) async {
    await _open(tester, onSubscribe: () async => true);

    // Name, period and price.
    expect(find.text(kPlusName), findsOneWidget);
    expect(find.text('\$12 per year'), findsOneWidget);

    // The renewal terms, in substance rather than by exact wording.
    final disclosure = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((s) => s.contains('renews automatically'), orElse: () => '');
    expect(disclosure, isNotEmpty,
        reason: 'the auto-renewal terms must appear on the purchase screen');
    expect(disclosure, contains('24 hours'));
    expect(disclosure, contains('cancelled'));

    // Both links, and the restore path.
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Restore Purchases'), findsOneWidget);
    expect(find.text('Subscribe'), findsOneWidget);
  });

  testWidgets('says plainly that the hymnal itself stays free',
      (tester) async {
    await _open(tester, onSubscribe: () async => true);
    final free = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .any((s) => s.contains('stay free'));
    expect(free, isTrue);
  });

  testWidgets('prefers the store\'s own localised price', (tester) async {
    await _open(
      tester,
      onSubscribe: () async => true,
      offer: const PlusOffer(id: kPlusProductId, price: '£10.99'),
    );
    expect(find.text('£10.99 per year'), findsOneWidget);
    expect(find.text('\$12 per year'), findsNothing,
        reason: 'showing a USD price to a UK buyer is a rejection and a lie');
  });

  testWidgets('a successful purchase closes the sheet as entitled',
      (tester) async {
    final outcome = await _open(tester, onSubscribe: () async => true);
    expect(outcome, isEmpty, reason: 'nothing has been tapped yet');

    await tester.tap(find.text('Subscribe'));
    await tester.pumpAndSettle();

    expect(find.text('Subscribe'), findsNothing, reason: 'the sheet closed');
    expect(outcome.single, isTrue);
  });

  testWidgets('a failed purchase keeps the sheet open and explains',
      (tester) async {
    await _open(tester, onSubscribe: () async => false);
    await tester.tap(find.text('Subscribe'));
    await tester.pumpAndSettle();

    expect(find.text('Subscribe'), findsOneWidget,
        reason: 'the sheet must not close on failure');
    expect(find.textContaining('Nothing was charged'), findsOneWidget);
  });

  testWidgets('a restore with nothing to restore says so', (tester) async {
    await _open(
      tester,
      onSubscribe: () async => false,
      onRestore: () async => false,
    );
    await tester.tap(find.text('Restore Purchases'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No previous subscription'), findsOneWidget);
  });

  testWidgets('a purchase that throws is reported, not swallowed',
      (tester) async {
    await _open(tester, onSubscribe: () async => throw Exception('store down'));
    await tester.tap(find.text('Subscribe'));
    await tester.pumpAndSettle();
    expect(find.textContaining('did not go through'), findsOneWidget);
  });
}
