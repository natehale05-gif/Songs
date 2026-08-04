# Setting up Songs of the Church Plus

$12/year, sold **on the web only**, through RevenueCat, with accounts in
Supabase. One purchase works on every platform.

Nothing in the app gates anything until `SUPABASE_URL` and `SUPABASE_ANON_KEY`
are compiled in. Until then every feature stays unlocked, which is why the
current build is safe to ship as-is.

---

## 1. The shape of it

```
  browser ──▶ RevenueCat Web Billing (Stripe) ──▶ webhook ──┐
                                                            ▼
  any app ──▶ Supabase Auth (email code) ──▶ entitlements table (RLS)
                                                            │
                                          app reads its own row ◀┘
```

- **Accounts** are Supabase Auth, email one-time codes. No password to leak,
  and no third-party social login — which also means Sign in with Apple is not
  triggered, since that obligation attaches to social logins.
- **Payment** is RevenueCat Web Billing, backed by Stripe. Nothing goes through
  the App Store or Play.
- **The Supabase user id is the RevenueCat App User ID.** That single decision
  is what makes one purchase work everywhere: whichever device signs in,
  RevenueCat is asked about the same subject.
- **The app never asks RevenueCat directly.** A webhook mirrors entitlement
  state into Postgres, and the app reads its own row over RLS. Startup does not
  depend on a third party being up, and an entitlement check is one indexed row
  read.

### What $12 becomes

Stripe takes ~2.9% + $0.30, RevenueCat is free below $2,500/month of tracked
revenue. You keep about **$11.35** — versus $10.20 through the app stores.
Against that: Supabase free tier, and the relay at ~$2–3/month.

---

## 2. The rule that shapes the mobile apps

**iOS and Android show a sign-in prompt and nothing else.** No price, no
Subscribe button, no mention that a website exists.

This is not a limitation of the code. App Store guideline 3.1.1 requires
digital features sold *inside* an app to use In-App Purchase, and Play's
payments policy says the same. Selling only on the web is permitted for a
genuine multiplatform service under 3.1.3(b) — you may let people use what they
bought elsewhere — but the mobile app must neither sell nor **steer**. Linking
to the purchase page, or even naming it, is steering.

So `purchaseAllowedHere` in `lib/billing/billing_config.dart` is false on iOS
and Android, and there are tests asserting the paywall shows no price and no
outside-purchase hint in that state. **Do not "fix" that by adding a link.**

The one exception worth knowing: since the 2025 US injunction, apps on the US
storefront may link out. The rules differ by country, so if you want that,
check the current position for everywhere you sell before changing it.

---

## 3. Supabase — already done

Applied to the existing project `natehale05-gif's Project`:

| | |
| --- | --- |
| Project ref | `xmjaqizlrlsvjbwqmtdo` |
| URL | `https://xmjaqizlrlsvjbwqmtdo.supabase.co` |
| Publishable key | `sb_publishable_Ga1mK-hAm42HO6SCLT6kYQ_Zcjqos31` |
| Webhook URL | `https://xmjaqizlrlsvjbwqmtdo.supabase.co/functions/v1/revenuecat-webhook` |

The `songs_entitlements` table is live with row level security: an
authenticated user can read **only their own row**, and there is deliberately
no insert or update policy at all. Verified by attempting an insert as an
authenticated role — it was refused. An entitlement a client could write is an
entitlement anyone can grant themselves.

The `revenuecat-webhook` function is deployed with JWT verification off, which
is required and safe: RevenueCat cannot present a Supabase user JWT, so the
request is authenticated by a shared secret instead.

### The one step left here

```bash
supabase secrets set REVENUECAT_WEBHOOK_SECRET='<a long random string>' \
  --project-ref xmjaqizlrlsvjbwqmtdo
```

**Until this is set the webhook refuses every event** with a 500 — it fails
closed rather than open, so no entitlement can be granted by anyone who simply
finds the URL. Use the same value as the Authorization header in RevenueCat.

### Sharing a project with another product

This project also runs an unrelated application, with its own `profiles`,
`subscriptions` and `usage_events` tables. Two consequences worth holding onto:

