# GroovyBox

A Flutter music player that streams from any **OpenSubsonic**-compatible
server — Navidrome, Jellyfin, Gonic, Airsonic — and plays audio files imported
from the device itself, and works without a network: every library's answers are
kept on the device, and tracks can be downloaded to play offline. What the app
keeps locally is its own library — songs, lyrics, cached answers and play
history in one SQLite database, independent of whichever server or file happens
to serve them.

There is no setup gate: the app opens on the library it has. Imported files
live in its own storage (`lib/library/local_import.dart`), and a page would
rather nudge you to connect a server or import something (`browseNoSource*`)
than block you behind a form.

## What is here

- **Window shell** — frameless desktop chrome ported from Solian
  (`lib/shell/window_frame.dart`), a responsive shell built from floating
  chrome, and the same design tokens (spacing, radii, glacier-paper color
  ramp) in `lib/core/theme.dart`.
- **Dynamic color** — the palette follows the music. With the setting on
  (Settings → Appearance, on by default) the playing track's cover is decoded
  at 128 px, its dominant usable colour is scored by Material Color Utilities,
  and that colour seeds the whole scheme (`lib/core/dynamic_color.dart`). A
  coverless or grayscale cover leaves the app's own teal seed in place.
- **Server layer** — `lib/library/` maps Subsonic, Jellyfin, Apple Music and
  NetEase Cloud Music onto one provider-neutral model. Subsonic uses salted
  token auth (never the password); Jellyfin signs in with the
  `Authorization: MediaBrowser …` header that 10.11+ requires and keeps the
  issued access token in that same header.
  Apple Music is read over its REST API with the two tokens MusicKit hands
  the app (a developer token it generates itself, and the account's music
  user token), and is played by the system's `ApplicationMusicPlayer`
  instead of a stream URL: `lib/library/apple_kit.dart` is the only file that
  imports the plugin, `lib/player/apple_player.dart` drives it, and the
  transport routes to it through `LibrarySource.usesPlatformPlayer`. Covers
  are Apple's own `{w}x{h}` art templates, resized per painted box in
  `artworkUri`. The landing page opens with its curated shelves — personal
  mixes, recently played, station suggestions — which no other provider has a
  word for; a station is
  queued as a `LibrarySong` with `isRadio`, so the dock, the queue panel and
  the scrobbler need no special case, and the transport hands the system
  player the whole run from the current track onward so a finished track
  advances instead of stopping dead. The plugin is vendored under `packages/music_kit` (MIT) so
  the darwin player can expose seek and stay inert on macOS 12/13, where
  `ApplicationMusicPlayer` does not exist.
