import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/glass.dart';
import 'package:groovy_box/core/responsive.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// How much room the selection bar occupies over the page, so a list can
/// scroll its last row clear of it.
const double kSelectionBarHeight = 52;

/// Which rows of one playlist are ticked, and whether ticking is on at all.
///
/// The state lives outside the rows because a batch acts on all of them at
/// once: the toolbar and every cover read the same set, and a page rebuild
/// after a removal cannot leave a tick behind. Keys are the page's own
/// identity for a row (an entry id, a cloud item id, a catalog id), never an
/// index: positions shift, ids do not.
class TrackSelection extends ChangeNotifier {
  bool _active = false;
  final Set<String> _keys = {};

  bool get active => _active;
  int get count => _keys.length;
  bool get isEmpty => _keys.isEmpty;
  bool contains(String key) => _keys.contains(key);
  Set<String> get keys => Set.unmodifiable(_keys);

  void begin() {
    if (_active) return;
    _active = true;
    notifyListeners();
  }

  void end() {
    if (!_active) return;
    _active = false;
    _keys.clear();
    notifyListeners();
  }

  void toggle(String key) {
    if (!_keys.remove(key)) _keys.add(key);
    notifyListeners();
  }

  /// Ticks every key when they are not all ticked, clears them otherwise: one
  /// control that does the only sensible thing at each state.
  void toggleAll(Iterable<String> keys) {
    final all = keys.toSet();
    if (_keys.length == all.length && _keys.containsAll(all)) {
      _keys.clear();
    } else {
      _keys
        ..clear()
        ..addAll(all);
    }
    notifyListeners();
  }
}

/// The tick, painted onto the row's own cover.
///
/// A checkbox column was the wrong shape: it took a slot the row did not have
/// before, so the whole list re-flowed on entering the mode, and it read as a
/// form. Here nothing about the row moves — the cover becomes the control.
///
/// The mode has one look: at rest every cover is muted with the app's own
/// paper, so the list itself says "these are targets now", and a tick stamps
/// the chosen ones with the brand teal and a check. Both states are drawn over
/// the artwork rather than beside it, which is what keeps a long playlist from
/// turning into a wall of ticks.
class SelectionCover extends StatelessWidget {
  final TrackSelection selection;

  /// The row's identity in [selection], not a position.
  final String rowKey;

  /// The artwork, already sized and rounded by the caller.
  final Widget child;

  /// The artwork's corner radius, so the wash clips to the same shape.
  final double radius;

  const SelectionCover({
    super.key,
    required this.selection,
    required this.rowKey,
    required this.child,
    this.radius = SolRadius.xs,
  });

