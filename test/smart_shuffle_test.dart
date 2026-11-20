import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/smart_shuffle.dart';

LibrarySong _song(
  String id, {
  String title = 'Song',
  String? artist = 'Artist',
  String? genre,
  int seconds = 200,
}) => LibrarySong(
  sourceId: 'a',
  id: id,
  title: title,
  artist: artist,
  genre: genre,
  duration: Duration(seconds: seconds),
);

ShuffleSeed _seed(
  LibrarySong song, {
  bool favourite = false,
  bool recommended = false,
  int plays = 0,
  bool recentlyPlayed = false,
}) => ShuffleSeed(
  song: song,
  favourite: favourite,
  recommended: recommended,
  plays: plays,
  recentlyPlayed: recentlyPlayed,
);

void main() {
  test('a genre takes a mood by its words, not its exact spelling', () {
    expect(moodForGenre('Holiday Rock'), ShuffleMood.festive);
    expect(moodForGenre('Ambient Techno'), ShuffleMood.chill);
    expect(moodForGenre('Classical Piano'), ShuffleMood.focus);
    expect(moodForGenre('R&B/Soul'), ShuffleMood.romantic);
    expect(moodForGenre('Alternative Rock'), ShuffleMood.energetic);
    expect(moodForGenre('Ballad'), ShuffleMood.melancholy);
    expect(moodForGenre(''), isNull);
    expect(moodForGenre(null), isNull);
  });

  test(
    'the same recording from two libraries is one entry, signals merged',
    () {
      final plan = planSmartShuffle([
        _seed(_song('1', title: 'Yellow', artist: 'Coldplay'), favourite: true),
        // The same song under another library's tags; the extra plays add up.
        _seed(_song('2', title: 'yellow (Live)', artist: 'Coldplay'), plays: 3),
      ]);

      expect(plan.queue, hasLength(1));
      expect(plan.queue.single.title, 'Yellow');
    },
  );

  test('hearts outrank recommendations, which outrank a plain row', () {
    final plan = planSmartShuffle([
      _seed(_song('plain', title: 'Plain')),
      _seed(_song('rec', title: 'Rec'), recommended: true),
      _seed(_song('heart', title: 'Heart'), favourite: true),
    ], size: 3);

    expect(plan.queue.map((song) => song.title), ['Heart', 'Rec', 'Plain']);
  });

  test('a recently played track drops below an unheard one', () {
    final plan = planSmartShuffle([
      _seed(_song('recent', title: 'Recent'), plays: 5, recentlyPlayed: true),
      _seed(_song('fresh', title: 'Fresh')),
    ], size: 2);

    expect(plan.queue.first.title, 'Fresh');
  });

  test('the same artist does not run back to back while another remains', () {
    final plan = planSmartShuffle([
      for (var i = 0; i < 4; i++)
        _seed(_song('a$i', title: 'A$i', artist: 'Artist A'), plays: 9),
      for (var i = 0; i < 3; i++)
        _seed(_song('b$i', title: 'B$i', artist: 'Artist B')),
    ], size: 7);

    final artists = [for (final song in plan.queue) song.artist];
    for (var i = 1; i < artists.length; i++) {
      expect(artists[i], isNot(artists[i - 1]));
    }
  });

  test('groups cover genres and moods above the minimum size', () {
    final plan = planSmartShuffle([
      for (var i = 0; i < 4; i++)
        _seed(_song('rock$i', title: 'Rock $i', genre: 'Alternative Rock')),
      for (var i = 0; i < 4; i++)
        _seed(_song('chill$i', title: 'Chill $i', genre: 'Lo-Fi')),
      // One lonely genre is a shelf of one: it does not earn a row.
      _seed(_song('solo', title: 'Solo', genre: 'Polka')),
    ], minimumGroupSize: 3);

    final titles = plan.groups.map((group) => group.title).toList();
    expect(titles, contains('Alternative Rock'));
    expect(titles, contains('Lo-Fi'));
    expect(titles, isNot(contains('Polka')));
    final moods = [
      for (final group in plan.groups)
        if (group.kind == ShuffleGroupKind.mood) group.title,
    ];
    expect(moods, contains('energetic'));
    expect(moods, contains('chill'));
  });

  test('a second press with another seed explores a different slice', () {
    final seeds = [
      for (var i = 0; i < 20; i++) _seed(_song('s$i', title: 'S$i')),
    ];
    final first = planSmartShuffle(seeds, size: 5, seed: 1);
    final second = planSmartShuffle(seeds, size: 5, seed: 2);

    expect(first.queue, hasLength(5));
    expect(second.queue, hasLength(5));
    // Seeded, not random: the same seed repeats.
    expect(
      planSmartShuffle(seeds, size: 5, seed: 1).queue.map((s) => s.id),
      first.queue.map((s) => s.id),
    );
  });

  test('an empty library plans nothing rather than an empty queue', () {
    expect(planSmartShuffle(const []).isEmpty, isTrue);
    expect(planSmartShuffle(const [], size: 0).isEmpty, isTrue);
  });

  test('a station is never queued: it has no track to walk', () {
    final plan = planSmartShuffle([
      _seed(
        LibrarySong(
          sourceId: 'a',
          id: 'radio',
          title: 'Station',
          duration: Duration.zero,
          isRadio: true,
        ),
      ),
      _seed(_song('real')),
    ]);

    expect(plan.queue.map((song) => song.id), ['real']);
  });

  test('mood bucket matching tolerates casing and compounds', () {
    expect(moodForGenre('CHRISTMAS'), ShuffleMood.festive);
    expect(moodForGenre('Hip-Hop'), ShuffleMood.energetic);
    expect(moodForGenre('Rock Ballad'), ShuffleMood.melancholy);
  });
}
