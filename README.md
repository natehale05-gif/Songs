# Songs

A Flutter app for presenting worship songs in a small group — and letting the
whole group follow along live on their own phones. It is designed to work
**offline**: everything runs over your local WiFi (or a phone hotspot), so no
internet connection is required.

## Features

- **Offline song library** — songs are stored on the device and seeded with a
  few public-domain hymns on first launch. Add, edit and delete your own songs.
- **Lead a small group session** — the leader's device hosts a session on the
  local network and picks songs, navigates verse-by-verse and can blank the
  screen.
- **Join via code or QR** — members join either by scanning the leader's QR
  code or by typing a short join code. No IP addresses to remember.
- **Live mirroring** — whatever section the leader is on shows instantly on
  every member's screen.

## How the offline small-group feature works

The leader's device runs a small WebSocket server (via `shelf`) on the local
network. When a session starts it:

1. Generates a short, easy-to-read join code (ambiguous characters like `0`/`O`
   are excluded).
2. Detects its LAN IPv4 address and picks a free port.
3. Encodes the host, port and code into a QR code.
4. Advertises itself for **code-only joining** using lightweight UDP broadcast
   discovery, so a member who only knows the code can find the leader on the
   same network without typing an address.

Members either scan the QR (which contains the full connection details) or type
the code (which is resolved to the leader via UDP discovery), then connect over
a WebSocket and receive a snapshot of exactly what to display every time the
leader changes something.

All of this works with **no internet** — the devices only need to be on the
same local network.

## Project layout

```
lib/
  models/        # Pure Dart data models (Song, snapshots, sync messages)
  data/          # Offline storage + seed songs
  services/      # Networking: host, client, discovery, join codes
  controllers/   # ChangeNotifier state for library, leader and member
  ui/            # Screens and widgets
```

## Running

```bash
flutter pub get
flutter run
```

## Testing

```bash
flutter analyze
flutter test
```

The test suite covers model serialization, join-code handling, the QR payload
format and a real end-to-end sync between a host and a client over a loopback
socket.
