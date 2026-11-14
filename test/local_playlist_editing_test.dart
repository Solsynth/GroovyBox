import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/catalog.dart';
import 'package:groovy_box/library/models.dart';

void main() {
  test('a device playlist can be renamed, edited and deleted', () async {
    final db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = LibraryCatalog(db);

    const yellow = LibrarySong(
      sourceId: 'a',
      id: 's1',
      title: 'Yellow',
      artist: 'Coldplay',
      duration: Duration(seconds: 266),
    );
    const trouble = LibrarySong(
      sourceId: 'a',
      id: 's2',
      title: 'Trouble',
      artist: 'Coldplay',
      duration: Duration(seconds: 273),
    );

    final playlist = await catalog.createPlaylist('Sunday');
    await catalog.addToOwnedPlaylist(playlist.id, [yellow, trouble]);

    // Entries carry the id a removal names, in the order they were added.
    final entries = await catalog.ownedPlaylistEntryRows(playlist.id);
    expect(entries.map((e) => e.$2.title), ['Yellow', 'Trouble']);

    // Removing the first keeps the second, and the survivor keeps its rank
    // rather than being renumbered into the gap.
    await catalog.removeFromOwnedPlaylist(playlist.id, entries.first.$1);
    final afterRemove = await catalog.ownedPlaylistEntryRows(playlist.id);
    expect(afterRemove.single.$2.title, 'Trouble');
    expect((await catalog.ownedPlaylists()).single.trackCount, 1);

    await catalog.renameOwnedPlaylist(playlist.id, 'Late');
    expect((await catalog.ownedPlaylists()).single.name, 'Late');

    await catalog.deleteOwnedPlaylist(playlist.id);
    expect(await catalog.ownedPlaylists(), isEmpty);
    expect(await catalog.ownedPlaylistEntryRows(playlist.id), isEmpty);
  });
}
