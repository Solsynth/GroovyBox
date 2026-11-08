# GroovyBox

A Flutter music player that streams from any **OpenSubsonic**-compatible
server — Navidrome, Jellyfin, Gonic, Airsonic — and plays audio files imported
from the device itself. Streams are never downloaded; an import is the one copy
the app makes, and it is the user's own music, not a cache. What the app keeps
locally is its own library — songs, lyrics and play history in one SQLite
database, independent of whichever server or file happens to serve them.

There is no setup gate: the app opens on the library it has. Imported files
live in its own storage (`lib/library/local_import.dart`), and a page would
rather nudge you to connect a server or import something (`browseNoSource*`)
than block you behind a form.

## What is here

- **Window shell** — frameless desktop chrome ported from Solian
  (`lib/shell/window_frame.dart`), a responsive shell built from floating
  chrome, and the same design tokens (spacing, radii, warm-paper color ramp) in
  `lib/core/theme.dart`.
- **Server layer** — `lib/library/` maps Subsonic, Jellyfin and Apple Music
  onto one provider-neutral model. Subsonic uses salted token auth (never the
  password); Jellyfin signs in with the `Authorization: MediaBrowser …` header
  that 10.11+ requires and keeps the issued access token in that same header.
  Apple Music is read over its REST API with the two tokens MusicKit hands
  the app (a developer token it generates itself, and the account's music
  user token), and is played by the system's `ApplicationMusicPlayer`
  instead of a stream URL: `lib/library/apple_kit.dart` is the only file that
  imports the plugin, `lib/player/apple_player.dart` drives it, and the
  transport routes to it through `LibrarySource.usesPlatformPlayer`. Covers
  are Apple's own `{w}x{h}` art templates, resized per painted box in
  `artworkUri`. The plugin is vendored under `packages/music_kit` (MIT) so
  the darwin player can expose seek and stay inert on macOS 12/13, where
  `ApplicationMusicPlayer` does not exist.
- **Playback** — one `media_kit` player for the app's lifetime
  (`lib/player/player.dart`), exposed through Riverpod. Shuffle reorders the
  visible queue instead of hiding randomization underneath. The media session
  is `audio_service` (`lib/player/session.dart`): it publishes the current
  track, the queue and the transport state to the notification, the lock
  screen and headset buttons, and routes what they send back into the same
  transport the UI drives. The full player is also a keyboard surface — Space,
  Escape, arrows, Shift+arrows and `L` — bound on the page's own focus, so a
  focused control keeps its keys.
- **Local library** — `lib/data/local/library_database.dart` (Drift, SQLite)
  is where the app remembers songs, whatever server serves them. A track is
  canonical — title, artist, album, duration and a fingerprint of them — and
  each source's own id for it is a *link* row. Adoption happens as you browse:
  every read the aggregator performs (`lib/library/aggregate.dart`) is folded
  into the catalog, so no full sync is needed yet. Two servers carrying the
  same song end up as one track with two links (fingerprint in
  `lib/library/track_identity.dart` ignores bracketed credits, case,
  punctuation and a couple of seconds of length), which is what makes the
  library independent of a *playback source*: removing a source drops its
  links and keeps the track, its lyrics and its play history, so re-adding it —
  or adding a different one with the same songs — picks them up again. Local
  files join the same rows through `local_files`
  (`lib/library/local_library.dart`), a `LibrarySource` that answers from the
  device instead of the network, so browse, search, albums and the play history
  treat an imported track exactly like a streamed one. `play_events` is one row
  per play, written when a track opens and updated as it advances
  (`lib/player/play_tracker.dart`); play counts and "recently played" are
  queries over it, so no counter can drift.
- **Lyrics** — `lib/library/lyrics.dart` normalizes OpenSubsonic structured
  lyrics (timed lines, with romanization and translation layers folded onto the
  words they annotate) and LRC text. `lib/widgets/lyrics_view.dart` draws the
  Apple Music–style column: the sung line in full tone, the rest dimmed, the
  playhead parked a third of the way down, a tap on a line seeking to it.
  `lib/library/lyrics_resolver.dart` decides where the words come from: the
  library first when it has *timed* lines, otherwise
  [LRCLIB](https://lrclib.net) (`lib/library/lrclib.dart`, identified client,
  one request at a time, `Retry-After` honoured), otherwise the library's plain
  block. Every answer is stored in `lyrics_entries`
  (`lib/library/lyrics_store.dart`) against the canonical track, so the second
  play — and any play offline — never asks the network, and a re-tagged or
  re-linked song keeps its words. A confirmed miss is cached for a day; a
  timeout never is.
- **Import** — `LocalImportService` copies picked audio into the app's support
  directory, reads ID3/Vorbis/MP4 tags off the UI isolate, extracts an embedded
  cover next to the file, writes synced or plain lyrics from the tags onto the
  canonical track, and adopts the song. The copy is what plays, so the original
  folder can move or disappear. Importing the same file again is recognised by
  name and length instead of duplicating it; a different file with the same name
  is kept beside the first rather than overwriting it.
