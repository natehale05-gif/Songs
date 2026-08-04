import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songs_of_the_church/billing/billing_config.dart';
import 'package:songs_of_the_church/billing/paywall_sheet.dart';
import 'package:songs_of_the_church/theme.dart';

/// Opens the paywall at [stage]. The returned box holds what the sheet
/// eventually popped with — empty until something is tapped.
Future<List<bool?>> _open(
  WidgetTester tester, {
  required PaywallStage stage,
  Future<bool> Function()? onSignIn,
  Future<bool> Function()? onPurchase,
  Future<bool> Function()? onRecheck,
  PlusOffer offer = const PlusOffer.fallback(),
}) async {
  final List<bool?> outcome = <bool?>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async => outcome.add(await showPaywall(
              context,
              AppPalette.light,
              feature: PlusFeature.setList,
              stage: stage,
              offer: offer,
              onSignIn: onSignIn ?? () async => false,
              onPurchase: onPurchase ?? () async => false,
              onRecheck: onRecheck ?? () async => false,
            )),
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

Iterable<String> _texts(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '');

void main() {
  group('signed out', () {
    testWidgets('offers only sign-in, and never a price or a purchase',
        (tester) async {
      await _open(tester, stage: PaywallStage.signedOut);

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Subscribe'), findsNothing);

      // This is the screen iOS and Android users see. A price or renewal terms
      // here would read as selling a subscription outside the store, which is
      // what gets an app rejected under guideline 3.1.1.
      expect(_texts(tester).any((s) => s.contains('per year')), isFalse,
          reason: 'no price may appear before sign-in');
      expect(_texts(tester).any((s) => s.contains('renews automatically')),
          isFalse);
    });

    testWidgets('still says plainly that the hymnal stays free',
        (tester) async {
      await _open(tester, stage: PaywallStage.signedOut);
      expect(_texts(tester).any((s) => s.contains('stay free')), isTrue);
    });

    testWidgets('signing in to an entitled account closes the sheet',
        (tester) async {
      final outcome = await _open(tester,
          stage: PaywallStage.signedOut, onSignIn: () async => true);
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(outcome.single, isTrue);
    });
  });

  group('where buying is allowed', () {
    testWidgets('shows the price, terms and links App Review looks for',
        (tester) async {
      await _open(tester, stage: PaywallStage.canBuy);

      expect(find.text(kPlusName), findsOneWidget);
      expect(find.text('\$12 per year'), findsOneWidget);

      final disclosure = _texts(tester)
          .firstWhere((s) => s.contains('renews automatically'), orElse: () => '');
      expect(disclosure, isNotEmpty);
      expect(disclosure, contains('24 hours'));
      expect(disclosure, contains('cancelled'));

      expect(find.text('Terms of Use'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Subscribe'), findsOneWidget);
    });

    testWidgets('prefers the store\'s own localised price', (tester) async {
      await _open(
        tester,
        stage: PaywallStage.canBuy,
        offer: const PlusOffer(id: kPlusProductId, price: '£10.99'),
      );
      expect(find.text('£10.99 per year'), findsOneWidget);
      expect(find.text('\$12 per year'), findsNothing);
    });

    testWidgets('opening the purchase page keeps the sheet open and explains',
        (tester) async {
      // The purchase finishes in a browser, so this must not claim an unlock
      // and must not report a failure either.
      await _open(tester,
          stage: PaywallStage.canBuy, onPurchase: () async => true);
      await tester.tap(find.text('Subscribe'));
      await tester.pumpAndSettle();

      expect(find.text('Subscribe'), findsOneWidget);
      expect(find.textContaining('Finish subscribing in your browser'),
          findsOneWidget);
      expect(find.textContaining('Could not open'), findsNothing);
    });

    testWidgets('a page that will not open is reported as an error',
        (tester) async {
      await _open(tester,
          stage: PaywallStage.canBuy, onPurchase: () async => false);
      await tester.tap(find.text('Subscribe'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not open'), findsOneWidget);
    });

    testWidgets('re-checking finds a subscription bought in the browser',
        (tester) async {
      final outcome = await _open(tester,
          stage: PaywallStage.canBuy, onRecheck: () async => true);
      await tester.tap(find.text('Already subscribed? Check again'));
      await tester.pumpAndSettle();
      expect(outcome.single, isTrue);
    });
  });

  group('where buying is not allowed', () {
    testWidgets('never shows a price, a purchase button, or where to buy',
        (tester) async {
      await _open(tester, stage: PaywallStage.cannotBuyHere);

      expect(find.text('Subscribe'), findsNothing);
      expect(find.text('Check Again'), findsOneWidget);

      final all = _texts(tester).join(' ').toLowerCase();
      // Guideline 3.1.1 bans steering as well as selling. None of these may
      // appear on iOS or Android.
      for (final banned in <String>[
        'per year',
        'website',
        'browser',
        'subscribe at',
        'songsofthechurch.app',
        '\$12',
      ]) {
        expect(all.contains(banned), isFalse,
            reason: '"$banned" would be steering to an outside purchase');
      }
    });

    testWidgets('a successful re-check unlocks', (tester) async {
      final outcome = await _open(tester,
          stage: PaywallStage.cannotBuyHere, onRecheck: () async => true);
      await tester.tap(find.text('Check Again'));
      await tester.pumpAndSettle();
      expect(outcome.single, isTrue);
    });

    testWidgets('a failed re-check says so without pointing anywhere',
        (tester) async {
      await _open(tester,
          stage: PaywallStage.cannotBuyHere, onRecheck: () async => false);
      await tester.tap(find.text('Check Again'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Still nothing'), findsOneWidget);
    });
  });

  group('purchaseAllowedHere', () {
    test('is false with no purchase URL compiled in', () {
      // The shipped default: nothing configured, so nothing is sold anywhere.
      expect(kPurchaseUrl, isEmpty);
      expect(purchaseAllowedHere, isFalse);
    });
  });
}
