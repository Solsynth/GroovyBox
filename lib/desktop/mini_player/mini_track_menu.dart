import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/desktop/mini_player/link.dart';
import 'package:groovy_box/desktop/mini_player/mini_actions.dart';
import 'package:groovy_box/library/models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// The track's menu in the mini player's transport row.
///
/// The mini window is the one surface in the app with no page behind it, so
/// the track's writes have to be reachable from the window itself. They are
/// the host's to perform — the guest holds neither the database nor the
/// account — so each item is a command across the link, and the sheet below is
/// filled from the host's own list of destinations.
class MiniTrackMenuButton extends ConsumerWidget {
  final LibrarySong song;

  const MiniTrackMenuButton({super.key, required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return MenuAnchor(
      animated: true,
      // The menu opens upward: the button sits at the bottom of the window,
      // and a menu below it would be the one place there is no room.
      alignmentOffset: const Offset(0, -320),
      builder: (context, controller, child) => IconButton(
        tooltip: 'playerMore'.tr(),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        color: theme.colorScheme.onSurfaceVariant,
        iconSize: 20,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        icon: const Icon(Symbols.more_horiz_rounded),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Symbols.playlist_add_rounded),
          // The menu closes before this runs, so the sheet is opened on the
          // anchor's own context — still mounted — rather than this item's,
          // whose element is deactivated the frame the menu closes.
          onPressed: () => _openPlaylistSheet(context, ref, song),
          child: Text('playerAddToPlaylist'.tr()),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Symbols.ios_share_rounded),
          onPressed: () => _share(context, ref, song),
          child: Text('playerShare'.tr()),
        ),
      ],
    );
  }

  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    LibrarySong song,
  ) async {
    final error = await ref.read(miniActionsProvider).share(song);
    if (error == null || !context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(error)));
  }
}

/// Asks the host where the track can go, then adds it there.
///
/// A sheet rather than a submenu: the destinations come from three different
/// owners — the device, the account, the connected libraries — and a menu tall
/// enough for all of them does not fit this window. The list is the host's,
/// fetched on open, so a playlist made on the player page a second ago is
/// already here.
Future<void> _openPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  LibrarySong song,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    builder: (_) => _MiniPlaylistSheet(song: song),
  );
}

class _MiniPlaylistSheet extends ConsumerStatefulWidget {
  final LibrarySong song;

  const _MiniPlaylistSheet({required this.song});

  @override
  ConsumerState<_MiniPlaylistSheet> createState() => _MiniPlaylistSheetState();
}

class _MiniPlaylistSheetState extends ConsumerState<_MiniPlaylistSheet> {
  List<MiniPlaylistTarget>? _targets;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final targets = await ref
        .read(miniActionsProvider)
        .playlistTargets(widget.song);
    if (!mounted) return;
    setState(() => _targets = targets);
  }

  /// Writes the track into [target] and closes the sheet.
  Future<void> _add(MiniPlaylistTarget target) async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await ref
        .read(miniActionsProvider)
        .addToPlaylist(target, widget.song);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop();
    // Said on the window the tap came from: the sheet is gone by now, so the
    // confirmation is what proves the write landed.
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('playerPlaylistAdded'.tr(args: [target.name]))),
    );
  }

  /// Names, creates and adds in one go: a fresh playlist with one track in it
  /// is the common case for a mini player.
  Future<void> _createThenAdd() async {
    final name = await askMiniPlaylistName(context);
    if (name == null || !mounted) return;
    setState(() => _busy = true);
    final target = await ref.read(miniActionsProvider).createPlaylist(name);
    if (!mounted) return;
    setState(() => _busy = false);
    if (target == null) {
      setState(() => _error = 'commonLibraryUnreachable'.tr());
      return;
    }
    await _add(target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targets = _targets;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SolSpace.md,
              SolSpace.xs,
              SolSpace.md,
              SolSpace.sm,
            ),
            child: Text(
              'playlistPickerTitle'.tr(),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SolSpace.md,
                SolSpace.xs,
                SolSpace.md,
                SolSpace.sm,
              ),
              child: Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ListTile(
            enabled: !_busy,
            leading: Icon(
              Symbols.add_rounded,
              color: theme.colorScheme.primary,
            ),
            title: Text('playlistPickerNew'.tr()),
            onTap: _busy ? null : _createThenAdd,
          ),
          if (targets == null)
            const Padding(
              padding: EdgeInsets.all(SolSpace.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (targets.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SolSpace.md,
                SolSpace.xs,
                SolSpace.md,
                SolSpace.lg,
              ),
              child: Text(
                'playlistPickerEmpty'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: targets.length,
                itemBuilder: (context, index) {
                  final target = targets[index];
                  return ListTile(
                    enabled: !_busy,
                    leading: Icon(
                      _iconOf(target.owner),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(target.name),
                    subtitle: target.trackCount == 0
                        ? null
                        : Text('playlistsTrackCount'.plural(target.trackCount)),
                    onTap: _busy ? null : () => _add(target),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// The destination's owner, as its row's icon: a device playlist lives on
  /// this device, the account's in the cloud, a library's on that server.
  IconData _iconOf(String owner) => switch (owner) {
    'device' => Symbols.queue_music_rounded,
    'cloud' => Symbols.cloud_rounded,
    _ => Symbols.dns_rounded,
  };
}

/// A playlist name, asked for before it is created.
///
/// Separate from the app's own dialog widget: the mini window's engine loads
/// no routes, and this dialog is the only text input the window ever shows.
Future<String?> askMiniPlaylistName(BuildContext context) async {
  final controller = TextEditingController();
  final answer = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('playlistPickerNewTitle'.tr()),
      content: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: 'playlistPickerNewLabel'.tr()),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('commonCancel'.tr()),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: Text('commonSave'.tr()),
        ),
      ],
    ),
  );
  controller.dispose();
  final trimmed = answer?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