- **Screens** — Browse (search + random shelf + recently added), Albums, album
  detail, Playlists, playlist detail, Stats, full Player, Setup, Settings. The
  queue has no page of its own: it is a pane of the player and a sheet in the
  dock, because a third view of one list only made the transport compete with
  itself.
- **Stats** — `lib/screens/stats.dart` reads `play_events` and shows what the
  history adds up to: plays, time listened, songs heard, how many plays ran to
  the end, the most played tracks and artists, and the last dozen plays. All of
  it is aggregate SQL (`LibraryDatabase.playTotals`, `playCountsByTrack`,
  `playCountsByArtist`, `latestPlays`) behind one `ListeningStats` read, so the
  page never walks the play table in Dart. A track no connected source can
  serve still appears — it just is not tappable.

## Design

Two surface languages, deliberately kept apart:

- **Liquid glass** (`lib/core/glass.dart`, `GlassSurface`) is used in exactly
  two places, both of which float over a scrolling page on the compact
  layout: the tab capsule and the now-playing dock. They refract the content
  underneath, share one backdrop capture via `BackdropGroup`, and pages reserve
  clearance with `solBottomChromeInset` so content scrolls beneath them.
  Everything else — the wide rail, settings, panels, the player's transport —
  is tonal. A persistent navigation column or a panel holding live controls and
  artwork is where glass costs frames and legibility without adding anything.
- **Island cards** (`IslandCard` in `lib/widgets/common.dart`) are for content
  in the scrolling plane: settings groups, the setup panel, the wide player
  body. Opaque, tonal, no border, no blur — body text has to stay legible and a
  long list must not pay for a backdrop sample per card.

The dock's lyrics button lifts the capsule into a lyric sheet instead of a
route, so glancing at the next line never loses the page; the player page keeps
the cover beside the words on a wide window and swaps them on a phone.

The now-playing dock is the collapsed player: tapping anywhere on the capsule
that is not a control records its rect and opens `/now-playing` through a
container transform (`lib/shell/dock_morph.dart`), so the capsule grows into the
player instead of a page sliding over it.

The wide layout's rail follows Solian: a solid column beside the page with no
divider, collapsed by default, expanded in place by the page header's menu
button (`RailScope`, `lib/shell/rail_scope.dart`). There is exactly one
navigation toggle — the header's — not one in the rail as well.

Pages and the shell `select` only what they need from the transport. The
position changes once a second while playing; only the dock watches all of it.

No dividers anywhere: groups are separated by tone and space, and the theme
neutralises `Divider` for any stray third-party use.

Wide windows get one centered content column (`ContentFrame`,
`solContentPadding`) that stops growing at `kContentMaxWidth`; the player
switches to a side-by-side cover/controls layout at `kWideScreenWidth`.

Liquid glass is a real shader and needs Flutter GPU, enabled per platform in
`macos/Runner/Info.plist`, `ios/Runner/Info.plist` and
`android/app/src/main/AndroidManifest.xml`. Where the shader is unavailable the
renderer falls back to a frosted approximation automatically, and Settings has
a **Liquid glass** switch that paints the same geometry as flat surfaces.

## First run

The app opens on the setup screen until a server is connected. Enter the server
address (a bare host works — `/rest` is appended for Subsonic, the root for
Jellyfin), username and password, then **Test connection** or **Connect**.

**Apple Music** is the one kind with no fields: the account is whatever
MusicKit reports for this device, so the screen shows a single Connect button
that asks for permission, fetches both tokens and proves them with one read.
It needs the *MusicKit App Service* enabled for the bundle id in the developer
portal, `NSAppleMusicUsageDescription` in `Info.plist` (both already set), and
macOS 14 or iOS 15 for playback. Reads work on macOS 12/13 from the SDK but
the system has no `ApplicationMusicPlayer` there, so the kind stays hidden on
those.

## Development

```sh
flutter pub get
dart run build_runner build   # routes + riverpod providers
flutter analyze
flutter test
flutter run -d macos
```

Generated files: `lib/core/router.gr.dart`, `lib/core/app.g.dart`,
`lib/library/providers.g.dart`, `lib/library/store.g.dart`,
`lib/player/player.g.dart`, `lib/player/apple_player.g.dart`. Do not edit them.

## Layout

```
lib/
  core/      theme tokens, glass surface, routing, providers, responsive helpers
  library/   adapters, models, aggregation, persistence
  player/    playback transport and state
  screens/   one file per route
  shell/     window frame, tab shell, destinations
  widgets/   shared cards, rows, artwork, empty states, the dock
```

Fonts: Nunito (SIL OFL 1.1, see `assets/fonts/OFL.txt`).
