# Submitting to the App Store and Google Play

Everything in this repository that a store checks is already in place. What is
left is account setup, signing identities, and the questionnaires — none of
which can be done from CI. This is the list.

Facts you will be asked for repeatedly:

| | |
| --- | --- |
| App name | Songs of the Church |
| iOS bundle ID | `app.songsofthechurch.songsOfTheChurch` |
| Android application ID | `app.songsofthechurch.songs_of_the_church` |
| Privacy policy URL | `https://natehale05-gif.github.io/Songs/privacy.html` |
| Support URL | `https://github.com/natehale05-gif/Songs/issues` |
| Category | Reference (Apple) · Books & Reference (Play) |
| Age rating | 4+ / Everyone |
| Price | Free, no in-app purchases |
| iOS deployment target | 13.0, iPhone and iPad |
| Android | minSdk 24, targetSdk 36 |

---

## 0. Settle this before you spend money

**The song texts are the real risk, not the code.** Store review will not check
copyright, but a rights holder can have a listing pulled at any time, and
"Songs of the Church" is a published hymnal title. Most of the 715 songs here
are 18th- and 19th-century texts that are unambiguously public domain, but the
collection also contains 20th-century works, translations, and arrangements
that may not be. A translation or arrangement carries its own copyright even
when the underlying hymn is public domain.

Before publishing, go through the data and confirm, per song, that you have the
right to distribute the text — either because it is public domain or because
you hold a licence. Publishing a hymnal app is exactly the case CCLI and
similar licences exist for, and a church copyright licence generally does *not*
cover redistributing texts in an app. If any song cannot be cleared, drop it.

Everything below assumes that is resolved.

---

## 1. Accounts and one-time setup

| | Apple | Google |
| --- | --- | --- |
| Programme | Apple Developer Program | Google Play Console |
| Cost | $99/year | $25, one time |
| Approval | 1–2 days, sometimes longer for individuals | Identity verification, can take days |
| Build machine | A Mac — App Store builds must be archived and uploaded from Xcode | Any; CI already produces the upload artefact |

A **personal** Play developer account created after November 2023 must run a
closed test with at least **12 testers for 14 continuous days** before it can
apply for production access. Start that clock early — it is the longest single
delay in the whole process. Organisation accounts are exempt.

### Android signing (do this first)

CI already builds a Play-ready `.aab`, but it is debug-signed until the release
keystore exists, and Play rejects debug-signed uploads. Run:

```bash
tool/make_android_keystore.sh
```

then add the four values it prints as repository secrets (see the README).
**Back the keystore file up somewhere you will not lose it.** With Play App
Signing enabled — do enable it — losing the upload key is recoverable, but
losing it without Play App Signing means you can never update the app again.

---

## 2. What is already handled in the repo

Do not redo these; do check them if a submission is rejected.

| Requirement | Where |
| --- | --- |
| Privacy policy, publicly reachable | `web/privacy.html`, deployed with the web app |
| Policy reachable from inside the app | About sheet — the ⓘ next to the title (`lib/widgets/about_sheet.dart`) |
| Apple privacy manifest | `ios/Runner/PrivacyInfo.xcprivacy`, in the Runner target's resources phase |
| Export-compliance answer | `ITSAppUsesNonExemptEncryption=false` in `ios/Runner/Info.plist` |
| Camera purpose string | `NSCameraUsageDescription` |
| Local-network purpose string | `NSLocalNetworkUsageDescription` |
| App icon, 1024×1024, no alpha | `ios/Runner/Assets.xcassets/AppIcon.appiconset` (regenerate with `tool/generate_icons.py`) |
| Android adaptive icon | `android/app/src/main/res/mipmap-*` |
| Play-format upload artefact | `songs-of-the-church-play-upload.aab` from the **Build apps** workflow |
| targetSdk at Play's current floor | `targetSdk 36` |

The iOS project is compiled on every release run by the `ios-project` job,
which also asserts the privacy manifest actually landed in the built bundle —
a manifest that is referenced but not copied passes the build and fails review.

---

## 3. Apple App Store

### Building

```bash
flutter build ipa --release \
  --build-name=1.2.0 --build-number=<n> \
  --dart-define=APP_VERSION=1.2.0 \
  --dart-define=APP_BUILD=<n> \
  --dart-define=RELAY_URL=wss://your-relay
```

Then open `build/ios/archive/Runner.xcarchive` in Xcode and distribute, or use
Transporter. `--build-number` must increase with every upload.

Note the app has no App Store update banner: `currentTarget()` returns null on
iOS deliberately, because Apple forbids an app pointing users at a download
outside the store. iOS updates come from the App Store alone.

### App Privacy ("nutrition labels")

Answer **Data Not Collected**. That is accurate and it must stay consistent
with `PrivacyInfo.xcprivacy`, which declares `NSPrivacyCollectedDataTypes` as
empty.

The one thing to understand before you answer: an **Online** small-group
session sends the current verse and the display names through a relay. Apple's
definition of "collect" excludes data transmitted only to service a request in
real time and not retained — which is what the relay does. It holds the latest
state in memory so a late joiner lands on the right verse, writes nothing to
disk, has no database, and does not log join codes or session content. If you
ever change the relay to retain sessions, this answer stops being true and
both this form and `web/privacy.html` have to change with it.

Tracking: **No**. There are no analytics, advertising, or attribution SDKs in
the dependency list, and nothing is combined with data from other apps.

### Age rating

4+. No objectionable content, no user-generated content that is publicly
shared, no unrestricted web access. The app is religious in subject matter,
which is a content descriptor Apple does not rate against.

