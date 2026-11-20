import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';

void main() {
  test('the device owns the favourite, and playlists it made', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = LibraryCatalog(db);

    const song = LibrarySong(
      sourceId: 'a',
      id: 's1',
      title: 'Yellow',
      artist: 'Coldplay',
      duration: Duration(seconds: 266),
    );

    expect(await catalog.favouriteOf(song), isNull);
    await catalog.setFavourite(song, value: true);
    expect(await catalog.favouriteOf(song), isTrue);

    // A copy of the same track from another library is the same favourite:
    // the record is keyed by the canonical track, not by the source id.
    const other = LibrarySong(
      sourceId: 'b',
      id: 'x9',
      title: 'Yellow',
      artist: 'Coldplay',
      duration: Duration(seconds: 266),
    );
    expect(await catalog.favouriteOf(other), isTrue);

    // A device playlist exists with no server in sight.
    final playlist = await catalog.createPlaylist('Sunday');
    await catalog.addToOwnedPlaylist(playlist.id, [song]);
    expect((await catalog.ownedPlaylists()).single.name, 'Sunday');
    expect((await catalog.ownedPlaylists()).single.trackCount, 1);
    expect((await catalog.ownedPlaylistSongs(playlist.id)).single.title, 'Yellow');
    expect((await catalog.favourites()).single.track.title, 'Yellow');

    await catalog.setFavourite(song, value: false);
    expect(await catalog.favouriteOf(song), isFalse);
    expect(await catalog.favourites(), isEmpty);
  });

  test('the device remembers albums and playlists apart from tracks', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = LibraryCatalog(db);

    final album = CollectionFavourite(
      kind: FavouriteKind.album,
      sourceId: 'apple-1',
      id: 'l.1',
      name: 'Bronco',
      subtitle: 'Orville Peck',
      artId: 'https://x/{w}x{h}bb.jpg',
      decidedAt: DateTime.now(),
    );
    final playlist = CollectionFavourite(
      kind: FavouriteKind.playlist,
      sourceId: kSolinkSourceId,
      id: 'p.1',
      name: 'A-team',
      decidedAt: DateTime.now(),
    );

    expect(await catalog.collectionFavouriteOf(album.key), isNull);
    await catalog.setCollectionFavourite(album, value: true);
    await catalog.setCollectionFavourite(playlist, value: true);

    // The kind is part of the identity: an album and a playlist that happen
    // to share a string id are two opinions, not one.
    expect(await catalog.collectionFavouriteOf(album.key), isTrue);
    expect(await catalog.collectionFavouriteOf(playlist.key), isTrue);
    expect(
      await catalog.collectionFavouriteOf((
        kind: FavouriteKind.track,
        sourceId: 'apple-1',
        id: 'l.1',
      )),
      isNull,
    );
    // Read back with what a row needs to draw itself, with no library asked.
    final stored = await catalog.collectionFavourites();
    expect(stored, hasLength(2));
    final storedAlbum = stored.firstWhere(
      (row) => row.kind == FavouriteKind.album,
    );
    expect(storedAlbum.name, 'Bronco');
    expect(storedAlbum.subtitle, 'Orville Peck');
    expect(storedAlbum.artId, contains('{w}'));

    // Clearing removes the row rather than writing "not a favourite".
    await catalog.setCollectionFavourite(album, value: false);
    expect(await catalog.collectionFavouriteOf(album.key), isNull);
    expect(await catalog.collectionFavourites(), hasLength(1));
  });
}
