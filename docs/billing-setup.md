# Setting up Songs of the Church Plus

$12/year, sold on iOS, Android, web and desktop, with one purchase working
everywhere. This is what has to exist outside the repository before any of it
can take money, and none of it can be done from CI.

Nothing in the app sells anything until `BILLING_URL` is set. Until then every
feature stays unlocked for everyone, which is why the current build is safe to
ship as-is.

---

## 1. What $12 actually becomes

Worth knowing before you price anything else around it.

| | Apple / Google | Stripe (web, desktop) |
| --- | --- | --- |
| Store or processor cut | 15% under the small-business programmes | ~2.9% + $0.30 |
| You receive | **$10.20** | **~$11.35** |

Apple's 15% rate needs enrolment in the **App Store Small Business Program**;
without it the rate is 30% and you net $8.40. Google's equivalent 15% rate on
the first $1M applies automatically. Both are worth confirming rather than
assuming.

Against that, the running costs: the relay (~$2–3/month), the billing service
below (similar), and a domain. At $12/year, roughly **six subscribers** cover
the infrastructure. That is a low bar, but it is not zero, and it is the honest
reason to think about whether this is worth the operational weight.

---

## 2. The shape of it, and why

```
   iOS ──StoreKit──┐
Android ─Play Bill─┤
    Web ──Stripe───┼──▶  billing service  ──▶  GET /entitlement  ──▶  app
Desktop ──Stripe───┘     (accounts, receipts)
```

The app never decides for itself whether someone has paid. It asks the billing
service, caches the answer, and trusts that cache for up to 30 days offline.
That last part is not a detail: this app's whole premise is working with no
connection, and a subscriber in a building with no signal must not be asked to
pay again.

**Why there is an account at all.** You asked for one purchase to work
everywhere. Apple will not tell Google about a purchase, and neither will tell
a browser. The only thing that can join them is an identity you own, so
subscribing asks for an email address. The free app still asks for nothing.

**What the service must never do** is trust the client. A receipt arrives from
the app, but the service verifies it directly with Apple or Google before
granting anything — an app can be modified, and "the app said so" is not
evidence of payment.

---

## 3. Apple

### Create the product
1. App Store Connect → your app → **Subscriptions** → create a subscription
   group (e.g. "Songs of the Church Plus").
2. Add a subscription with product ID **`app.songsofthechurch.plus.yearly`** —
   this must match `kPlusProductId` in `lib/billing/billing_config.dart`
   exactly. A mismatch shows up as an empty product list with no error, which
   is a miserable thing to debug.
3. Duration **1 year**, price tier closest to $12. Add a localised display name
   and description; Apple rejects subscriptions with these missing.
4. Upload a **review screenshot** of the paywall.

### Agreements, tax and banking
Under **Business** → *Agreements, Tax, and Banking*, accept the Paid
Applications agreement and complete banking and tax. **Nothing sells until this
is done and shows Active** — this is the single most common reason a
subscription appears to exist but cannot be bought.

### Server credentials
For the billing service to verify receipts:
- App Store Connect → Users and Access → **Integrations** → In-App Purchase →
  generate a key. You get a `.p8` file (downloadable once), a **Key ID**, and
  an **Issuer ID**.
- Note your app's **bundle ID** (`app.songsofthechurch.songsOfTheChurch`).

Use the **App Store Server API** and **App Store Server Notifications V2**.
The old `verifyReceipt` endpoint is deprecated; do not build on it.

Point Server Notifications V2 at `https://your-billing/webhooks/apple`. Without
it, a cancellation or a failed renewal will not reach you until the app next
asks — with the 30-day grace window, that can be weeks of access after someone
stopped paying.

### Testing
Create **Sandbox testers** in Users and Access. Sandbox subscriptions renew on
an accelerated clock (a year becomes an hour), which is the only practical way
to test a renewal.

---

## 4. Google Play

1. Play Console → Monetise → **Subscriptions** → create one with product ID
   **`app.songsofthechurch.plus.yearly`**, and a base plan with a **yearly**
   billing period, auto-renewing.
2. Set the price, and activate both the subscription and the base plan — a
   subscription with an inactive base plan is invisible to the app.
3. Complete the **payments profile** under Setup → Payments profile.