### Screenshots

Required, and they must be real screenshots of this app:

- iPhone 6.9" (1320×2868 or 1290×2796)
- iPad 13" (2064×2752 or 2048×2732) — **required, because the app ships as
  Universal** (`TARGETED_DEVICE_FAMILY = "1,2"`). If you would rather not
  produce iPad screenshots, set that to `"1"` and submit as iPhone-only.

Good candidates: the library with the filter pills, a song open in the reader,
the music staff, presentation mode, and the small-group sheet.

### Review notes

Reviewers test on one device, so write in the notes that the small-group
feature needs two: "Tap the round button at the bottom-left to lead a session;
a second device joins with the code shown. With only one device, the sheet and
join code can still be inspected." Without this, App Review has historically
flagged such features as non-functional under Guideline 2.1.

Also worth stating: the app requires no account and works fully offline.

### Guidelines this app touches

- **2.1 App Completeness** — the small-group caveat above.
- **4.2 Minimum Functionality** — comfortably met; this is not a wrapped
  website. The hymnal is bundled and works offline.
- **5.1.1 Data Collection and Storage** — the camera is requested only at the
  point of scanning, has a purpose string, and the app is fully usable if the
  permission is denied (join codes can be typed). Keep it that way.
- **5.1.2** — no data is shared with third parties.

Sign in with Apple, account deletion, and subscription rules do not apply:
there is no account.

---

## 4. Google Play

### Uploading

Take `songs-of-the-church-play-upload.aab` from the release the **Build apps**
workflow produced. Enable **Play App Signing** on first upload.

`versionCode` comes from the workflow's run number, so it always increases.
Play rejects a re-used `versionCode`, which means you cannot re-upload the
artefact from a re-run — trigger a new run instead.

### Data safety form

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **No** |
| Is all data encrypted in transit? | Yes (relay traffic is `wss://`) |
| Do you provide a way for users to request data deletion? | Not applicable — no data is held off-device; uninstalling removes everything |
| Data used for advertising or tracking? | No |
| Third-party SDKs collecting data? | None |

Same caveat as Apple's form: this answer describes the relay as it is written
in `relay/`. It relays in real time and retains nothing.

### Permissions

Play shows every permission and asks you to justify anything sensitive. None of
these are in the sensitive set (no location, contacts, SMS, call log, photos,
`QUERY_ALL_PACKAGES`, or `MANAGE_EXTERNAL_STORAGE`), so no declaration form is
required — but be ready to explain them:

| Permission | Why |
| --- | --- |
| `INTERNET` | Update check, and the relay for Online sessions |
| `ACCESS_NETWORK_STATE` | Detect whether a network is available at all |
| `ACCESS_WIFI_STATE`, `CHANGE_WIFI_MULTICAST_STATE` | Same-WiFi sessions find the leader by UDP broadcast |
| `CAMERA` | Scanning the leader's join QR code, nothing else. Declared `android:required="false"`, so the app installs on devices without one |

`android:usesCleartextTraffic="true"` is set in the manifest. It is there
because Same-WiFi sessions connect to another phone on the local network over
`ws://`, where there is no certificate to validate and no hostname to pin.
Play allows it; the Play Console pre-launch report will mention it, and this is
the answer.

### Content rating

Fill in the IARC questionnaire honestly and it lands on **Everyone**: no
violence, no sexuality, no profanity, no gambling, no purchases. Two questions
usually catch people out:

- *Does the app let users interact or share content?* — Yes, in a narrow sense:
  a small-group leader shares which verse is showing, and members type a
  display name. It is not open chat and nothing is published.
- *Does the app share the user's location?* — No.

### Target audience and content

Select an audience of 13+ (or 18+) rather than including children. Including
under-13s pulls the app into the Families policy, Google Play's Designed for
Families programme requirements, and stricter SDK rules — for no benefit, since
the app is aimed at congregations rather than children.

### Store listing

Needs a short description (80 chars), a full description (4000), a 512×512
icon, a 1024×500 feature graphic, and at least two phone screenshots. Play also
requires a **public developer email address** on the listing — pick one you are
willing to publish, because it is shown to every user.

---

## 5. Not yet done, and not doable from here

- **Apple signing.** Requires a paid account; the CI `ios-project` job builds
  with `--no-codesign` and produces nothing installable by design.
- **macOS notarisation.** The DMG on GitHub Releases is ad-hoc signed, which is
  why first launch needs a right-click → Open. Notarising it, or shipping to
  the Mac App Store, needs the same paid Developer ID. The Mac App Store would
  additionally need its own `PrivacyInfo.xcprivacy` in `macos/Runner/` and the
  App Sandbox entitlement reviewed — the LAN session host in particular needs
  `com.apple.security.network.server`.
- **Windows code signing.** SmartScreen's warning goes away only with a paid
  certificate (an OV cert also needs reputation to accumulate; an EV cert is
  trusted immediately).
- **Automated store uploads.** Fastlane or the Play Developer API could push
  builds from CI, but both need credentials this repository does not hold.

---

## 6. Order of operations

1. Clear the song texts (§0).
2. Create both developer accounts; start Play identity verification.
3. Generate the Android keystore and add the secrets; back the keystore up.
4. Run **Build apps** and confirm the `.aab` is release-signed.
5. Upload to a Play closed test and start the 12-tester / 14-day clock.
6. Take the screenshots for both stores.
7. Archive and upload the iOS build from Xcode; submit for review.
8. Apply for Play production access once the closed test qualifies.
