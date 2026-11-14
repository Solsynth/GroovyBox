import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/solarpass/client.dart';
import 'package:groovy_box/solarpass/models.dart';
import 'package:groovy_box/solarpass/providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A transport whose state a test moves by hand: nothing is loaded, decoded
/// or played, and only what the scrobbler reads — the current row, its length
/// and whether it is playing — changes.
class _FakePlayback extends Playback {
  @override
  PlaybackState build() => const PlaybackState();

  void startTrack(LibrarySong song) {
    state = PlaybackState(
      queue: [song],
      currentIndex: 0,
      playing: true,
      duration: song.duration,
    );
  }

  void hold() => state = state.copyWith(playing: false);
}

class _FakeSession extends SolarpassSessionNotifier {
  static const session = OAuthSession(accessToken: 'token');

  @override
  Future<OAuthSession?> build() async => session;

  @override
  Future<OAuthSession?> validSession() async => session;
}

class _RecordingClient extends SolarpassClient {
  final presence = <String>[];
  final scrobbles = <({String title, Duration listened})>[];

  @override
  Future<void> setPresenceActivity({
    required OAuthSession session,
    required String title,
    String? artist,
    String? album,
    Duration? duration,
    Duration? position,
    String? artworkUrl,
    String? trackId,
  }) async {
    presence.add(title);
  }

  @override
  Future<void> submitScrobble({
    required OAuthSession session,
    required String title,
    String? artist,
    String? album,
    Duration? duration,
    Duration? listened,
    String? artworkUrl,
    String? trackId,
    DateTime? playedAt,
  }) async {
    scrobbles.add((title: title, listened: listened ?? Duration.zero));
  }
}

LibrarySong _song(String id, {int seconds = 200}) => LibrarySong(
  sourceId: 'a',
  id: id,
  title: 'Song $id',
  duration: Duration(seconds: seconds),
);

void main() {
  late SharedPreferences prefs;
  late _FakePlayback playback;
  late _RecordingClient client;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    playback = _FakePlayback();
    client = _RecordingClient();
    // Built outside the fake clock: reading the scrobbler must happen inside
    // it, so the timers it arms belong to the same timeline the test moves.
  });

  /// Reads the scrobbler inside [async]'s timeline and hands back the
  /// container, so its timers elapse with the fake clock.
  ProviderContainer start() {
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourceByIdProvider.overrideWithValue(const {}),
        playbackProvider.overrideWith(() => playback),
        solarpassSessionProvider.overrideWith(_FakeSession.new),
        solarpassClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    container.read(solarpassScrobblerProvider);
    return container;
  }

  group('isScrobbleEligible', () {
    test('a quarter of the track is enough', () {
      expect(
        isScrobbleEligible(
          duration: const Duration(seconds: 200),
          listened: const Duration(seconds: 50),
        ),
        isTrue,
      );
      expect(
        isScrobbleEligible(
          duration: const Duration(seconds: 200),
          listened: const Duration(seconds: 49),
        ),
        isFalse,
      );
    });

    test('a row with no length of its own needs 30 seconds', () {
      expect(
        isScrobbleEligible(
          duration: Duration.zero,
          listened: const Duration(seconds: 30),
        ),
        isTrue,
      );
      expect(
        isScrobbleEligible(
          duration: Duration.zero,
          listened: const Duration(seconds: 29),
        ),
        isFalse,
      );
    });

    test('jingle-length rows never count', () {
      expect(
        isScrobbleEligible(
          duration: const Duration(seconds: 20),
          listened: const Duration(seconds: 20),
        ),
        isFalse,
      );
    });
  });

  test('a skip-through broadcasts only the track it settles on', () {
    fakeAsync((async) {
      start();

      playback.startTrack(_song('1'));
      async.elapse(const Duration(seconds: 1));
      playback.startTrack(_song('2'));
      async.elapse(const Duration(seconds: 1));
      playback.startTrack(_song('3'));
      async.elapse(const Duration(seconds: 3));

      expect(client.presence, ['Song 3']);
    });
  });

  test('a track heard past a quarter scrobbles when the next one starts', () {
    fakeAsync((async) {
      start();

      playback.startTrack(_song('1'));
      async.elapse(const Duration(seconds: 60));
      playback.startTrack(_song('2'));
      async.elapse(const Duration(seconds: 1));

      expect(client.scrobbles, hasLength(1));
      expect(client.scrobbles.single.title, 'Song 1');
      expect(client.scrobbles.single.listened, const Duration(seconds: 60));
    });
  });

  test('a track skipped before a quarter is not scrobbled', () {
    fakeAsync((async) {
      start();

      playback.startTrack(_song('1'));
      async.elapse(const Duration(seconds: 20));
      playback.startTrack(_song('2'));
      async.elapse(const Duration(seconds: 1));

      expect(client.scrobbles, isEmpty);
    });
  });

  test('pausing before the broadcast fires cancels it', () {
    fakeAsync((async) {
      start();

      playback.startTrack(_song('1'));
      async.elapse(const Duration(seconds: 1));
      playback.hold();
      async.elapse(const Duration(seconds: 5));

      expect(client.presence, isEmpty);
    });
  });
}
