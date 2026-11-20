import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/scheduler.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/lyrics.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/widgets/lyric_widgets.dart';
import 'package:groovy_box/widgets/lyrics_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

export 'lyric_widgets.dart';

/// The lyrics of the song the transport is on, driven by an isolated 60/120Hz
/// [ValueNotifier<Duration>] so position updates never rebuild the pane or
/// inactive rows.
class SongLyricsPane extends ConsumerStatefulWidget {
  /// Height the pane fills, or null to take the space its parent gives it.
  /// The dock sizes the sheet itself; the player page gives it the column.
  final double? height;
  final EdgeInsets padding;

  /// Whether to fade the column's edges.
  final bool fade;

  const SongLyricsPane({
    super.key,
    this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: SolSpace.xl),
    this.fade = true,
  });

  @override
  ConsumerState<SongLyricsPane> createState() => _SongLyricsPaneState();
}

class _SongLyricsPaneState extends ConsumerState<SongLyricsPane>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<Duration> _positionNotifier;
  late final Ticker _clockTicker;

  Duration _anchorPosition = Duration.zero;
  Duration? _anchorElapsed;
  Duration _trackDuration = Duration.zero;
  bool _playing = false;
  bool _buffering = false;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(playbackProvider);
    _anchorPosition = initial.position;
    _trackDuration = _resolveDuration(initial);
    _playing = initial.playing;
    _buffering = initial.buffering;
    _positionNotifier = ValueNotifier<Duration>(initial.position);
    _clockTicker = createTicker(_onClockTick);
    _syncClock();
  }

  Duration _resolveDuration(PlaybackState state) =>
      state.duration > Duration.zero
      ? state.duration
      : (state.current?.duration ?? Duration.zero);

  void _syncClock() {
    final shouldTick = _playing && !_buffering;
    if (shouldTick) {
      if (!_clockTicker.isActive) {
        _anchorElapsed = null;
        _clockTicker.start();
      }
    } else if (_clockTicker.isActive) {
      _clockTicker.stop();
      _anchorElapsed = null;
    }
  }

  void _onClockTick(Duration elapsed) {
    if (_anchorElapsed == null) {
      _anchorElapsed = elapsed;
      return;
    }
    var next = _anchorPosition + (elapsed - _anchorElapsed!);
    if (_trackDuration > Duration.zero && next > _trackDuration) {
      next = _trackDuration;
    }
    if (next < Duration.zero) next = Duration.zero;
    _positionNotifier.value = next;
  }

  void _onPositionUpdate(Duration reported) {
    final current = _positionNotifier.value;
    final delta = reported - current;
    // Ignore tiny backward jitter from audio-engine polling or mini-player IPC
    // while actively playing so the karaoke sweep never stutters backward.
    if (_playing &&
        !_buffering &&
        delta < Duration.zero &&
        delta > const Duration(milliseconds: -250)) {
      return;
    }
    _anchorPosition = reported;
    _anchorElapsed = null;
    _positionNotifier.value = reported;
  }

  @override
  void dispose() {
    _clockTicker.dispose();
    _positionNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to position via ref.listen so audio ticks never rebuild this
    // widget tree; only the active lyric/interlude item listens to
    // _positionNotifier.
    ref.listen<Duration>(
      playbackProvider.select((state) => state.position),
      (_, next) => _onPositionUpdate(next),
    );
    ref.listen<(bool, bool, Duration)>(
      playbackProvider.select(
        (state) => (state.playing, state.buffering, _resolveDuration(state)),
      ),
      (_, next) {
        final (playing, buffering, duration) = next;
        _playing = playing;
        _buffering = buffering;
        _trackDuration = duration;
        if (!playing || buffering) {
          final pos = ref.read(playbackProvider).position;
          _anchorPosition = pos;
          _positionNotifier.value = pos;
        }
        _syncClock();
      },
    );

    final song = ref.watch(playbackProvider.select((state) => state.current));
    final duration = ref.watch(playbackProvider.select(_resolveDuration));
    final theme = Theme.of(context);

    Widget status(
      IconData? icon,
      String title, {
      String? detail,
      bool retry = false,
      bool rescue = false,
      bool skeleton = false,
    }) {
      Widget core;
      if (skeleton) {
        core = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < 8; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SolSpace.xs),
                child: Bone.text(
                  fontSize: 24,
                  width: i.isEven ? double.infinity : 160 + 40.0 * (i % 3),
                ),
              ),
          ],
        );
      } else {
        core = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: theme.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.65,
              ),
            ),
            const SizedBox(height: SolSpace.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: SolSpace.xxs),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
            ],
            if (retry || rescue) ...[
              const SizedBox(height: SolSpace.md),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: SolSpace.sm,
                runSpacing: SolSpace.xs,
                children: [
                  if (retry)
                    TextButton.icon(
                      onPressed: () => ref
                          .read(lyricsMaintenanceProvider.notifier)
                          .refresh(
                            LyricsRequest.of(song!),
                            languageCode: Localizations.localeOf(
                              context,
                            ).languageCode,
                          ),
                      icon: const Icon(Symbols.refresh_rounded, size: 18),
                      label: Text('lyricsAskAgain'.tr()),
                    ),
                  if (rescue)
                    FilledButton.tonalIcon(
                      onPressed: song == null
                          ? null
                          : () => LyricsPickerSheet.show(context, song),
                      icon: const Icon(Symbols.edit_note_rounded, size: 18),
                      label: Text('lyricsRescue'.tr()),
                    ),
                ],
              ),
            ],
          ],
        );
      }
      return SizedBox(
        height: widget.height,
        child: SingleChildScrollView(
          child: SizedBox(
            height: widget.height,
            child: Center(
              child: skeleton
                  ? Skeletonizer.zone(
                      enabled: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SolSpace.xl,
                        ),
                        child: core,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(SolSpace.xl),
                      child: core,
                    ),
            ),
          ),
        ),
      );
    }

    if (song == null) {
      return status(Symbols.lyrics_rounded, 'lyricsNothingPlaying'.tr());
    }

    final request = LyricsRequest.of(song);
    final lyrics = ref.watch(songLyricsProvider(request));
    // A separate family so the words never wait behind the translation: the
    // pane draws what `songLyrics` answered, and this fold lands later.
    final translation = ref.watch(
      songLyricsTranslationProvider(
        request,
        languageCode: Localizations.localeOf(context).languageCode,
      ),
    );
    final controller = ref.read(playbackProvider.notifier);
    final showPronunciation = ref.watch(lyricsPronunciationEnabledProvider);
    final showTranslation = ref.watch(lyricsTranslationEnabledProvider);

    return lyrics.when(
      skipLoadingOnRefresh: true,
      loading: () => status(null, 'lyricsLoading'.tr(), skeleton: true),
      error: (_, _) => status(
        Symbols.cloud_off_rounded,
        'lyricsUnavailable'.tr(),
        detail: 'lyricsUnavailableDetail'.tr(),
        retry: true,
        rescue: true,
      ),
      data: (words) {
        if (words.isEmpty) {
          return status(
            Symbols.lyrics_rounded,
            'lyricsEmpty'.tr(),
            detail: 'lyricsEmptyDetail'.tr(),
            retry: true,
            rescue: true,
          );
        }
        // The translation answers with the same words plus the layer; while it
        // is still loading — or if it failed — the words on screen are the
        // whole pane rather than a spinner over a lyric already in hand.
        final shown = translation.value ?? words;
        return SizedBox(
          height: widget.height,
          child: LyricsView(
            lyrics: shown,
            positionListenable: _positionNotifier,
            trackDuration: duration > Duration.zero ? duration : null,
            padding: widget.padding,
            fade: widget.fade,
            onSeek: shown.synced ? controller.seek : null,
            showPronunciation: showPronunciation,
            showTranslation: showTranslation,
          ),
        );
      },
    );
  }
}
