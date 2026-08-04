// Receives RevenueCat webhooks and mirrors entitlement state into Postgres.
//
// RevenueCat is the source of truth; this keeps a local copy so the app can
// read its entitlement in one indexed row read, over RLS, without the launch
// path depending on a third party being up.
//
// Set these on the function (supabase secrets set):
//   REVENUECAT_WEBHOOK_SECRET  the Authorization header value configured in
//                              the RevenueCat dashboard
//   SUPABASE_URL               provided automatically
//   SUPABASE_SERVICE_ROLE_KEY  provided automatically
//
// Deploy with:
//   supabase functions deploy revenuecat-webhook --no-verify-jwt
//
// --no-verify-jwt is required and safe here: RevenueCat cannot present a
// Supabase user JWT, so the request is authenticated by the shared secret
// checked below instead.

import { createClient } from 'jsr:@supabase/supabase-js@2';

/// Events that mean the subscription is live right now.
const GRANTING = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'UNCANCELLATION',
  'PRODUCT_CHANGE',
  'SUBSCRIPTION_EXTENDED',
  'TEMPORARY_ENTITLEMENT_GRANT',
]);

/// Events that end access immediately.
///
/// Note that CANCELLATION is deliberately *not* here: in RevenueCat it means
/// auto-renew was turned off, not that access stopped. Someone who cancels on
/// day one has paid for the year and keeps it until expiry. Treating it as
/// revocation would cut off paying subscribers.
const REVOKING = new Set([
  'EXPIRATION',
  'REFUND',
  'SUBSCRIPTION_PAUSED',
]);

const STORE_TO_SOURCE: Record<string, string> = {
  APP_STORE: 'app_store',
  MAC_APP_STORE: 'app_store',
  PLAY_STORE: 'play_store',
  STRIPE: 'stripe',
  RC_BILLING: 'stripe',
  PADDLE: 'stripe',
  PROMOTIONAL: 'promotional',
};

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  // Shared-secret check. Without this, anyone who finds the URL can grant
  // themselves a subscription, so fail closed if it is not configured.
  const expected = Deno.env.get('REVENUECAT_WEBHOOK_SECRET');
  if (!expected) {
    console.error('REVENUECAT_WEBHOOK_SECRET is not set; refusing all events');
    return new Response('Not configured', { status: 500 });
  }
  if (req.headers.get('Authorization') !== expected) {
    return new Response('Unauthorized', { status: 401 });
  }

  let payload: { event?: Record<string, unknown> };
  try {
    payload = await req.json();
  } catch {
    return new Response('Bad JSON', { status: 400 });
  }

  const event = payload.event;
  if (!event) return new Response('No event', { status: 400 });

  const type = String(event.type ?? '');
  const appUserId = String(event.app_user_id ?? '');

  // RevenueCat sends anonymous ids ($RCAnonymousID:...) before a user is
  // identified. Those cannot map to an account, so acknowledge and move on
  // rather than erroring — a non-2xx makes RevenueCat retry forever.
  if (!appUserId || appUserId.startsWith('$RCAnonymousID')) {
    return new Response('Ignored: anonymous subscriber', { status: 200 });
  }
  if (!/^[0-9a-f-]{36}$/i.test(appUserId)) {
    return new Response('Ignored: app_user_id is not a Supabase user id', {
      status: 200,
    });
  }

  const granting = GRANTING.has(type);
  const revoking = REVOKING.has(type);
  if (!granting && !revoking) {
    // TRANSFER, BILLING_ISSUE, CANCELLATION and the rest are informational
    // here — the expiry we already hold still describes access correctly.
    return new Response(`Ignored: ${type}`, { status: 200 });
  }

  const expiryMs = Number(event.expiration_at_ms ?? 0);
  const expiresAt = expiryMs > 0 ? new Date(expiryMs).toISOString() : null;

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { auth: { persistSession: false } },
  );

  const { error } = await supabase.from('entitlements').upsert(
    {
      user_id: appUserId,
      product_id: String(event.product_id ?? 'plus_yearly'),
      active: granting,
      expires_at: expiresAt,
      source: STORE_TO_SOURCE[String(event.store ?? '')] ?? 'stripe',
      rc_customer_id: String(event.original_app_user_id ?? appUserId),
      updated_at: new Date().toISOString(),
    },
    { onConflict: 'user_id' },
  );

  if (error) {
    // Return 5xx so RevenueCat retries; losing a renewal event silently would
    // expire a paying subscriber.
    console.error('upsert failed', error);
    return new Response('Storage error', { status: 500 });
  }

  return new Response(`OK: ${type}`, { status: 200 });
});
