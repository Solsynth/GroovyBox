import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/glass.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/router.gr.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/shell/dock_morph.dart';
import 'package:groovy_box/widgets/artwork.dart';
import 'package:groovy_box/widgets/format.dart';
import 'package:groovy_box/widgets/lyrics_view.dart';
import 'package:groovy_box/widgets/queue_panel.dart';
import 'package:groovy_box/widgets/transport.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The persistent transport strip under every tab.
///
/// It floats over the page as a glass capsule rather than occupying a band, so
/// the content keeps scrolling underneath and the glass has something to
/// refract.
///
/// The whole capsule is one target. It is the collapsed player, so tapping
/// anywhere that is not a control grows it into the full player page
/// ([DockMorphOrigin]) instead of pushing a page over it. The transport buttons
/// and the wide layout's scrubber win their own gestures, so playing and
/// seeking still work without leaving the page.
///
/// The lyrics button lifts the capsule into a lyric sheet: the transport row
/// stays put and the timed lines rise above it, following the song the way the
/// player page's lyrics do. It is a second tap to go back, not a route, so a
/// glance at the next line never costs the page underneath.
///
/// The queue button does the same for what is coming up: the sheet lists the
/// queue and a row seeks to it, all without leaving the page. Only one of the
/// two sheets is open at a time — they occupy the same space above the
/// transport, and stacking them would push the tab capsule off a short window.
///
/// Nothing of it appears or vanishes between frames. The capsule rises from
/// behind the tab pill when a song starts and folds back when the last one
/// ends, and each sheet unrolls out of the transport row and retracts into it
/// on the same curve — both driven by their own controller, so a closing
/// panel has time to fade rather than disappearing a beat before the glass
/// around it collapses.
class NowPlayingDock extends ConsumerStatefulWidget {
  const NowPlayingDock({super.key});

  @override
  ConsumerState<NowPlayingDock> createState() => _NowPlayingDockState();
}

