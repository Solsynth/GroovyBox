# GroovyBox

A Flutter music player that streams from any **OpenSubsonic**-compatible
server — Navidrome, Jellyfin, Gonic, Airsonic — rather than managing local
files. Nothing is downloaded: playback streams straight from the server.

## What is here

- **Window shell** — frameless desktop chrome ported from Solian
  (`lib/shell/window_frame.dart`), a responsive rail/capsule-bar shell, and the
  same design tokens (spacing, radii, warm-paper color ramp) in
  `lib/core/theme.dart`.
- **Server layer** — `lib/server/subsonic.dart` talks to the `/rest` API with
  Subsonic token auth (salted token, never the password). `lib/server/models.dart`
  holds the wire models.
- **Playback** — one `media_kit` player for the app's lifetime
  (`lib/player/player.dart`), exposed through Riverpod. Shuffle reorders the
  visible queue instead of hiding randomization underneath.
- **Screens** — Browse (search + random shelf + recently added), Albums, album
  detail, Playlists, playlist detail, Queue, full Player, Setup, Settings.

## First run

The app opens on the setup screen until a server is connected. Enter the server
address (a bare host works — `/rest` is appended), username and password, then
**Test connection** or **Connect**. The password is exchanged for a salted token
that is what gets stored.

## Development

```sh
flutter pub get
dart run build_runner build   # routes + riverpod providers
flutter analyze
flutter test
flutter run -d macos
```

Generated files: `lib/core/router.gr.dart`, `lib/core/app.g.dart`,
`lib/core/server_data.g.dart`, `lib/player/player.g.dart`. Do not edit them.

## Layout

```
lib/
  core/      theme tokens, routing, providers, responsive helpers
  player/    playback transport and state
  screens/   one file per route
  server/    Subsonic client and models
  shell/     window frame, tab shell, destinations
  widgets/   shared rows, artwork, empty states
```

Fonts: Nunito (SIL OFL 1.1, see `assets/fonts/OFL.txt`).
