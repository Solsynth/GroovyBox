import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/queue.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fake extends LibrarySource {
  _Fake(this.id, this.label);
  @override
  final String id;
  final String label;
  @override
  SourceConfig get config => SourceConfig(
    id: id, kind: LibraryKind.subsonic,
    baseUrl: 'https://$id', displayName: label);
  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;
  @override
  Uri streamUri(LibrarySong song) => Uri.parse('https://$id/${song.id}');
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakePlayback extends Playback {
  _FakePlayback(this.initial);
  final PlaybackState initial;
  @override
  PlaybackState build() => initial;
}

PlaybackState _queueState() => const PlaybackState(
  queue: [
    LibrarySong(sourceId: 'a', id: 's1', title: 'Solo', duration: Duration(seconds: 5)),
  ],
  currentIndex: 0,
);

Future<void> _pump(WidgetTester tester, List<LibrarySource> sources) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      librarySourcesProvider.overrideWithValue(sources),
      playbackProvider.overrideWith(() => _FakePlayback(_queueState())),
    ],
    child: MaterialApp(theme: createAppThemeSet().light, home: const QueueScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('queue labels the source only when several are connected', (tester) async {
    await _pump(tester, [_Fake('a', 'Alpha')]);
    expect(find.textContaining('Alpha'), findsNothing);

    await _pump(tester, [_Fake('a', 'Alpha'), _Fake('b', 'Beta')]);
    expect(find.textContaining('Alpha'), findsOneWidget);
  });
}