class _NowPlayingDockState extends ConsumerState<NowPlayingDock>
    with TickerProviderStateMixin {
  /// The capsule's own box, measured at tap time so the player can start the
  /// morph from exactly where the capsule was.
  final _capsuleKey = GlobalKey();

  /// Which sheet, if any, is asked to be lifted above the transport row. One
  /// at a time: both take the same space, and two of them would push the tab
  /// capsule off the bottom of a short phone.
  _DockSheet _openSheet = _DockSheet.none;

  /// The sheet whose panel is still on screen.
  ///
  /// [_openSheet] flips the moment its button is tapped; this one only
  /// follows once the fall has finished, so a closing panel stays mounted to
  /// fade out of instead of vanishing a beat before the glass collapses.
  _DockSheet _shownSheet = _DockSheet.none;

  /// The song the capsule is dressed in, held while the dock folds away.
  ///
  /// Playback reports no current song the instant the last one ends; the
  /// artwork should fade with the capsule rather than be deleted from it.
  LibrarySong? _shownSong;

  /// The capsule's own rise and fall, kept off the sheets' timeline: a song
  /// can end while a sheet is open, and the two motions must not fight.
  late final AnimationController _dock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 260),
  );

  /// Every sheet's rise and fall. The slot's height and the panel's opacity
  /// both read its curve, so a panel unrolls out of the transport row on the
  /// way in and retracts into it on the way out.
  late final AnimationController _sheet = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 260),
  );

  late final Animation<double> _dockCurve = CurvedAnimation(
    parent: _dock,
    curve: Curves.easeOutCubic,
  );

  late final Animation<double> _sheetCurve = CurvedAnimation(
    parent: _sheet,
    curve: Curves.easeOutCubic,
  );

  /// Set while a narrow window has asked the open panel to leave, so the
  /// request is scheduled once rather than by every rebuild of the fall.
  bool _closingForWidth = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The sheet controls live only where there is room for the panel. A
    // window that shrinks under an open sheet would otherwise leave it lifted
    // with nothing to fold it back, so the shrink closes it. Closing is a
    // setState, which cannot run mid-build; it waits for the frame.
    if (isWideScreen(context) || _openSheet == _DockSheet.none) {
      _closingForWidth = false;
      return;
    }
    if (_closingForWidth) return;
    _closingForWidth = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _closingForWidth = false;
      final sheet = _openSheet;
      if (sheet != _DockSheet.none) _toggleSheet(sheet);
    });
  }

  @override
  void initState() {
    super.initState();
    _shownSong = ref.read(playbackProvider).current;
    if (_shownSong != null) _dock.forward();
  }

  @override
  void dispose() {
    _dock.dispose();
    _sheet.dispose();
    super.dispose();
  }

  bool get _lyricsOpen => _openSheet == _DockSheet.lyrics;
  bool get _queueOpen => _openSheet == _DockSheet.queue;

  /// Folds the capsule away, unless a song arriving during the fold turns it
  /// back into a rise.
  Future<void> _foldDock() async {
    await _dock.reverse();
    if (!mounted || _dock.value > 0) return;
    setState(() => _shownSong = null);
  }

  Future<void> _toggleSheet(_DockSheet sheet) async {
    if (_openSheet != sheet) {
      setState(() {
        _openSheet = sheet;
        _shownSheet = sheet;
      });
      await _sheet.forward();
      return;
    }
    setState(() => _openSheet = _DockSheet.none);
    await _sheet.reverse();
    // A tap during the fall reopened a panel; only the sheet that actually
    // finished leaving stops being shown.
    if (!mounted || _sheet.value > 0) return;
    setState(() => _shownSheet = _DockSheet.none);
  }

  /// Height the lyric sheet asks for, capped to a share of the window so the
  /// transport row and the tab capsule still fit on a short window.
  double _sheetHeight() {
    return 300.0.clamp(0.0, MediaQuery.sizeOf(context).height * 0.34);
  }

  /// The queue needs more room than the words: it is a list, and three rows
  /// are the fewest that show a song, the one playing, and what follows.
  double _queueSheetHeight() {
    return 380.0.clamp(0.0, MediaQuery.sizeOf(context).height * 0.46);
  }

  /// The slot a sheet grows out of and retracts into: nothing when no sheet
  /// is shown, the open panel's height plus its trailing gap otherwise.
  ///
  /// Height and opacity ride the same curve, so closing is the opening
  /// reversed — the panel folds back into the transport row as it fades —
  /// rather than a size shrinking around content already gone. The gap is
  /// part of the slot, so tone and space (never a rule) still separate the
  /// panel from the transport at every point of the motion.
  Widget _sheetSlot() {
    final height = switch (_shownSheet) {
      _DockSheet.lyrics => _sheetHeight(),
      _DockSheet.queue => _queueSheetHeight(),
      _DockSheet.none => 0.0,
    };
    final gap = switch (_shownSheet) {
      _DockSheet.lyrics => SolSpace.md,
      _DockSheet.queue => SolSpace.xs,
      _DockSheet.none => 0.0,
    };
    return SizeTransition(
      sizeFactor: _sheetCurve,
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        height: height + gap,
        child: Padding(
          padding: EdgeInsets.only(bottom: gap),
          child: FadeTransition(
            opacity: _sheetCurve,
            child: switch (_shownSheet) {
              // Each sheet owns its taps: a lyric line seeks, a queue row
              // plays, and a tap on the space beside them must not morph
              // the dock.
              _DockSheet.lyrics => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: SongLyricsPane(
                  height: _sheetHeight(),
                  padding: const EdgeInsets.symmetric(horizontal: SolSpace.md),
                ),
              ),
              _DockSheet.queue => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: SizedBox(
                  height: _queueSheetHeight(),
                  child: const QueuePanel(),
                ),
              ),
              _DockSheet.none => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }

  void _openPlayer() {
    final box = _capsuleKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize) {
      DockMorphOrigin.rect = box.localToGlobal(Offset.zero) & box.size;
    }
    context.router.push(const PlayerRoute());
  }

  @override
  Widget build(BuildContext context) {
    // The dock is the one widget that *should* repaint every tick, so it
    // watches the whole transport. Nothing above it does.
    final playback = ref.watch(playbackProvider);
    // The capsule holds the last song while it folds away, the way a sheet
    // holds its panel — so which song is on show is settled here and the
    // fold itself by the controller.
    final song = playback.current ?? _shownSong;
    ref.listen(playbackProvider.select((state) => state.current), (_, next) {
      if (next == null) {
        _foldDock();
      } else {
        setState(() => _shownSong = next);
        _dock.forward();
      }
    });

    final controller = ref.read(playbackProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final wide = isWideScreen(context);
    final duration = playback.duration != Duration.zero
        ? playback.duration
        : song?.duration ?? Duration.zero;
    final maxMs = duration.inMilliseconds.toDouble();
    final positionMs = playback.position.inMilliseconds
        .clamp(0, duration.inMilliseconds)
        .toDouble();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kChromeGutter),
      child: MouseRegion(
        cursor: song == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: song == null ? null : _openPlayer,
          // The capsule rises from behind the tab pill when a song starts
          // and folds back into it when the last one ends.
          child: AnimatedBuilder(
            animation: _dockCurve,
            builder: (context, capsule) => ClipRect(
              // Unclipped, so the glass keeps its shadow at rest; whatever
              // hangs below while it moves paints behind the tab pill,
              // which is where it came from.
              clipBehavior: Clip.none,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                heightFactor: _dockCurve.value,
                child: capsule,
              ),
            ),
            child: song == null
                ? const SizedBox.shrink()
                : FadeTransition(
                    opacity: _dockCurve,
                    child: AnimatedBuilder(
                      animation: _sheetCurve,
                      builder: (context, capsule) => GlassSurface(
                        key: _capsuleKey,
                        // A capsule while no sheet has given it height, a
                        // card once one has, where a pill's ends would eat
                        // the first and last row. Lerp on the sheet's own
                        // curve so the ends change shape with the panel
                        // rather than popping under it.
                        cornerRadius:
                            SolRadius.pill +
                            (SolRadius.xxl - SolRadius.pill) *
                                _sheetCurve.value,
                        // Leading inset matches the artwork's own corner, so
                        // the cover sits square in the capsule's left end. A
                        // sheet keeps the same padding: its own list has the
                        // inner inset instead, and changing this box is what
                        // the morph would read as movement.
                        padding: const EdgeInsets.fromLTRB(
                          SolSpace.sm,
                          0,
                          SolSpace.md,
                          0,
                        ),
                        child: capsule!,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _sheetSlot(),
                          SizedBox(
                            height: kNowPlayingDockHeight,
                            child: Row(
                              children: [
                                LibraryArtwork(
                                  sourceId: song.sourceId,
                                  artId: song.artId,
                                  size: 44,
                                  radius: SolRadius.pill,
                                ),
                                const SizedBox(width: SolSpace.md),
                                Expanded(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: wide ? 260 : double.infinity,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          song.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                        Text(
                                          switch (_shownSheet) {
                                            _DockSheet.lyrics => 'lyricsTitle'
                                                .tr(),
                                            _DockSheet.queue => queueSummary(
                                              playback.queue.length,
                                              playback.shuffle,
                                            ),
                                            _DockSheet.none => wide
                                                ? song.subtitle
                                                : 'formatPositionOfDuration'
                                                      .tr(
                                                        args: [
                                                          formatDuration(
                                                            playback.position,
                                                          ),
                                                          formatDuration(
                                                            duration,
                                                          ),
                                                        ],
                                                      ),
                                          },
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (wide) ...[
                                  const SizedBox(width: SolSpace.md),
                                  Text(
                                    formatDuration(playback.position),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: positionMs,
                                      max: maxMs <= 0 ? 1 : maxMs,
                                      onChanged: maxMs <= 0
                                          ? null
                                          : (value) => controller.seek(
                                              Duration(
                                                milliseconds: value.round(),
                                              ),
                                            ),
                                    ),
                                  ),
                                  Text(
                                    formatDuration(duration),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: SolSpace.sm),
                                ],
                                // The controls own their taps, including a
                                // disabled button (a disabled control is still
                                // a control, not a way into the player).
                                // Without this, a disabled Next would fall
                                // through to the capsule's morph.
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {},
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // The panels take more room than a phone
                                      // has: with the transport, the tab pill
                                      // and the safe area there is no height
                                      // left for a sheet, so the two ways into
                                      // them exist only on a wide window.
                                      if (wide) ...[
                                        IconButton(
                                          tooltip: _queueOpen
                                              ? 'playerQueueHide'.tr()
                                              : 'playerQueueShow'.tr(),
                                          visualDensity: VisualDensity.compact,
                                          isSelected: _queueOpen,
                                          onPressed: () =>
                                              _toggleSheet(_DockSheet.queue),
                                          icon: const Icon(
                                            Symbols.queue_music_rounded,
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: _lyricsOpen
                                              ? 'playerLyricsHide'.tr()
                                              : 'playerLyricsShow'.tr(),
                                          visualDensity: VisualDensity.compact,
                                          isSelected: _lyricsOpen,
                                          onPressed: () =>
                                              _toggleSheet(_DockSheet.lyrics),
                                          icon: const Icon(
                                            Symbols.lyrics_rounded,
                                          ),
                                        ),
                                      ],
                                      IconButton(
                                        tooltip: 'playerPrevious'.tr(),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: controller.previous,
                                        icon: const Icon(
                                          Symbols.skip_previous_rounded,
                                        ),
                                      ),
                                      IconButton.filled(
                                        tooltip: playback.playing
                                            ? 'playerPause'.tr()
                                            : 'playerPlay'.tr(),
                                        onPressed: controller.togglePlayPause,
                                        icon: PlayPauseIcon(
                                          playing: playback.playing,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'playerNext'.tr(),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: playback.hasNext
                                            ? controller.next
                                            : null,
                                        icon: const Icon(
                                          Symbols.skip_next_rounded,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Which sheet the dock is lifted into, if any.
enum _DockSheet { none, lyrics, queue }
