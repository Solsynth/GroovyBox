import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Full-window player: large cover, scrubber, transport and volume.
///
/// This is the only place seeking happens from the page stack; the dock shows
/// position but leaves dragging to a control with room for it.
///
/// The page is built around a color field taken from the cover, with the
/// controls on a glass capsule so they stay legible over whatever the artwork
/// paints. On a wide window the cover and the controls sit side by side
/// instead of stacking in a narrow column.
@RoutePage()
class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);
    final song = playback.current;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (song == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: TextButton.icon(
            onPressed: () => context.router.maybePop(),
            icon: const Icon(Symbols.arrow_back_rounded),
            label: const Text('Nothing is playing'),
          ),
        ),
      );
    }

    final duration = playback.duration == Duration.zero
        ? song.duration
        : playback.duration;
    final maxMs = duration.inMilliseconds.toDouble();
    final positionMs = playback.position.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();
    final wide = isWideScreen(context);

    final scrubber = _Scrubber(
      positionMs: positionMs,
      maxMs: maxMs,
      position: playback.position,
      duration: duration,
      onSeek: (value) => controller.seek(Duration(milliseconds: value.round())),
    );

    final transport = _Transport(playback: playback, controller: controller);

    final volume = _VolumeControl(
      volume: playback.volume,
      onChanged: controller.setVolume,
      onSaved: (value) => saveVolume(ref, value),
    );

    return Scaffold(
      // Opaque: this page owns the whole window, and the page it grew out of
      // must not show through the artwork blur.
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // The cover, blown up and blurred, gives the page a colour field
          // without introducing a gradient of our own.
          Positioned.fill(
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Opacity(
                  opacity: 0.4,
                  child: LibraryArtwork(
                    sourceId: song.sourceId,
                    artId: song.artId,
                    radius: 0,
                    fallbackIcon: Symbols.music_note_rounded,
                  ),
                ),
              ),
            ),
          ),
          // A scrim so text and glass always have something even behind a
          // bright cover; without it the blurred art washes the labels out.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface.withValues(alpha: 0.55),
                    colorScheme.surface.withValues(alpha: 0.82),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _PlayerHeader(
                  onClose: () => context.router.maybePop(),
                  title: 'Now playing',
                ),
                Expanded(
                  child: wide
                      ? _WidePlayerBody(
                          song: song,
                          scrubber: scrubber,
                          transport: transport,
                          volume: volume,
                        )
                      : _CompactPlayerBody(
                          song: song,
                          scrubber: scrubber,
                          transport: transport,
                          volume: volume,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  final VoidCallback onClose;
  final String title;

  const _PlayerHeader({required this.onClose, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SolSpace.sm),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Symbols.keyboard_arrow_down_rounded),
          ),
          const Spacer(),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Compact: cover, copy, and the controls on a tonal panel pinned to the
/// bottom of the page.
///
/// The panel is *not* glass: it holds the scrubber, the transport and the
/// volume, and a sampled material behind moving controls plus live artwork is
/// both noisy and expensive. The glass in this app is reserved for the dock
/// and the tab bar — chrome that only ever floats over a scrolling page.
class _CompactPlayerBody extends StatelessWidget {
  final LibrarySong song;
  final Widget scrubber;
  final Widget transport;
  final Widget volume;

  const _CompactPlayerBody({
    required this.song,
    required this.scrubber,
    required this.transport,
    required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverSize = (constraints.maxHeight * 0.46).clamp(180.0, 380.0);
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            SolSpace.xl,
            0,
            SolSpace.xl,
            SolSpace.lg,
          ),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _Cover(song: song, size: coverSize),
                ),
              ),
              _TrackCopy(song: song, centered: true),
              const SizedBox(height: SolSpace.lg),
              IslandCard(
                cornerRadius: SolRadius.xxl,
                padding: const EdgeInsets.fromLTRB(
                  SolSpace.lg,
                  SolSpace.md,
                  SolSpace.lg,
                  SolSpace.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    scrubber,
                    transport,
                    const SizedBox(height: SolSpace.xs),
                    volume,
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Wide: cover on the left, everything you can do to the track on the right,
/// both inside one tonal panel so the pair reads as a single object.
class _WidePlayerBody extends StatelessWidget {
  final LibrarySong song;
  final Widget scrubber;
  final Widget transport;
  final Widget volume;

  const _WidePlayerBody({
    required this.song,
    required this.scrubber,
    required this.transport,
    required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SolSpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: IslandCard(
            cornerRadius: SolRadius.xxl,
            padding: const EdgeInsets.all(SolSpace.xxl),
            emphasised: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  flex: 4,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _Cover(song: song, size: null),
                  ),
                ),
                const SizedBox(width: SolSpace.xxxl),
                Flexible(
                  flex: 5,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TrackCopy(song: song, centered: false),
                      const SizedBox(height: SolSpace.lg),
                      scrubber,
                      const SizedBox(height: SolSpace.sm),
                      transport,
                      const SizedBox(height: SolSpace.lg),
                      volume,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  final LibrarySong song;
  final double? size;

  const _Cover({required this.song, required this.size});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final artwork = LibraryArtwork(
      sourceId: song.sourceId,
      artId: song.artId,
      radius: SolRadius.xl,
      size: size,
      fallbackIcon: Symbols.album,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(SolRadius.xl),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.20),
            blurRadius: 40,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: size == null
          ? SizedBox.expand(child: artwork)
          : SizedBox.square(dimension: size, child: artwork),
    );
  }
}

class _TrackCopy extends StatelessWidget {
  final LibrarySong song;
  final bool centered;

  const _TrackCopy({required this.song, required this.centered});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          song.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          song.album == null
              ? song.subtitle
              : '${song.subtitle}  ·  ${song.album}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Scrubber extends StatelessWidget {
  final double positionMs;
  final double maxMs;
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;

  const _Scrubber({
    required this.positionMs,
    required this.maxMs,
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Slider(
          value: positionMs,
          max: maxMs <= 0 ? 1 : maxMs,
          onChanged: maxMs <= 0 ? null : onSeek,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SolSpace.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDuration(position), style: labelStyle),
              Text(formatDuration(duration), style: labelStyle),
            ],
          ),
        ),
      ],
    );
  }
}