- **`auth.users` is shared.** The same email address is the same account in
  both products. Somebody who signs up for the other one can sign into Songs
  with those credentials, and vice versa; deleting an account removes it from
  both. Nothing leaks between the two beyond that — Songs reads only its own
  table, and there is no trigger on `auth.users`, so a Songs sign-up writes
  nothing into the other product's tables.
- **Two subscription systems now live side by side.** `public.subscriptions`
  belongs to the other product; `public.songs_entitlements` is this one. They
  are unrelated, which is why the names differ.

If Songs grows, move it to its own project. That means migrating accounts, so
it is much cheaper to do before there are subscribers than after.

### Email

Supabase's built-in email sender is rate-limited and not for production. Set up
SMTP under Authentication → Emails before launch, or sign-in codes will start
silently failing.

---

## 4. RevenueCat

1. Create a project. Add a **Web Billing** app (formerly RC Billing) and
   connect your Stripe account.
2. Create a product at **$12/year** and an entitlement called `plus`.
3. Create a **paywall / purchase link**. Its URL goes into `PURCHASE_URL`.
4. **Integrations → Webhooks** → point at
   `https://<ref>.supabase.co/functions/v1/revenuecat-webhook`, and set the
   Authorization header to the same `REVENUECAT_WEBHOOK_SECRET`.

### The event handling worth understanding

`supabase/functions/revenuecat-webhook/index.ts` treats `CANCELLATION` as
**informational, not revoking**. In RevenueCat that event means auto-renew was
turned off, not that access ended — somebody who cancels on day one has paid
for the year and keeps it until `EXPIRATION`. Treating cancellation as
revocation would cut off paying subscribers, which is the kind of bug you hear
about from angry customers rather than from tests.

Anonymous subscribers (`$RCAnonymousID:…`) are acknowledged and ignored, since
they cannot map to an account. The function returns 5xx on a storage failure so
RevenueCat retries — silently losing a renewal event would expire someone who
has paid.

---

## 5. Building with it

```bash
flutter build web --release \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=sb_publishable_... \
  --dart-define=PURCHASE_URL=https://pay.songsofthechurch.app/plus
```

Set `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `PURCHASE_URL` as repository
variables so both workflows pass them through, exactly as `RELAY_URL` does.

The publishable key is meant to ship in a client — RLS is what protects the
data, not the secrecy of that key. **The service role key must never appear in
the app**, only in the edge function's secrets.

`PURCHASE_URL` is read on every platform but only *used* where
`purchaseAllowedHere` allows, so setting it does not put a purchase button in
the iOS build.

---

## 6. What the stores are told

This replaces the "Data Not Collected" answers in
[`docs/store-submission.md`](store-submission.md), which were written when the
app collected nothing.

**Apple, App Privacy:**
- *Contact Info → Email Address* — linked to identity, App Functionality.
- *Purchases → Purchase History* — linked to identity, App Functionality.
- Tracking: **No**.

Update `ios/Runner/PrivacyInfo.xcprivacy` to match before submitting.

**Google Play, Data safety:** Personal info → Email address, and Financial info
→ Purchase history. Both collected, both required, encrypted in transit,
deletion available on request.

**Both:** because accounts now exist, Play requires a documented account
deletion route. The privacy policy commits to deletion on request, which
satisfies it; an in-app button would be better.

**Review notes.** Give reviewers a test account that already has an active
subscription. A reviewer on iOS *cannot buy one* — that is the whole point of
the design — so without a pre-entitled account they will see a sign-in wall and
reject the build. This is the single most likely rejection reason here, so make
the note explicit.

---

## 7. Order of operations

1. Settle the song licensing (`docs/store-submission.md` §0). Selling access
   raises the stakes considerably.
2. Have a lawyer read `web/terms.html`, especially the song-rights paragraph,
   and add a governing-law clause.
3. Free up a Supabase project slot; apply the migration and deploy the function.
4. Set up RevenueCat and Stripe; wire the webhook.
5. Build the **web** app with all three defines and buy a real subscription
   end to end.
6. Confirm the entitlement then appears on a mobile build after signing in with
   the same email — that is the cross-platform claim, and it is worth proving
   before anyone pays for it.
7. Only then set the repository variables and cut a release.
