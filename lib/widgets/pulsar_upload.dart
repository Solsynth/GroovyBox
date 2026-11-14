import 'package:easy_localization/easy_localization.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/pulsar/client.dart';
import 'package:groovy_box/pulsar/links.dart';
import 'package:groovy_box/pulsar/models.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/widgets/common.dart';
import 'package:groovy_box/widgets/playlist_name_dialog.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

/// Pushing a playlist that lives somewhere else into Pulsar, and keeping it
/// there afterwards.
///
/// Two directions, one flow: a device playlist or a server playlist becomes a
/// cloud playlist. The upload happens once; the sync is the same write again,
/// which is why the server's replace endpoint is the verb behind both — the
/// app's list is the truth, so running it twice is not a duplicate.
abstract final class PulsarUpload {
  /// Asks what to call the new cloud playlist, uploads [songs] into it, and
  /// returns it. Null when the user cancelled or there is no session.
  static Future<PulsarPlaylist?> upload(
    BuildContext context,
    WidgetRef ref, {
    required String localKey,
    required String suggestedName,
    required List<LibrarySong> songs,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (ref.read(pulsarSessionProvider).value == null) {
      messenger?.showSnackBar(
        SnackBar(content: Text('playerShareNeedsAccount'.tr())),
      );
      return null;
    }
    final name = await askPlaylistName(
      context,
      title: 'pulsarUploadTitle'.tr(),
      initial: suggestedName,
      confirmLabelKey: 'commonSave',
    );
    if (name == null) return null;
    if (songs.isEmpty) {
      messenger?.showSnackBar(
        SnackBar(content: Text('pulsarUploadEmpty'.tr())),
      );
      return null;
    }
    try {
      final uploaded = await ref
          .read(pulsarPlaylistsProvider.notifier)
          .upload(name, songs);
      if (uploaded == null) return null;
      // The link is what makes the next tap a sync rather than a copy.
      await ref.read(pulsarPlaylistLinksProvider).set(localKey, uploaded.id);
      messenger?.showSnackBar(
        SnackBar(
          content: Text('pulsarUploadDone'.tr(args: [name, '${songs.length}'])),
        ),
      );
      return uploaded;
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(describeServerError(error))),
      );
      return null;
    }
  }

  /// Replaces one cloud playlist's contents with [songs]. This is the sync a
  /// user runs after the source playlist changed; nothing is duplicated.
  static Future<void> sync(
    BuildContext context,
    WidgetRef ref, {
    required PulsarPlaylist playlist,
    required List<LibrarySong> songs,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (ref.read(pulsarSessionProvider).value == null) {
      messenger?.showSnackBar(
        SnackBar(content: Text('playerShareNeedsAccount'.tr())),
      );
      return;
    }
    try {
      await ref.read(pulsarPlaylistsProvider.notifier).replace(playlist, songs);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            'pulsarSyncDone'.tr(args: [playlist.name, '${songs.length}']),
          ),
        ),
      );
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(describeServerError(error))),
      );
    }
  }

  /// The songs of a device-owned playlist, for an upload.
  static Future<List<LibrarySong>> deviceSongs(
    WidgetRef ref,
    int playlistId,
  ) async {
    final catalog = ref.read(libraryCatalogProvider);
    if (catalog == null) return const [];
    return catalog.ownedPlaylistSongs(playlistId);
  }

  /// The device's favourite tracks as songs, skipping any whose sources are
  /// all gone — a fleet write cannot name a track no library holds.
  static Future<List<LibrarySong>> favouriteSongs(WidgetRef ref) async {
    final catalog = ref.read(libraryCatalogProvider);
    if (catalog == null) return const [];
    final favourites = await catalog.favourites();
    return [for (final favourite in favourites) ?favourite.song];
  }

  /// Pushes every favourite this device holds that Pulsar does not, and
  /// returns how many were new. One-way on purpose: un-hearting on another
  /// device is an opinion this device cannot see, and deleting on its behalf
  /// would lose a decision the user never made here.
  static Future<int> syncFavourites(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (ref.read(pulsarSessionProvider).value == null) {
      messenger?.showSnackBar(
        SnackBar(content: Text('playerShareNeedsAccount'.tr())),
      );
      return 0;
    }
    final songs = await favouriteSongs(ref);
    if (songs.isEmpty) return 0;
    final notifier = ref.read(pulsarFavouritesProvider.notifier);
    final existing = await ref
        .read(pulsarFavouritesProvider.future)
        .catchError((_) => const <PlaylistItem>[]);
    final known = {
      for (final item in existing)
        if (item.catalogItem?.providerKey != null)
          item.catalogItem!.providerKey!,
    };
    var pushed = 0;
    for (final song in songs) {
      if (known.contains(pulsarTrackKey(song))) continue;
      try {
        await notifier.set(song, value: true);
        pushed++;
      } catch (_) {
        // One unreachable track must not stop the rest of the taste from
        // travelling; the next sync offers it again.
      }
    }
    if (context.mounted) {
      messenger?.showSnackBar(
        SnackBar(content: Text('pulsarFavouritesSynced'.tr(args: ['$pushed']))),
      );
    }
    return pushed;
  }
}

/// The "upload to Pulsar" action for a playlist header.
///
/// One tap uploads when this playlist has never been pushed. Once it has, the
/// tap asks which of the two meanings the user wants: update the cloud copy
/// (the source changed), or make another one (a different take on the same
/// tracks). Guessing between them would either lose an edit or duplicate a
/// playlist.
class PulsarUploadButton extends ConsumerWidget {
  /// This playlist's identity on its own side: see [PulsarPlaylistLinks].
  final String localKey;
  final String suggestedName;
  final Future<List<LibrarySong>> Function(WidgetRef ref) songs;

  const PulsarUploadButton({
    super.key,
    required this.localKey,
    required this.suggestedName,
    required this.songs,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(
      pulsarSessionProvider.select((session) => session.value != null),
    );
    if (!signedIn) return const SizedBox.shrink();
    return IconButton(
      tooltip: 'pulsarUploadAction'.tr(),
      icon: const Icon(Symbols.cloud_upload_rounded),
      onPressed: () => _onPressed(context, ref),
    );
  }

  Future<void> _onPressed(BuildContext context, WidgetRef ref) async {
    final link = ref.read(pulsarPlaylistLinksProvider).of(localKey);
    final linked = link == null
        ? null
        : ref
              .read(pulsarPlaylistsProvider)
              .value
              ?.where((playlist) => playlist.id == link)
              .firstOrNull;
    final list = await songs(ref);
    if (!context.mounted) return;
    if (linked == null) {
      await PulsarUpload.upload(
        context,
        ref,
        localKey: localKey,
        suggestedName: suggestedName,
        songs: list,
      );
      return;
    }
    final choice = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Symbols.sync_rounded),
              title: Text('pulsarSyncAction'.tr()),
              subtitle: Text(
                'pulsarSyncSubtitle'.tr(args: [linked.name]),
              ),
              onTap: () => Navigator.of(sheetContext).pop(true),
            ),
            ListTile(
              leading: const Icon(Symbols.cloud_upload_rounded),
              title: Text('pulsarUploadAsNew'.tr()),
              onTap: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice) {
      await PulsarUpload.sync(context, ref, playlist: linked, songs: list);
    } else {
      await PulsarUpload.upload(
        context,
        ref,
        localKey: localKey,
        suggestedName: suggestedName,
        songs: list,
      );
    }
  }
}