  @override
  Widget build(BuildContext context) {
    if (!selection.active) return child;
    final scheme = Theme.of(context).colorScheme;
    final ticked = selection.contains(rowKey);
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    return Semantics(
      button: true,
      selected: ticked,
      label: 'playlistSelectionToggle'.tr(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => selection.toggle(rowKey),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = constraints.biggest.shortestSide;
            final iconSize = side.isFinite
                ? (side * 0.44).clamp(14.0, 30.0)
                : 22.0;
            return Stack(
              fit: StackFit.passthrough,
              children: [
                child,
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: AnimatedContainer(
                      duration: motion,
                      curve: Curves.easeOutCubic,
                      color: ticked
                          ? scheme.primary.withValues(alpha: 0.46)
                          : scheme.surface.withValues(alpha: 0.26),
                    ),
                  ),
                ),
                if (ticked)
                  Positioned.fill(
                    child: Center(
                      child: Icon(
                        Symbols.check_rounded,
                        size: iconSize,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The controls a batch needs, floating over the page rather than living in
/// the hero.
///
/// Play, shuffle, rename and delete stay where they always were: they are
/// about the collection. A batch is about the rows, so its controls are a
/// separate surface — the app's one glass pill, lifted above the now-playing
/// dock and the tab bar, and present only while the mode is on.
class SelectionToolbar extends StatelessWidget {
  final TrackSelection selection;

  /// Every selectable row's key, for the select-all toggle.
  final List<String> keys;

  final VoidCallback? onPlay;
  final VoidCallback? onAddToPlaylist;
  final VoidCallback? onDownload;
  final VoidCallback? onRemove;

  const SelectionToolbar({
    super.key,
    required this.selection,
    required this.keys,
    this.onPlay,
    this.onAddToPlaylist,
    this.onDownload,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = selection.count;
    final allTicked =
        keys.isNotEmpty &&
        count == keys.length &&
        keys.every(selection.contains);
    final enabled = count > 0;

    return PillSurface(
      margin: EdgeInsets.zero,
      radius: SolRadius.pillRadius,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SolSpace.sm,
        vertical: SolSpace.xs,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: 'playlistSelectionCount'.plural(count),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: enabled ? scheme.primaryContainer : null,
                  shape: BoxShape.circle,
                  border: enabled
                      ? null
                      : Border.all(color: scheme.outlineVariant),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: enabled
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            const SizedBox(width: SolSpace.xs),
            _BarAction(
              tooltip: (allTicked ? 'playlistSelectNone' : 'playlistSelectAll')
                  .tr(),
              icon: allTicked
                  ? Symbols.deselect_rounded
                  : Symbols.select_all_rounded,
              onPressed: keys.isEmpty ? null : () => selection.toggleAll(keys),
            ),
            if (onPlay != null)
              _BarAction(
                tooltip: 'playlistSelectionPlay'.tr(),
                icon: Symbols.play_arrow_rounded,
                onPressed: enabled ? onPlay : null,
              ),
            if (onAddToPlaylist != null)
              _BarAction(
                tooltip: 'playlistSelectionAdd'.tr(),
                icon: Symbols.playlist_add_rounded,
                onPressed: enabled ? onAddToPlaylist : null,
              ),
            if (onDownload != null)
              _BarAction(
                tooltip: 'playlistSelectionDownload'.tr(),
                icon: Symbols.download_rounded,
                onPressed: enabled ? onDownload : null,
              ),
            if (onRemove != null)
              _BarAction(
                tooltip: 'playlistSelectionRemove'.tr(),
                icon: Symbols.delete_rounded,
                color: scheme.error,
                onPressed: enabled ? onRemove : null,
              ),
            const SizedBox(width: SolSpace.xs),
            TextButton(
              onPressed: selection.end,
              child: Text('playlistSelectionDone'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

/// One control in [SelectionToolbar]: a compact target, not a 48 px button
/// with a 48 px hole around it.
class _BarAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color? color;
  final VoidCallback? onPressed;

  const _BarAction({
    required this.tooltip,
    required this.icon,
    this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: color,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// The page plus its floating selection bar.
///
/// The bar is a sibling of the scroll view in a stack, never a slot in it:
/// the page keeps its own padding, the bar keeps the app's floating chrome,
/// and the way out is on screen the whole time.
///
/// While the mode is off the bar is not built at all. Hiding it with zero
/// opacity would keep a full glass layer in the tree, sampling the page
/// behind it on every frame for something nobody can see.
class SelectionBarOverlay extends StatelessWidget {
  final TrackSelection selection;
  final Widget bar;

  /// Distance from the page's bottom edge to the bar, so it clears the
  /// now-playing dock and the tab capsule.
  final double bottom;
  final Widget child;

  const SelectionBarOverlay({
    super.key,
    required this.selection,
    required this.bar,
    required this.bottom,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (selection.active)
          Positioned(
            left: kChromeGutter,
            right: kChromeGutter,
            bottom: bottom,
            // The bar arrives with the mode, so its entrance plays once on
            // insertion rather than being kept alive to fade.
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: motion,
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Transform.translate(
                offset: Offset(0, 14 * (1 - t)),
                child: Opacity(opacity: t, child: child),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: bar,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The hero action that turns ticking on.
class SelectionToggleButton extends StatelessWidget {
  final TrackSelection selection;

  const SelectionToggleButton({super.key, required this.selection});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'playlistsSelectMode'.tr(),
      onPressed: selection.begin,
      icon: const Icon(Symbols.checklist_rounded),
    );
  }
}

/// Asks before a batch removal. One row is cheap to undo, so single removals
/// run and offer undo; a batch is many writes against a list whose order the
/// app cannot restore, so it is the one place a confirm is right.
Future<bool> confirmBatchRemove(
  BuildContext context, {
  required int count,
}) async {
  final agreed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('playlistSelectionRemoveTitle'.tr()),
      content: Text('playlistSelectionRemoveMessage'.tr(args: ['$count'])),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text('commonCancel'.tr()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text('commonRemove'.tr()),
        ),
      ],
    ),
  );
  return agreed == true;
}
