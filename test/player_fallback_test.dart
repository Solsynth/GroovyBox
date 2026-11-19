import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/data/local/library_database.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentPlayerStream extends Fake implements PlayerStream {
  @override
  Stream<bool> get playing => const Stream.empty();
  @override
  Stream<bool> get buffering => const Stream.empty();
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<Duration> get duration => const Stream.empty();
  @override
  Stream<bool> get completed => const Stream.empty();
  @override
  Stream<double> get volume => const Stream.empty();
}

class _FakePlayer extends Fake implements Player {
  /// Every URL this player was asked to open.
  final opened = <String>[];

  @override
  PlayerStream get stream => _SilentPlayerStream();

  @override
  Future<void> open(Playable playable, {bool? play = true}) async {
    opened.add((playable as Media).uri);
  }

  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setPlaylistMode(PlaylistMode mode) async {}
  @override
  Future<void> dispose() async {}
}

/// A library that mints its URLs, as NetEase's bridge does: the paywall
/// answer is a trial URL handed back with [PreviewOnlyException] instead of a
/// playable one.
class _MintingSource extends LibrarySource implements ResolvedStreamSource {
  _MintingSource(this.id, {this.preview = false, this.catalogue = const []});

  @override
  final String id;
  final bool preview;

  /// What this library answers when another library searches it.
  final List<LibrarySong> catalogue;

  @override
  SourceConfig get config => SourceConfig(
    id: id,
    kind: LibraryKind.netease,
    baseUrl: 'https://$id.example.com',
    displayName: id,
  );

  @override
  Future<Uri> resolveStreamUri(LibrarySong song) async {
    if (preview) {
      throw PreviewOnlyException(
        Uri.parse('https://preview.example/${song.id}.aac'),
        'only a preview is available',
        messageKey: 'libraryNeteasePreviewOnly',
      );
    }
    return Uri.parse('https://$id.example.com/${song.id}.mp3');
  }

  @override
  Future<List<LibrarySong>> search(String query, {int limit = 40}) async =>
      catalogue;

  @override
  Uri streamUri(LibrarySong song) =>
      throw StateError('this library mints its URLs');

  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _wanted = LibrarySong(
  sourceId: 'ne',
  id: '101',
  title: 'Yellow',
  artist: 'Coldplay',
  album: 'Parachutes',
  duration: Duration(milliseconds: 266773),
);

void main() {
  late _FakePlayer player;
  late LibraryDatabase db;

  Future<ProviderContainer> containerFor(List<LibrarySource> sources) async {
    SharedPreferences.setMockInitialValues({'app_infinite_playback': false});
    final prefs = await SharedPreferences.getInstance();
    db = LibraryDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    player = _FakePlayer();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryDatabaseProvider.overrideWithValue(db),
        librarySourcesProvider.overrideWithValue(sources),
        playbackProvider.overrideWith(() => Playback(player)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a paywalled track plays the copy another library has', () async {
    // The neighbour tags its copy differently (a remaster credit, a rounded
    // length), which is what the identity rules exist to see through.
    final neighbour = _MintingSource(
      'jam',
      catalogue: const [
        LibrarySong(
          sourceId: 'jam',
          id: 's-1',
          title: 'Yellow (Remastered)',
          artist: 'Coldplay',
          duration: Duration(milliseconds: 267500),
        ),
      ],
    );
    final container = await containerFor([
      _MintingSource('ne', preview: true),
      neighbour,
    ]);

    await container.read(playbackProvider.notifier).playQueue([_wanted]);

    // The trial URL is never opened: the row's own library said it only has
    // an excerpt, and another library streams the whole recording.
    expect(player.opened, ['https://jam.example.com/s-1.mp3']);
  });

  test('the row follows the copy that actually plays', () async {
    final container = await containerFor([
      _MintingSource('ne', preview: true),
      _MintingSource(
        'jam',
        catalogue: const [
          LibrarySong(
            sourceId: 'jam',
            id: 's-1',
            title: 'Yellow',
            artist: 'Coldplay',
            duration: Duration(milliseconds: 266773),
          ),
        ],
      ),
    ]);

    await container.read(playbackProvider.notifier).playQueue([_wanted]);

    // What sounds is the neighbour's copy, so the dock, lyrics and the next
    // open of this slot must name it rather than the library that refused.
    final row = container.read(playbackProvider).queueRow!;
    expect(row.sourceId, 'jam');
    expect(row.id, 's-1');
    expect(container.read(playbackProvider).position, Duration.zero);
  });

  test('the excerpt is played when nobody has the full track', () async {
    final container = await containerFor([_MintingSource('ne', preview: true)]);

    await container.read(playbackProvider.notifier).playQueue([_wanted]);

    // Silence would be worse than thirty seconds of the right recording; the
    // trial URL is held until every connected library has been asked.
    expect(player.opened, ['https://preview.example/101.aac']);
  });

  test('a neighbour asked for the track answers with its own refusal', () async {
    final container = await containerFor([
      _MintingSource('ne', preview: true),
      _MintingSource(
        'jam',
        preview: true,
        catalogue: const [
          LibrarySong(
            sourceId: 'jam',
            id: 's-1',
            title: 'Yellow',
            artist: 'Coldplay',
            duration: Duration(milliseconds: 266773),
          ),
        ],
      ),
    ]);

    await container.read(playbackProvider.notifier).playQueue([_wanted]);

    expect(player.opened, ['https://preview.example/101.aac']);
  });

  test('a row whose library is gone is served from another library', () async {
    // A restored session keeps the row after its library was disconnected:
    // the track is still in the catalog, and a neighbour's search finds it
    // even though this session has never seen that copy.
    final neighbour = _MintingSource(
      'jam',
      catalogue: const [
        LibrarySong(
          sourceId: 'jam',
          id: 's-1',
          title: 'Yellow',
          artist: 'Coldplay',
          duration: Duration(milliseconds: 266773),
        ),
      ],
    );
    final container = await containerFor([neighbour]);

    await container.read(playbackProvider.notifier).playQueue([_wanted]);

    expect(player.opened, ['https://jam.example.com/s-1.mp3']);
  });
}
