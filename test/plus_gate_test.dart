import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songs_of_the_church/billing/auth_controller.dart';
import 'package:songs_of_the_church/billing/entitlement.dart';
import 'package:songs_of_the_church/billing/entitlement_controller.dart';
import 'package:songs_of_the_church/billing/entitlement_store.dart';
import 'package:songs_of_the_church/billing/paywall_sheet.dart';
import 'package:songs_of_the_church/billing/plus_gate.dart';
import 'package:songs_of_the_church/billing/supabase_config.dart';
import 'package:songs_of_the_church/theme.dart';

/// Taps a button wired to [requirePlus] and reports whether it was allowed.
Future<List<bool>> _tapGated(
  WidgetTester tester, {
  required EntitlementController entitlement,
}) async {
  final List<bool> allowed = <bool>[];
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<EntitlementController>.value(value: entitlement),
      ChangeNotifierProvider<AuthController>(create: (_) => AuthController()),
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

Future<EntitlementController> _controller(
    Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return EntitlementController(store: EntitlementStore(prefs: prefs));
}

void main() {
  testWidgets('with no billing configured nothing is gated at all',
      (tester) async {
    // The shipped default. If this regresses, a build without Supabase
    // credentials locks every existing user out of features they had.
    expect(billingConfigured, isFalse,
        reason: 'the default build must not gate anything');

    final entitlement = await _controller(<String, Object>{});
    await entitlement.init();

    final allowed = await _tapGated(tester, entitlement: entitlement);

    expect(allowed.single, isTrue);
    expect(find.text('Sign In'), findsNothing,
        reason: 'no paywall should appear when nothing is configured');
  });

  testWidgets('an entitled user is never shown the paywall', (tester) async {
    final entitlement = await _controller(<String, Object>{});
    await entitlement.apply(Entitlement(
      active: true,
      expiresAt: DateTime.now().add(const Duration(days: 200)),
      source: PurchaseSource.stripe,
    ));

    final allowed = await _tapGated(tester, entitlement: entitlement);

    expect(allowed.single, isTrue);
    expect(find.text('Sign In'), findsNothing);
  });

  testWidgets('a grandfathered user is never shown the paywall',
      (tester) async {
    final entitlement =
        await _controller(<String, Object>{'songbook-favorites': '[7]'});
    await entitlement.init();
    expect(entitlement.isGrandfathered, isTrue);

    final allowed = await _tapGated(tester, entitlement: entitlement);

    expect(allowed.single, isTrue);
    expect(find.text('Sign In'), findsNothing);
  });
}
