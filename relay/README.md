# Songs of the Church — online relay

A small WebSocket server that lets small-group sessions work **over the
internet**, so the leader and members can be on cellular data, on different
WiFi networks, or in different cities.

## Why this exists

The app's original small-group mode has the leader host a WebSocket server on
the local network. That is genuinely offline — no internet needed — but it only
works when every device is on the same WiFi. It cannot work over cellular,
because phones sit behind carrier NAT: there is no address for anyone to dial,
and no port that can be opened.

The fix is for **both** sides to dial *out* to a server they can each reach.
That server is this relay. It does no more than that: it matches a leader and
its members by join code and forwards frames between them.

## What it does and does not do

- Rooms are keyed by the six-character join code the app already generates.
- The leader's frames are forwarded verbatim to every member of its room.
- The last state frame is cached, so somebody joining halfway through a song
  immediately sees the current verse instead of a blank screen.
- The leader holds a random token, so only it can reclaim its own room after a
  dropped connection — a phone that slept does not lose its group.
- Frames are **opaque** to the relay: it only peeks at `t` to spot a state
  frame worth caching. The app's protocol can change without redeploying.
- Rooms are dropped once empty, and swept after 6 hours idle.

It stores nothing on disk, has no accounts, and no database. A room exists only
while somebody is connected to it.

**On privacy:** traffic is not end-to-end encrypted. `wss://` protects it in
transit, but the relay operator can see which song and verse a group is on.
Anyone who learns a join code can also listen in while that session is live.
Codes are random from a 31-character alphabet (about 887 million combinations),
so guessing one is impractical, but treat this as "not secret" rather than
"private". Nothing personal beyond a chosen display name is transmitted.

## Deploy it

Any host that can run a container and keep a WebSocket open works. The image
compiles to a single native binary on a `scratch` base, so it is a few
megabytes and starts instantly.

CI already builds and publishes it on every change to `relay/`:

```
ghcr.io/natehale05-gif/songs-relay:latest
```

so you can usually skip building entirely. Packages pushed to GHCR start out
**private** — if your host pulls anonymously, set the package to public under
*Packages → songs-relay → Package settings*, or give the host a pull secret.

### Fly.io

Deploy the prebuilt image:

```bash
cd relay
fly launch --copy-config --no-deploy          # creates the app from fly.toml
fly deploy --image ghcr.io/natehale05-gif/songs-relay:latest
fly status                                    # note the hostname
```

Or let Fly build from source instead:

```bash
cd relay
fly launch --copy-config --now
```

`fly.toml` deliberately keeps one machine warm (`min_machines_running = 1`).
Scaling to zero would drop a live session mid-song.

### Render

Point a new Web Service at this directory; `render.yaml` is already set up.
Avoid tiers that idle a service to sleep, for the same reason.

### Anywhere else / locally

```bash
cd relay
dart pub get
dart run bin/server.dart            # PORT=8080 by default
```

```bash
docker build -t songs-relay .
docker run -p 8080:8080 songs-relay
```

## Point the app at it

The relay URL is compiled into the app, so builds need it:

```bash
flutter build apk --release --dart-define=RELAY_URL=wss://your-relay.fly.dev
```

In CI, set a repository **variable** named `RELAY_URL` (Settings → Secrets and
variables → Actions → Variables). It is a public URL, not a secret. Both
workflows pass it through automatically.

Without `RELAY_URL` the app still builds and the same-WiFi mode works exactly
as before — the Online option is simply shown as unavailable, rather than
failing at connect time with something cryptic.

## Endpoints

| Path | Purpose |
| --- | --- |
| `GET /health` | Returns `ok rooms=N`. Used by platform health checks. |
| `WS /live?code=X&role=leader&token=T` | Leader end of a session. |
| `WS /live?code=X&role=member` | Member end of a session. |

## Tests

```bash
cd relay
dart test
```

Covers the room registry directly (fan-out, late-joiner replay, code
isolation, leader reclaim, sweeping, limits) plus a group that serves the real
handler on a loopback port and drives it over actual WebSockets.

The app side has matching tests in `test/relay_client_test.dart`, which start
this server as a subprocess and run the app's own client against it.