class _Transport extends StatelessWidget {
  final PlaybackState playback;
  final Playback controller;

  const _Transport({required this.playback, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Shuffle',
          isSelected: playback.shuffle,
          onPressed: () => controller.setShuffle(!playback.shuffle),
          icon: const Icon(Symbols.shuffle_rounded),
        ),
        const SizedBox(width: SolSpace.xs),
        IconButton(
          tooltip: 'Previous',
          onPressed: controller.previous,
          iconSize: 32,
          icon: const Icon(Symbols.skip_previous_rounded),
        ),
        const SizedBox(width: SolSpace.xs),
        IconButton.filled(
          tooltip: playback.playing ? 'Pause' : 'Play',
          onPressed: controller.togglePlayPause,
          iconSize: 36,
          padding: const EdgeInsets.all(SolSpace.lg),
          icon: Icon(
            playback.playing
                ? Symbols.pause_rounded
                : Symbols.play_arrow_rounded,
          ),
        ),
        const SizedBox(width: SolSpace.xs),
        IconButton(
          tooltip: 'Next',
          onPressed: playback.hasNext ? controller.next : null,
          iconSize: 32,
          icon: const Icon(Symbols.skip_next_rounded),
        ),
        const SizedBox(width: SolSpace.xs),
        IconButton(
          tooltip: playback.repeatMode == PlaybackRepeatMode.single
              ? 'Repeat song'
              : 'Repeat',
          isSelected: playback.repeatMode != PlaybackRepeatMode.off,
          onPressed: controller.cycleRepeatMode,
          icon: Icon(
            playback.repeatMode == PlaybackRepeatMode.single
                ? Symbols.repeat_one_rounded
                : Symbols.repeat_rounded,
          ),
        ),
      ],
    );
  }
}

/// Volume row. Writes through to prefs when the drag ends, not on every tick.
class _VolumeControl extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onSaved;

  const _VolumeControl({
    required this.volume,
    required this.onChanged,
    required this.onSaved,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          volume <= 0 ? Symbols.volume_off_rounded : Symbols.volume_up_rounded,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
        Expanded(
          child: Slider(
            value: volume.clamp(0, 100),
            max: 100,
            onChanged: onChanged,
            onChangeEnd: onSaved,
          ),
        ),
      ],
    );
  }
}
