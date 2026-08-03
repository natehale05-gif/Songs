# Songs of the Church

A cross-platform **Flutter / Dart** rebuild of the
[songsofthechurch.netlify.app](https://songsofthechurch.netlify.app) hymnal.
It runs natively and offline on **Android, iOS, Web, macOS, Windows and Linux**
from a single codebase.

## Download

[![Windows](https://img.shields.io/badge/Download-Windows-0078D4?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/natehale05-gif/Songs/releases/latest/download/songs-of-the-church-windows-setup.exe)
[![macOS](https://img.shields.io/badge/Download-macOS-000000?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/natehale05-gif/Songs/releases/latest/download/songs-of-the-church-macos.dmg)
[![Linux](https://img.shields.io/badge/Download-Linux-E95420?style=for-the-badge&logo=linux&logoColor=white)](https://github.com/natehale05-gif/Songs/releases/latest/download/songs-of-the-church-x86_64.AppImage)
[![Android](https://img.shields.io/badge/Download-Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://github.com/natehale05-gif/Songs/releases/latest/download/songs-of-the-church.apk)
[![Web](https://img.shields.io/badge/Open-in%20browser-1C3975?style=for-the-badge&logo=googlechrome&logoColor=white)](https://natehale05-gif.github.io/Songs/)

One file per platform, and all 715 songs work offline the moment it opens.

| Platform | You get | What to do |
| --- | --- | --- |
| **Windows** | `…-windows-setup.exe` | Run it. Installs for just you, so there's no admin prompt, and adds Start Menu and desktop shortcuts. |
| **macOS** | `…-macos.dmg` | Open it, drag the app to Applications. |
| **Linux** | `…-x86_64.AppImage` | `chmod +x` it and run — no install, no dependencies. |
| **Android** | `songs-of-the-church.apk` | Open it on your phone and tap Install. One APK, every device. |
| **Web** | nothing to install | Works in any browser; "Add to Home Screen" installs it as an app. |

Prefer plain archives? Every release also ships
`…-windows-x64.zip`, `…-macos.zip` and `…-linux-x64.tar.gz`.

The download links always resolve to the newest
[release](https://github.com/natehale05-gif/Songs/releases).

### First launch

The desktop builds aren't code-signed — signing needs a paid Apple/Microsoft
certificate — so each OS asks once whether you trust the app:

- **macOS** — right-click the app and choose *Open*, then *Open* again. On
  macOS 15+, go to *System Settings → Privacy & Security → Open Anyway*.
- **Windows** — if SmartScreen appears, choose *More info → Run anyway*.
- **Linux** — nothing; just make the AppImage executable.
- **Android** — because the APK doesn't come from the Play Store, Android asks
  you to allow installs from your browser the first time. Tap *Settings* on the
  prompt, turn it on, then go back.

You only do this the first time. The web app has no such prompt.

Publish a new set of builds by running the **Build apps** workflow from
the Actions tab, or by pushing a `v*` tag.

### Staying up to date

The app checks for a newer version on launch and shows a slim bar offering it.
Dismissing hides that version until a later one ships, and a failed check is
silent — this app works offline, so it never treats "no network" as an error.

- **Web** — the bar compares the deployed build against the running one and
  offers a reload. Flutter no longer ships a caching service worker (the one
  it generates now unregisters itself), so a reload really does fetch the new
  build. A browser holding an older cached copy may need one hard refresh
  (Ctrl/Cmd+Shift+R) to pick this up the first time.
- **Windows, macOS, Linux, Android** — the bar links straight to the new
  download for that platform. Installing over the top keeps your favourites
  and set list, since those live outside the app bundle.

Builds know their own version because CI passes
`--dart-define=APP_VERSION` / `APP_BUILD`. A build made locally has neither, so
it never prompts.

Fully silent self-updating isn't possible for the desktop and Android builds:
macOS and Windows would need paid signing certificates to update without a
prompt, and Android cannot install an APK without the user confirming.

### Android signing (one-time setup)

Android refuses to install an unsigned APK, and only a build signed with the
**same** key can update one already installed. Generate a key once:

```bash
tool/make_android_keystore.sh
```

It writes `android/upload-keystore.jks` and `android/key.properties` — both
gitignored, never commit them — and prints four values to add under
*Settings → Secrets and variables → Actions*:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the base64 blob the script prints |
| `ANDROID_KEYSTORE_PASSWORD` | your keystore password |
| `ANDROID_KEY_PASSWORD` | same password |
| `ANDROID_KEY_ALIAS` | `upload` |

Until those exist the workflow still builds an APK, but signs it with the
throwaway debug key: it installs fine, yet a later release won't upgrade it in
place. **Back the keystore up** — losing it means the same thing permanently.

### Publishing to the App Store and Google Play

The repository already carries what the stores check — a published
[privacy policy](web/privacy.html), Apple's `PrivacyInfo.xcprivacy`, the export
compliance answer, and a Play-format `.aab` alongside the APK. What is left is
developer accounts, signing identities and the store questionnaires, all of
which are walked through in
[`docs/store-submission.md`](docs/store-submission.md) — including the one
thing worth settling before spending any money, which is confirming you have
the right to distribute each song's text.

## Features

- **715 songs** across English, Spanish, Hebrew, Greek, Albanian and Chinese,
  each with verses, choruses, musical key, tune name and scripture reference.
- **Library** — alphabetically grouped list with live search (title, author,
  scripture, verse text, hymn number), category filter pills with counts,
  language filters, **Favorites**, and a locally-derived **Popular** list.
- **Reader** — immersive light/dark reading view with **scroll** and
  **tap-through** modes, verse/chorus interleaving, a per-verse picker,
  adjustable font size, hold-to-play **starting pitch**, a chromatic
  **pitch pipe**, and a rendered **music staff** of each hymn's opening melody.
- **Author biographies** — dates, quotes and cross-linked songs for 26 authors.
- **Set lists** — build one manually or generate a random set, then run a
  full-screen **presentation mode** that flows title cards and verses across
  the whole set with tap navigation.
- **Small group (live sessions)** — tap the circular button in the bottom-left
  to open a bottom sheet where you can **lead** a group or **join** one by code
  or QR. The leader hosts the session and, as they move through verses in the
  reader or set-list presenter, every member's screen mirrors the current verse
  in real time. Works **offline** — see below.
- **Theming** — iOS-style light/dark palettes that follow the device's system
  appearance and switch with it while the app is open.

## Small group / live sessions

Tap the round button at the bottom-left of the library to open the small-group
sheet.

- **Lead a group:** a short join code (and QR) is generated. Members join, and
  whatever verse/slide you are on in the reader or set-list presenter is pushed
  to everyone. You can blank all screens from the sheet.
- **Join a group:** enter the leader's code (or scan the QR on mobile) to open a
  full-screen live view that follows the leader.

### Same WiFi or Online

The sheet offers two transports, and the leader's panel shows which one a
running session is using.

| | Reach | Needs internet |
| --- | --- | --- |
| **Same WiFi** | One local network or hotspot | No — fully offline |
| **Online** | Cellular, any network, any distance | Yes, for everyone |

**Same WiFi** is the original mode: the leader hosts a WebSocket server on the
local network and answers UDP-broadcast discovery probes, so members join by
code with no internet at all. On the web build, browsers cannot host a server,
so this falls back to a same-origin `BroadcastChannel` — useful for trying the
flow across two tabs, but not a cross-device transport.

**Online** carries the session through a relay instead. Both the leader and the
members dial *out* to it, which is what makes it work over cellular: phones sit
behind carrier NAT, so there is no address to dial and no port to open, and a
directly-hosted session cannot be reached. The relay matches them by join code
and forwards the current verse. It works identically on web and native.

Online needs a relay you run — a single small container. The **Deploy relay**
workflow stands one up on Fly from the Actions tab, so the only local step is
creating a token; see [`relay/README.md`](relay/README.md). Then set a
repository variable `RELAY_URL` (e.g. `wss://songs-relay.fly.dev`) and re-run
**Deploy web to GitHub Pages** and **Build apps** so the value is compiled in.

Both steps are needed. A relay that is running changes nothing on its own, and
a build without `RELAY_URL` shows Online as unavailable rather than failing
when tapped. Everything else — the whole hymnal, and Same WiFi sessions — works
exactly as before either way.

Traffic through the relay is `wss://`-encrypted in transit but not end to end:
the relay operator can see which verse a group is on, and anyone who learns a
live join code can follow along. Codes are random out of ~887 million, so
guessing is impractical — but treat a session as "not secret".

## Project layout

```
assets/data/songs.json        Extracted song / author / category / melody data
lib/models.dart               Data models + JSON loading (SongBook)
lib/app_state.dart            Favorites, Popular tracking, theme, set list
lib/audio.dart                Tone / pitch-pipe synthesis
lib/theme.dart                Color tokens & category colors
lib/widgets/                  Music staff painter, pitch-pipe sheet
lib/screens/                  Library, reader, author, set-list presentation
lib/live/                     Live small-group feature (transport, controller, UI)
```

The `lib/live/` module is self-contained: pure-Dart models (`live_snapshot`,
`frame`, `join_code`, `connection_info`), a platform-selected transport
(`host`/`client` with `_io` LAN and `_web` BroadcastChannel implementations),
a `LiveSessionController`, and the sheet / member view UI.

## Running

```bash
flutter pub get
flutter run                 # pick a connected device / platform
flutter run -d chrome       # web
flutter build apk           # Android
flutter build ios           # iOS
flutter build macos         # macOS  (also: windows / linux / web)
```

Building for **Linux** additionally needs the GTK and GStreamer headers — the
latter are required by `audioplayers_linux`, and CMake fails to configure
without them:

```bash
sudo apt-get install -y clang cmake ninja-build pkg-config \
  libgtk-3-dev liblzma-dev \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
```

## Testing

```bash
flutter analyze
flutter test
```

## Notes

The original site's networked "group session" live-sync is reimplemented here as
the offline **small group** feature described above — but without any external
service or API key. Instead of a cloud realtime backend, the leader hosts
directly on the local network (native) or over a same-browser channel (web), so
it works offline.

Crowd-sourced Popular voting still relied on an external service, so **Popular**
is computed locally from how often you open each song.
