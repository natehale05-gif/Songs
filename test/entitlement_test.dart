import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songs_of_the_church/billing/entitlement.dart';
import 'package:songs_of_the_church/billing/entitlement_controller.dart';
import 'package:songs_of_the_church/billing/entitlement_store.dart';

DateTime _at(String iso) => DateTime.parse(iso);

class _FakeSource implements EntitlementSource {
  _FakeSource(this._result);
  final Object _result;
  int calls = 0;

  @override
  Future<Entitlement> fetch() async {
    calls++;
    if (_result is Entitlement) return _result;
    throw _result;
  }
}

void main() {
  group('Entitlement expiry', () {
    test('is usable inside the paid period', () {
      final e = Entitlement(active: true, expiresAt: _at('2026-09-01T00:00:00Z'));
      expect(e.isUsableAt(_at('2026-08-04T00:00:00Z')), isTrue);
    });

    test('survives the offline grace window past expiry', () {
      // A renewal we could not confirm must not lock somebody out mid-service.
      final e = Entitlement(active: true, expiresAt: _at('2026-08-01T00:00:00Z'));
      expect(e.isUsableAt(_at('2026-08-20T00:00:00Z')), isTrue);
    });

    test('lapses once the grace window is past', () {
      final e = Entitlement(active: true, expiresAt: _at('2026-08-01T00:00:00Z'));
      expect(e.isUsableAt(_at('2026-09-15T00:00:00Z')), isFalse);
    });

    test('an inactive entitlement is never usable', () {
      final e = Entitlement(active: false, expiresAt: _at('2027-01-01T00:00:00Z'));
      expect(e.isUsableAt(_at('2026-08-04T00:00:00Z')), isFalse);
    });

    test('a grandfathered one never lapses', () {
      const e = Entitlement.grandfathered();
      expect(e.isUsableAt(_at('2099-01-01T00:00:00Z')), isTrue);
    });

    test('survives a round trip through the cache', () {
      final e = Entitlement(
        active: true,
        expiresAt: _at('2026-09-01T00:00:00Z'),
        source: PurchaseSource.appStore,
      );
      final parsed = Entitlement.tryParse(e.encode())!;
      expect(parsed.active, isTrue);
      expect(parsed.expiresAt, e.expiresAt);
      expect(parsed.source, PurchaseSource.appStore);
    });

    test('unreadable cached data reads as no entitlement, not a crash', () {
      expect(Entitlement.tryParse('not json'), isNull);
      expect(Entitlement.tryParse('[1,2,3]'), isNull);
    });
  });

  group('grandfathering', () {
    test('an install with prior use keeps everything for free', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'songbook-favorites': '[1,2,3]',
      });
      final prefs = await SharedPreferences.getInstance();
      final controller = EntitlementController(
        store: EntitlementStore(prefs: prefs),
        clock: () => _at('2026-08-04T00:00:00Z'),
      );
      await controller.init();

      expect(controller.hasPlus, isTrue);
      expect(controller.isGrandfathered, isTrue);
    });

    test('a fresh install is not grandfathered', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final controller = EntitlementController(
        store: EntitlementStore(prefs: prefs),
        clock: () => _at('2026-08-04T00:00:00Z'),
      );
      await controller.init();

      expect(controller.hasPlus, isFalse);
    });

    test('the decision sticks even if the old data is cleared later', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'songbook-open-counts': '{"1":4}',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = EntitlementStore(prefs: prefs);
      expect(await store.resolveLegacyUser(), isTrue);

      await prefs.remove('songbook-open-counts');
      expect(await store.resolveLegacyUser(), isTrue,
          reason: 'clearing favourites must not revoke access');
    });
  });

  group('refresh', () {
    test('a server error leaves an existing entitlement alone', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final controller = EntitlementController(
        store: EntitlementStore(prefs: prefs),
        source: _FakeSource(Exception('offline')),
        clock: () => _at('2026-08-04T00:00:00Z'),
      );
      await controller.apply(Entitlement(
        active: true,
        expiresAt: _at('2026-12-01T00:00:00Z'),
        source: PurchaseSource.stripe,
      ));

      await controller.refresh();

      expect(controller.hasPlus, isTrue,
          reason: 'being unable to ask is not the same as being told no');
      expect(controller.lastRefreshError, isNotNull);
    });

    test('a successful refresh replaces and caches the entitlement', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final store = EntitlementStore(prefs: prefs);
      final controller = EntitlementController(
        store: store,
        source: _FakeSource(Entitlement(
          active: true,
          expiresAt: _at('2027-08-04T00:00:00Z'),
          source: PurchaseSource.playStore,
        )),
        clock: () => _at('2026-08-04T00:00:00Z'),
      );

      await controller.refresh();

      expect(controller.hasPlus, isTrue);
      final cached = await store.readCached();
      expect(cached, isNotNull);
      expect(cached!.source, PurchaseSource.playStore);
      expect(cached.checkedAt, isNotNull,
          reason: 'the cache needs to know when it was last confirmed');
    });

    test('signing out drops a bought entitlement but not a grandfathered one',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final bought = EntitlementController(
        store: EntitlementStore(prefs: prefs),
        clock: () => _at('2026-08-04T00:00:00Z'),
      );
      await bought.apply(Entitlement(
          active: true,
          expiresAt: _at('2027-01-01T00:00:00Z'),
          source: PurchaseSource.appStore));
      await bought.forget();
      expect(bought.hasPlus, isFalse);

      final legacy = EntitlementController(
        store: EntitlementStore(prefs: prefs),
        clock: () => _at('2026-08-04T00:00:00Z'),
      );
      await legacy.apply(const Entitlement.grandfathered());
      await legacy.forget();
      expect(legacy.hasPlus, isTrue,
          reason: 'it was never tied to an account to sign out of');
    });
  });
}
