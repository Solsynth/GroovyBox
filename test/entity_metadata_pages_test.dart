import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/pulsar/metadata.dart';
import 'package:groovy_box/pulsar/providers.dart';
import 'package:groovy_box/screens/albums.dart';
import 'package:groovy_box/screens/artists.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

/// A tracklist that does not ask a library or a database.
class _StubAlbumSongs extends AlbumSongs {
  _StubAlbumSongs(this.songs);
  final List<LibrarySong> songs;
  @override
  Future<List<LibrarySong>> build(LibraryRef album) async => songs;
}

class _Source extends LibrarySource {
  @override
  final String id = 'a';

  @override
  SourceConfig get config => const SourceConfig(
    id: 'a',
    kind: LibraryKind.subsonic,
    baseUrl: 'https://a',
    displayName: 'Alpha',
  );

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

const _album = LibraryAlbum(
  sourceId: 'a',
  id: 'album-1',
  name: 'OK Computer',
  artist: 'Radiohead',
  artistId: 'artist-1',
  duration: Duration(minutes: 53),
  year: 1997,
);

const _song = LibrarySong(
  sourceId: 'a',
  id: 'song-1',
  title: 'Airbag',
  artist: 'Radiohead',
  artistId: 'artist-1',
  album: 'OK Computer',
  albumId: 'album-1',
  duration: Duration(milliseconds: 284400),
  track: 1,
  year: 1997,
);

const _artist = PulsarEntityMetadata(
  title: 'Radiohead',
  subtitle: 'group · United Kingdom',
  bio: 'Radiohead are an English rock band formed in Abingdon in 1985.',
  bioSource: 'EN Wikipedia',
  artworkUrl: 'https://coverartarchive.org/release-group/rg-1/front-500',
  artist: PulsarArtistProfile(
    mbid: 'artist-mbid',
    type: 'Group',
    area: 'United Kingdom',
    born: '1985',
  ),
  genres: ['alternative rock', 'art rock'],
  albums: [
    PulsarAlbumSummary(
      mbid: 'rg-2',
      title: 'The Bends',
      year: 1995,
      type: 'Album',
    ),
  ],
  releaseGroupCount: 9,
);

Future<void> _pump(
  WidgetTester tester,
  Widget page,
  List<dynamic> extra,
) async {
  tester.view.physicalSize = const Size(1100, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localLibraryProvider.overrideWithValue(null),
        librarySourcesProvider.overrideWithValue([_Source()]),
        librarySourceByIdProvider.overrideWithValue({'a': _Source()}),
        playbackProvider.overrideWith(_Idle.new),
        ...extra.cast(),
      ],
      child: MaterialApp(theme: createAppThemeSet().light, home: page),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an artist page shows the fleet biography and its facts', (
    tester,
  ) async {
    await _pump(
      tester,
      const ArtistDetailScreen(
        sourceId: 'a',
        artistId: 'artist-1',
        artistName: 'Radiohead',
      ),
      [
        artistAlbumsProvider((sourceId: 'a', id: 'artist-1'))
            .overrideWith((ref) async => const [_album]),
        albumSongsProvider(
          (sourceId: 'a', id: 'album-1'),
        ).overrideWith(() => _StubAlbumSongs(const [_song])),
        pulsarArtistProfileProvider(
          'Radiohead',
          language: 'en',
        ).overrideWith((ref) async => _artist),
      ],
    );

    // The biography is the thing the page did not have before.
    expect(
      find.textContaining('English rock band formed in Abingdon'),
      findsOneWidget,
    );
    // And the facts read as facts, not as a second prose line.
    expect(find.text('Group'), findsOneWidget);
    expect(find.text('United Kingdom'), findsOneWidget);
    expect(find.text('alternative rock'), findsOneWidget);
    // The fleet knows the record the library does not hold.
    expect(find.text('The Bends'), findsOneWidget);
  });

  testWidgets('an album page shows the record description', (tester) async {
    const albumMeta = PulsarEntityMetadata(
      title: 'OK Computer',
      subtitle: 'Radiohead',
      caption: 'Album',
      description: 'The third studio album by the English rock band.',
      releaseDate: '1997-05-21',
      artworkUrl: 'https://coverartarchive.org/release-group/rg-1/front-500',
      genres: ['alternative rock'],
      tracks: [
        PulsarAlbumTrack(
          title: 'Airbag',
          disc: 1,
          position: 1,
          lengthMs: 284400,
        ),
      ],
    );

    await _pump(
      tester,
      const AlbumDetailScreen(sourceId: 'a', albumId: 'album-1'),
      [
        albumSongsProvider(
          (sourceId: 'a', id: 'album-1'),
        ).overrideWith(() => _StubAlbumSongs(const [_song])),
        pulsarAlbumProfileProvider(
          title: 'OK Computer',
          artist: 'Radiohead',
          language: 'en',
        ).overrideWith((ref) async => albumMeta),
      ],
    );

    expect(find.textContaining('third studio album'), findsOneWidget);
    // The release date the library's tags may not carry.
    expect(find.textContaining('1997'), findsWidgets);
  });

  testWidgets('an album whose own source has no tracks lists a server copy', (
    tester,
  ) async {
    // A cloud account answering with an id it will not turn into tracks: the
    // page must show the record and the copy another library holds, not
    // "this album is empty" over a title it already knows.
    const info = LibraryAlbum(
      sourceId: 'a',
      id: 'album-1',
      name: 'OK Computer',
      artist: 'Radiohead',
      duration: Duration.zero,
      year: 1997,
    );
    const copy = LibrarySong(
      sourceId: 'b',
      id: 'server-song',
      title: 'Airbag',
      artist: 'Radiohead',
      album: 'OK Computer',
      albumId: 'server-album',
      duration: Duration(milliseconds: 284400),
      track: 1,
    );

    await _pump(
      tester,
      const AlbumDetailScreen(
        sourceId: 'a',
        albumId: 'album-1',
        albumName: 'OK Computer',
      ),
      [
        albumTracksProvider((
          album: (sourceId: 'a', id: 'album-1'),
          title: 'OK Computer',
        )).overrideWith((ref) async => const [copy]),
        albumInfoProvider((sourceId: 'a', id: 'album-1'))
            .overrideWith((ref) async => info),
      ],
    );

    expect(find.text('OK Computer'), findsWidgets);
    expect(find.text('Airbag'), findsOneWidget);
  });
}
