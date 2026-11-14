# Vendored `music_kit`

Upstream: https://github.com/misiio/flutter_music_kit @ `0dcab8f` (MIT, see
`LICENSE`). `lib/` and `darwin/` are copied as-is except for the changes
below; `music_kit_platform_interface` is vendored next to it only because the
plugin depends on it by path.

Only the Darwin implementation is kept. Android's half needs a JitPack
dependency (`com.github.misiio:musickitauth`) and Apple credentials baked into
the manifest, which this app does not ship, so the plugin declares iOS and
macOS only.

## Local changes

- `MusicKitPluginPlayer.swift` — the player methods move behind
  `handlePlayerMethod`, annotated `@available(macOS 14, iOS 15)`. On macOS 12
  and 13 `ApplicationMusicPlayer` exists in the SDK but not in the system, and
  the upstream file touched `.shared` at registration, trapping at launch.
  Those versions now answer `ERR_PLAYER_UNAVAILABLE` for player calls while
  library reads keep working.
- Added `seekToPosition` (method key + `MusicKitPlatform.setPlaybackTime` +
  `MusicKit.setPlaybackTime`): upstream only exposed the `playbackTime`
  getter, and the property is settable, which is what a scrubber needs.
- Added `clearQueue` (method key + `MusicKitPlatform.clearQueue` +
  `MusicKit.clearQueue`): `ApplicationMusicPlayer` keeps its queue loaded
  after `stop()`, so macOS keeps showing the now-playing entry its playback
  published next to the app's own session. Assigning an empty queue retires
  it, which a hybrid player needs on every hand-over away from MusicKit.
- `register` installs a `SilentStreamHandler` on the two player event
  channels where there is no player, so the eagerly-subscribing Dart side
  does not see a missing handler.
- A queue's `startingAt` index is bounds-checked instead of trapping, and an
  unsupported item type answers with an error instead of silently doing
  nothing.
- The podspec is renamed to `music_kit` (Flutter looks for a podspec named
  after the plugin, and `sharedDarwinSource` points CocoaPods at `darwin/`).

Re-syncing with upstream means re-applying these; there is no patch file.