### Server credentials
- Google Cloud console → create a **service account**, grant it access in Play
  Console under Users and permissions with *View financial data* and *Manage
  orders and subscriptions*.
- Download the service-account **JSON key** for the billing service.
- Enable the **Google Play Android Developer API** for that project.

Use `purchases.subscriptionsv2.get` to verify. Set up **Real-time developer
notifications** via Pub/Sub pointing at `https://your-billing/webhooks/google`,
for the same reason as Apple's.

### Testing
Add **licence testers** under Setup → Licence testing. Their purchases are free
and renew on an accelerated clock.

---

## 5. Stripe (web and desktop)

1. Create a **Product** with a **recurring yearly $12 Price**.
2. Use **Stripe Checkout** rather than building a card form — it keeps card
   data entirely out of your systems, which is most of what PCI compliance
   would otherwise mean for you.
3. Enable **Stripe Tax** if you are selling internationally. Digital-goods VAT
   in the EU and UK applies from the first sale, with no threshold.
4. Set a webhook to `https://your-billing/webhooks/stripe` for
   `checkout.session.completed`, `customer.subscription.updated` and
   `customer.subscription.deleted`. Keep the **signing secret** — a webhook
   whose signature you do not verify is an open door to granting free
   subscriptions.

### The Apple rule worth knowing
Selling the same subscription on your own website is allowed. What is
restricted is *steering* — linking to it, or telling users about it, from
inside the iOS app. In the US, following the 2025 injunction, apps may link
out; elsewhere the rules are tighter and vary. **The app deliberately contains
no link to the web purchase page**, and that should stay true unless you have
checked the current rules for the countries you sell in.

---

## 6. Secrets the billing service needs

| Name | From |
| --- | --- |
| `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` | App Store Connect integration key |
| `APPLE_BUNDLE_ID` | `app.songsofthechurch.songsOfTheChurch` |
| `GOOGLE_SERVICE_ACCOUNT_JSON` | Google Cloud service account |
| `GOOGLE_PACKAGE_NAME` | `app.songsofthechurch.songs_of_the_church` |
| `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `STRIPE_PRICE_ID` | Stripe dashboard |
| `JWT_SIGNING_KEY` | generate one; rotating it signs everyone out |
| `DATABASE_URL` | wherever the service stores accounts |

None of these belong in the repository. Treat the Apple `.p8` and the Google
JSON the way you would treat the Android keystore.

---

## 7. Pointing the app at it

```bash
flutter build apk --release --dart-define=BILLING_URL=https://your-billing
```

Or set a repository **variable** `BILLING_URL` so both workflows pass it
through, exactly as `RELAY_URL` works. Remember that setting it changes the app
from "everything free" to "extras gated" — so it takes effect only in builds
made after it is set, and you should test a build with it before releasing one.

---

## 8. What the stores will now ask that they did not before

`docs/store-submission.md` was written when the app collected nothing. Both
answers change once billing ships:

**Apple, App Privacy.** No longer "Data Not Collected". Declare:
- *Contact Info → Email Address* — linked to identity, used for App
  Functionality. Not used for tracking.
- *Purchases → Purchase History* — linked to identity, App Functionality.

Tracking stays **No**: nothing is shared with data brokers or combined with
data from other apps.

**Google Play, Data safety.** No longer "No" to the first question. Declare
Personal info → Email address, and Financial info → Purchase history, both
*collected*, both required, both encrypted in transit, with account deletion
available on request. Play requires an in-app or documented **account deletion**
route once accounts exist — the privacy policy commits to deletion on request,
which satisfies it, but a link in the app is better.

**Review notes.** Give both reviewers a working test account with an active
subscription, plus a sandbox/licence tester. A reviewer who cannot get past the
paywall rejects the build.

---

## 9. Order of operations

1. Settle the song licensing (see `docs/store-submission.md` §0). Selling
   access raises the stakes on this considerably.
2. Have a lawyer look at `web/terms.html`, particularly the song-rights
   paragraph, and add a governing-law clause.
3. Apple and Google agreements, tax and banking — these gate everything and can
   take days.
4. Create the three products with the same product ID.
5. Deploy the billing service; set its secrets.
6. Build with `BILLING_URL` and test end to end with sandbox accounts on both
   stores, including a renewal and a cancellation.
7. Only then set the repository variable and cut a release.
