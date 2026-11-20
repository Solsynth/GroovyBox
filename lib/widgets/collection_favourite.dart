import 'package:easy_localization/easy_localization.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';

import '../library/models.dart';
import '../library/providers.dart';
import '../pulsar/models.dart';
import '../pulsar/providers.dart';
import 'common.dart';

/// The heart on an album or a playlist page.
///
/// The same rule as a track's heart: the device writes first, so the button
/// never flickers and works with no account, and the fleet copy follows when
/// signed in. The two are read back through two providers — the account's
/// list when signed in, the device's row when signed out — because a heart set
/// on another device is the answer the user expects to see here.
///
/// It is a button in the hero's action row rather than page chrome: what it
/// says is about the collection the hero names, so it belongs beside Play.
class CollectionFavouriteButton extends ConsumerStatefulWidget {
  /// The album or playlist this button hearts.
  final CollectionFavourite favourite;

  const CollectionFavouriteButton({super.key, required this.favourite});

  @override
  ConsumerState<CollectionFavouriteButton> createState() =>
      _CollectionFavouriteButtonState();
}

class _CollectionFavouriteButtonState
    extends ConsumerState<CollectionFavouriteButton> {
  bool _busy = false;

  CollectionFavourite get _favourite => widget.favourite;

  CollectionFavouriteKey get _key => _favourite.key;

  bool get _signedIn =>
      ref.watch(pulsarSessionProvider.select((s) => s.value != null));

  Future<void> _toggle() async {
    if (_busy) return;
    final value = !(ref.read(collectionFavouriteStateProvider(_key)).value ??
        false);
    setState(() => _busy = true);
    Object? fleetError;
    try {
      await ref.read(collectionFavouritesProvider).set(_favourite, value: value);
      // Pushed here, not in the device's record: this is the layer allowed to
      // know about Pulsar. A fleet that is down must not undo the tap — the
      // device already agrees with the user.
      if (_signedIn) {
        try {
          await ref
              .read(pulsarFavouritesProvider.notifier)
              .setCollection(_favourite, value: value);
        } catch (error) {
          fleetError = error;
        }
      }
      ref
        ..invalidate(collectionFavouriteStateProvider(_key))
        ..invalidate(deviceCollectionFavouriteStateProvider(_key))
        ..invalidate(solarCollectionFavouritesProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (fleetError != null && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(describeServerError(fleetError))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final favourited = ref.watch(collectionFavouriteStateProvider(_key)).value;
    final filled = favourited ?? false;
    return IconButton.filledTonal(
      tooltip: filled ? 'collectionFavourited'.tr() : 'collectionFavourite'.tr(),
      isSelected: filled,
      onPressed: _busy ? null : _toggle,
      // The account has not answered yet: drawing an outline says "not a
      // favourite", which may be wrong. A disabled button says "asking".
      icon: Icon(
        filled ? Symbols.favorite_rounded : Symbols.favorite_border_rounded,
      ),
    );
  }
}

/// The payload for a library album, as the button and the sync spell it.
CollectionFavourite albumFavourite(
  LibraryAlbum album, {
  String? artId,
  String? artworkUrl,
}) => CollectionFavourite(
  kind: FavouriteKind.album,
  sourceId: album.sourceId,
  id: album.id,
  name: album.name,
  subtitle: album.artist,
  artId: artId ?? album.artId,
  artworkUrl: artworkUrl,
  decidedAt: DateTime.now(),
);

/// The payload for a server playlist.
CollectionFavourite serverPlaylistFavourite(
  LibraryPlaylist playlist, {
  String? artId,
}) => CollectionFavourite(
  kind: FavouriteKind.playlist,
  sourceId: playlist.sourceId,
  id: playlist.id,
  name: playlist.name,
  subtitle: playlist.owner,
  artId: artId ?? playlist.artId,
  decidedAt: DateTime.now(),
);

/// The payload for a Solink playlist: a list no library stands behind.
CollectionFavourite solinkPlaylistFavourite(
  PulsarPlaylist playlist, {
  String? cover,
}) => CollectionFavourite(
  kind: FavouriteKind.playlist,
  sourceId: kSolinkSourceId,
  id: playlist.id,
  name: playlist.name,
  subtitle: playlist.description,
  artworkUrl: cover ?? playlist.artworkUrl,
  decidedAt: DateTime.now(),
);
