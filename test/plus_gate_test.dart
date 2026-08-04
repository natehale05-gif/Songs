import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songs_of_the_church/billing/billing_config.dart';
import 'package:songs_of_the_church/billing/entitlement.dart';
import 'package:songs_of_the_church/billing/entitlement_controller.dart';
import 'package:songs_of_the_church/billing/entitlement_store.dart';
import 'package:songs_of_the_church/billing/paywall_sheet.dart';
import 'package:songs_of_the_church/billing/plus_gate.dart';
import 'package:songs_of_the_church/billing/purchase_service.dart';
import 'package:songs_of_the_church/theme.dart';

class _FakePurchases implements PurchaseService {
  _FakePurchases();
  final Entitlement? result = null;
  int subscribeCalls = 0;

  @override
  Future<PlusOffer> loadOffer() async => const PlusOffer.fallback();

  @override
  Future<Entitlement?> subscribe() async {
    subscribeCalls++;
    return result;
  }

  @override
  Future<Entitlement?> restore() async => result;
}

/// Taps a button wired to [requirePlus] and reports whether it was allowed.
Future<List<bool>> _tapGated(
  WidgetTester tester, {
  required EntitlementController entitlement,
  required PurchaseService purchases,
}) async {
  final List<bool> allowed = <bool>[];
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<EntitlementController>.value(value: entitlement),
      Provider<PurchaseService>.value(value: purchases),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async => allowed.add(await requirePlus(
                  context, AppPalette.light, PlusFeature.setList)),
              child: const Text('do it'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('do it'));
  await tester.pumpAndSettle();
  return allowed;
}

void main() {
  testWidgets('with no billing configured nothing is gated at all',
      (tester) async {
    // This is the shipped default. If it ever regresses, a build without
    // BILLING_URL locks every existing user out of features they had.
    expect(billingConfigured, isFalse,
        reason: 'the default build must not sell anything');

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final entitlement = EntitlementController(
      store: EntitlementStore(prefs: prefs),
    );
    await entitlement.init();
    final purchases = _FakePurchases();

    final allowed = await _tapGated(tester,
        entitlement: entitlement, purchases: purchases);

    expect(allowed.single, isTrue);
    expect(find.text('Subscribe'), findsNothing,
        reason: 'no paywall should appear when nothing is for sale');
    expect(purchases.subscribeCalls, 0);
  });

  testWidgets('an entitled user is never shown the paywall', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final entitlement = EntitlementController(
      store: EntitlementStore(prefs: prefs),
    );
    await entitlement.apply(Entitlement(
      active: true,
      expiresAt: DateTime.now().add(const Duration(days: 200)),
      source: PurchaseSource.appStore,
    ));

    final allowed = await _tapGated(tester,
        entitlement: entitlement, purchases: _FakePurchases());

    expect(allowed.single, isTrue);
    expect(find.text('Subscribe'), findsNothing);
  });

  testWidgets('a grandfathered user is never shown the paywall',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'songbook-favorites': '[7]',
    });
    final prefs = await SharedPreferences.getInstance();
    final entitlement = EntitlementController(
      store: EntitlementStore(prefs: prefs),
    );
    await entitlement.init();
    expect(entitlement.isGrandfathered, isTrue);

    final allowed = await _tapGated(tester,
        entitlement: entitlement, purchases: _FakePurchases());

    expect(allowed.single, isTrue);
    expect(find.text('Subscribe'), findsNothing);
  });
}
