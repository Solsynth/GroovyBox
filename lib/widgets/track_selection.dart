import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Which rows of one playlist are ticked, and whether ticking is on at all.
///
/// The state lives outside the rows because a batch acts on all of them at
/// once: the hero's action row and every checkbox read the same set, and a
/// page rebuild after a removal cannot leave a tick behind. Keys are the
/// page's own identity for a row (an entry id, a cloud item id, a catalog
/// id), never an index: positions shift, ids do not.
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

/// The hero action row while a playlist is being edited in bulk.
///
/// Same slot as play, shuffle and the edit buttons, because it is the same
/// question: what happens to this collection. Selection is a mode, so it
/// replaces those actions rather than crowding beside them, and the way out
/// is always visible.
class SelectionActions extends StatelessWidget {
  final TrackSelection selection;

  /// Every selectable row's key, for the select-all toggle.
  final List<String> keys;
  final VoidCallback? onPlay;
  final VoidCallback? onRemove;

  const SelectionActions({
    super.key,
    required this.selection,
    required this.keys,
    this.onPlay,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allTicked =
        keys.isNotEmpty &&
        selection.count == keys.length &&
        keys.every(selection.contains);
    return Wrap(
      spacing: SolSpace.sm,
      runSpacing: SolSpace.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'playlistSelectionCount'.plural(selection.count),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton.filledTonal(
          tooltip: (allTicked ? 'playlistSelectNone' : 'playlistSelectAll')
              .tr(),
          onPressed: keys.isEmpty ? null : () => selection.toggleAll(keys),
          icon: Icon(
            allTicked
                ? Symbols.check_box_rounded
                : Symbols.check_box_outline_blank_rounded,
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'playlistSelectionPlay'.tr(),
          onPressed: selection.isEmpty ? null : onPlay,
          icon: const Icon(Symbols.play_arrow_rounded),
        ),
        IconButton(
          tooltip: 'playlistSelectionRemove'.tr(),
          onPressed: selection.isEmpty ? null : onRemove,
          color: theme.colorScheme.error,
          icon: const Icon(Symbols.delete_rounded),
        ),
        TextButton(
          onPressed: selection.end,
          child: Text('playlistSelectionDone'.tr()),
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

/// The tick a row shows while selection is on: a button, so the row can keep
/// its own tap and a screen reader still gets a real control.
class SelectionCheckbox extends StatelessWidget {
  final TrackSelection selection;
  final String rowKey;

  const SelectionCheckbox({
    super.key,
    required this.selection,
    required this.rowKey,
  });

  @override
  Widget build(BuildContext context) {
    final ticked = selection.contains(rowKey);
    return IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: 'playlistSelectionToggle'.tr(),
      isSelected: ticked,
      onPressed: () => selection.toggle(rowKey),
      icon: const Icon(Symbols.check_box_outline_blank_rounded),
      selectedIcon: Icon(
        Symbols.check_box_rounded,
        color: Theme.of(context).colorScheme.primary,
      ),
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