- **NetEase Cloud Music** — the same provider-neutral layer, against a
  self-hosted [NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi)
  bridge the user runs themselves; no address is shipped or defaulted. The
  address is the API server's own root (`http://host:3000`), not a path in
  front of it and not the project's docs site: the two wrong shapes are
  diagnosed by what the address answers — a 404 for a prefix the bridge does
  not mount, HTML for a web page — instead of surfacing as a bare HTTP error.
  Sign-in is the bridge's QR flow (mint a unikey, render the code, poll
  `801 → 802 → 803`): it is expressed as `InteractiveLoginAdapter` steps, so
  the setup screen renders whatever steps an adapter hands it and never asks
  the kind. The session cookie lives in `SourceConfig.auth` like every other
  token.
  Reads map `ar`/`al`/`dt` onto the neutral models; the red-heart list is
  `RatedSource`, the daily mix is a `CuratedSource` shelf, and lyrics merge
  `tlyric` as a translation layer. It is also a `LyricsQuerySource`: a
  signed-in account can find words for a song it does not hold — a local file,
  a Subsonic track — by searching its catalogue and reading the matching row's
  `/lyric`, so it joins LRCLIB in the resolver's chain and in the manual
  picker. It is an `ExtendableSource` too: the account's own playlists,
  subscribed albums and hearts are its library, and `searchCatalog` is the
  store search the Explore tab reads. That split is the reason
  `LibrarySource.search` is defined as *holdings* and
  `CatalogueSource.searchCatalogue` as the whole service: `/cloudsearch` only
  answers the latter, so the library tab filters its hits against the held set
  (hearts, playlist `trackIds`, subscribed albums) instead of listing tracks
  the user never added.
  Playback URLs are minted per request by
  `song/url/v1`, which is `ResolvedStreamSource` — the transport asks that
  capability before falling back to `streamUri`, so a refused mint falls
  through the cross-library fallback like a dead URL. A VIP track is not
  refused, though: the bridge mints an excerpt and marks it with
  `freeTrialInfo`, so the source answers `PreviewOnlyException`, which carries
  the trial URL instead of playing it. The transport then looks the recording
  up in every connected library (`findCopies`, the same answer the "other
  versions" sheet shows), plays the first full copy it can resolve, rewrites
  the playing row to that copy, and opens the trial only when nobody has the
  whole track. Two details of that mint are what keep the check honest: the
  quality asked for is part of the answer (a VIP-*quality* master comes back
  as a trial to an account that may still stream it at a lower level, so the
  levels are tried in order), and `freeTrialInfo` is a flag about the
  account's privilege rather than the file, so a mint reporting the track's
  full length is the track. The lookup itself is looser than the catalog's
  fingerprint on purpose: `TrackIdentity.couldBeSameRecording` accepts the
  same recording under another service's tags — a featured credit on one side
  only, ten seconds of timing drift — while the length still rules out a live
  or remixed take, and the closest length wins among candidates.
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
- **Offline answers** — `lib/library/http_cache.dart` keeps every JSON read a
  library answers (`http_cache` in the database), keyed by source, method, host,
  path and the meaningful query parameters — the auth parameters (`t`, `s`,
  `u`, `api_key`, `cookie`) are stripped, so no credential is written into a
  key and a re-joined server is the same key again. Each source installs one
  `CachingInterceptor` on its own Dio; the plugin host, which performs requests
  itself, asks the same cache around `_perform`. A read walks three states: a
  fresh entry answers with no request; otherwise the network answers and
  replaces the entry; if the network is *gone* (timeout, DNS, 5xx from a
  gateway) the expired entry answers anyway and the source is reported as
  offline, so a banner says "showing what was saved" instead of a library
  looking empty. A refusal (a 4xx, a server's own `status: failed`) is never
  answered from disk. Anything that writes — a POST/PUT/DELETE, or a GET the
  adapter marks as a mutation (Subsonic's `star`) — drops the library's entries
  first. Random draws, login polls and minted playback URLs use
  `CachePolicy.none` and are never stored. Entries older than two weeks are
  pruned at startup; Settings shows the count and size and can clear them.
- **Downloads** — `lib/library/downloads.dart` copies a library's stream into
  the app's own storage (`downloads/` under the support directory) and records
  the link it came from in `downloads`, with the cover written beside it. It is
  *not* an import: the canonical track and its link stay as they were, so
  removing a download deletes bytes and nothing else, and a download survives
  its library being disconnected. `Playback._openCurrent` asks for the copy
  first, before any URL is minted, so a downloaded track plays from disk with
  no server at all. The player's menu downloads or removes the playing track;
  an album's and a playlist's hero download the whole collection; Settings →
  Offline opens `/downloads`, which lists what is kept, what it costs, plays it
  and removes one on long press. Files are written to a staging folder and
  renamed only when complete, and a sweep deletes anything no row claims.
- **Dashboard** — the explore tab is one scroll of shelves, and the page is
  the user's: sections fold and stay folded (`CollapsedSections`, keyed
  `page:section`), and a customize sheet reorders them, removes them, and pins
  a playlist as a section of its own (`lib/core/dashboard_layout.dart`,
  `lib/widgets/dashboard.dart`). The arrangement is one JSON value in prefs.
  Every section names the library that provided it, and the same sheet opens
  from Settings, so the dashboard is arranged in either place.
- **Smart shuffle** — one mix from the device's whole library, planned in
  `lib/library/smart_shuffle.dart` from hearts, play history and the account's
  curated shelves (`ShuffleSeeds`). One recording is one entry however many
  libraries hold it; a heart outranks a recommendation, which outranks a plain
  row, and play count adds taste while a recent play subtracts. The queue
  interleaves artists so a shuffle does not become an album, and genres and
  moods (six buckets, matched on words because services spell them
  differently) are shown as shelves of their own on `/smart-shuffle`, opened
  from Explore and Settings.
- **Screens** — Explore (curated shelves, random draw, recently added), Search,
  the Library (albums, artists and one merged Playlists list), album and
  playlist detail, Profile, Player, Setup, Settings. Every collection page opens
  with one `CollectionHero` whose title is the collection's own name and whose
  meta line names where it lives and who made it — a playlist's creator, not its
  first track's artist. A playlist page can also enter selection mode
  (`lib/widgets/track_selection.dart`): the mode is announced on the artwork —
  every cover mutes, a tap stamps it with a check — so no row changes shape and
  no slot is taken from the number, the title or the duration. The hero keeps
  the collection's own actions unchanged; a batch gets its own floating glass
  bar above the now-playing dock, offering play in playlist order, add to
  another playlist (`lib/widgets/playlist_picker.dart`, shared with the player's
  single-track picker), download, and remove in one write behind a confirm — a
  batch cannot be undone one row at a time. The queue has no page of its own: it
  is a pane of the player and a sheet in the dock, because a third view of one
  list only made the transport compete with itself.
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
