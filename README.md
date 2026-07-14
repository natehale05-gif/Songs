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
- **Theming** — iOS-style light/dark palettes, persisted between launches.

## Project layout

```
assets/data/songs.json        Extracted song / author / category / melody data
lib/models.dart               Data models + JSON loading (SongBook)
lib/app_state.dart            Favorites, Popular tracking, theme, set list
lib/audio.dart                Tone / pitch-pipe synthesis
lib/theme.dart                Color tokens & category colors
lib/widgets/                  Music staff painter, pitch-pipe sheet
lib/screens/                  Library, reader, author, set-list presentation
```

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

The original site's networked "group session" live-sync (an Ably-backed feature
where a host broadcasts the current verse to a congregation) and its
crowd-sourced Popular voting rely on an external realtime service and API key,
so they are not reproduced here. Popular is computed locally from how often you
open each song, and presentation mode runs entirely on-device.
