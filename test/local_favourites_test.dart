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
}
