# Songs of the Church

A cross-platform **Flutter / Dart** rebuild of the
[songsofthechurch.netlify.app](https://songsofthechurch.netlify.app) hymnal.
It runs natively and offline on **Android, iOS, Web, macOS, Windows and Linux**
from a single codebase.

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
- **Theming** — iOS-style light/dark palettes, persisted between launches.

## Small group / live sessions

Tap the round button at the bottom-left of the library to open the small-group
sheet.

- **Lead a group:** a short join code (and QR) is generated. Members join, and
  whatever verse/slide you are on in the reader or set-list presenter is pushed
  to everyone. You can blank all screens from the sheet.
- **Join a group:** enter the leader's code (or scan the QR on mobile) to open a
  full-screen live view that follows the leader.

How it works per platform:

- **Native (Android/iOS/desktop):** the leader hosts a WebSocket server on the
  local network and answers UDP-broadcast discovery probes, so members can join
  by code with no internet — just the same WiFi or a hotspot.
- **Web:** browsers cannot host a server, so the web build syncs via a
  same-origin `BroadcastChannel`. This lets you try the flow across **two tabs
  of the same browser** (handy on GitHub Pages), but is not a cross-device
  transport.

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
