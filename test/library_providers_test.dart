import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One source whose answer can be flipped between success and failure.
class _FlakySource extends LibrarySource {
  _FlakySource(this.id);

  @override
  final String id;
  bool failing = false;

  @override
  SourceConfig get config => SourceConfig(
    id: id,
    kind: LibraryKind.subsonic,
    baseUrl: 'https://$id.example.com',
    displayName: id,
  );

  @override
  Future<List<LibraryAlbum>> recentlyAdded({int limit = 50}) async {
    if (failing) throw const LibraryException('server is down');
    return [
      LibraryAlbum(
        sourceId: id,
        id: '$id-album',
        name: 'Album from $id',
        duration: Duration.zero,
      ),
    ];
  }

  @override
  Future<List<LibrarySong>> albumSongs(String albumId) async => [
    LibrarySong(
      sourceId: id,
      id: '$albumId-song',
      title: 'Song from $id',
      duration: Duration.zero,
    ),
  ];

  /// What this library holds, as a search would answer.
  List<LibrarySong> catalogue = const [];

  @override
  Future<List<LibrarySong>> search(String query, {int limit = 40}) async {
    if (failing) throw const LibraryException('server is down');
    return [
      for (final song in catalogue)
        if ('${song.artist} ${song.title}'.toLowerCase().contains(
          query.toLowerCase().split(' ').first,
        ))
          song,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<ProviderContainer> _container(List<LibrarySource> sources) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      librarySourcesProvider.overrideWithValue(sources),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('merges across the provider graph and records failures', () async {
    final good = _FlakySource('good');
    final bad = _FlakySource('bad')..failing = true;
    final container = await _container([good, bad]);

    final albums = await container.read(recentAlbumsProvider.future);

    expect(albums.map((album) => album.sourceId), ['good']);
    expect(container.read(sourceFailuresProvider).keys, ['bad']);

    // A source that recovers drops its stale failure instead of keeping the
    // banner forever.
    bad.failing = false;
    await container.read(recentAlbumsProvider.notifier).refresh();
    expect(container.read(sourceFailuresProvider), isEmpty);
    expect(container.read(recentAlbumsProvider).value, hasLength(2));
  });

  test('no sources means an empty library, not an error', () async {
    final container = await _container(const []);
    expect(await container.read(recentAlbumsProvider.future), isEmpty);
  });

  group('lookup across libraries', () {
    const wanted = LibrarySong(
      sourceId: 'first',
      id: 'own-1',
      title: 'Yellow',
      artist: 'Coldplay',
      album: 'Parachutes',
      duration: Duration(milliseconds: 266000),
    );

    test('finds the copies other libraries hold', () async {
      final first = _FlakySource('first');
      final second = _FlakySource('second')
        ..catalogue = const [
          // The same recording, tagged differently: a bracketed remaster
          // credit and a rounded length.
          LibrarySong(
            sourceId: 'second',
            id: 'copy-1',
            title: 'Yellow (Remastered)',
            artist: 'Coldplay',
            duration: Duration(milliseconds: 267500),
          ),
          LibrarySong(
            sourceId: 'second',
            id: 'other',
            title: 'Clocks',
            artist: 'Coldplay',
            duration: Duration(milliseconds: 307000),
          ),
        ];
      final container = await _container([first, second]);

      final copies = await container.read(
        songCopiesProvider(const TrackLookup(wanted)).future,
      );

      expect(copies.map((copy) => copy.sourceId), ['first', 'second']);
      expect(copies.last.externalId, 'copy-1');
      expect(copies.every((copy) => copy.playable), isTrue);
      // One entry per library, not one per sighting.
      expect(copies, hasLength(2));
    });

    test('a library without the track contributes nothing', () async {
      final first = _FlakySource('first');
      final second = _FlakySource('second')
        ..catalogue = const [
          LibrarySong(
            sourceId: 'second',
            id: 'other',
            title: 'Clocks',
            artist: 'Coldplay',
            duration: Duration(milliseconds: 307000),
          ),
        ];
      final container = await _container([first, second]);

      final copies = await container.read(
        songCopiesProvider(const TrackLookup(wanted)).future,
      );

      expect(copies.map((copy) => copy.sourceId), ['first']);
    });

    test('a library that cannot be asked still answers the others', () async {
      final first = _FlakySource('first');
      final down = _FlakySource('down')..failing = true;
      final second = _FlakySource('second')
        ..catalogue = const [
          LibrarySong(
            sourceId: 'second',
            id: 'copy-1',
            title: 'Yellow',
            artist: 'Coldplay',
            duration: Duration(milliseconds: 266000),
          ),
        ];
      final container = await _container([first, down, second]);

      final copies = await container.read(
        songCopiesProvider(const TrackLookup(wanted)).future,
      );

      expect(copies.map((copy) => copy.sourceId), ['first', 'second']);
    });
  });

  test('an album is read from its own source only', () async {
    final first = _FlakySource('first');
    final second = _FlakySource('second');
    final container = await _container([first, second]);

    final songs = await container.read(
      albumSongsProvider((sourceId: 'second', id: 'second-album')).future,
    );

    // Only the owning source is asked: no fan-out, so one album never pulls
    // the same id from every other library.
    expect(songs.single.sourceId, 'second');
    expect(songs.single.id, 'second-album-song');
  });
}
