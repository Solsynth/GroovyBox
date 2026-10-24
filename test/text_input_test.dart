import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/browse.dart';
import 'package:groovy_box/screens/setup.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fake extends LibrarySource {
  _Fake(this.id);
  @override
  final String id;
  @override
  SourceConfig get config => SourceConfig(
    id: id,
    kind: LibraryKind.subsonic,
    baseUrl: 'https://music.example.com',
    displayName: 'Home library',
  );
  @override
  Uri? artworkUri(String? artId, {int size = 600}) => null;
  @override
  Uri streamUri(LibrarySong song) => Uri.parse('https://x/${song.id}');
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _IdlePlayback extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

/// Drives the field the way the macOS embedder does: every keystroke and every
/// backspace arrives as a full editing-value replacement with a composing
/// range, not as an incremental insert.
Future<void> type(WidgetTester tester, String text) async {
  final client = tester.testTextInput;
  var value = fieldText(tester);
  for (final char in text.split('')) {
    value += char;
    client.updateEditingValue(
      TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      ),
    );
    await tester.pump();
  }
}

Future<void> backspace(WidgetTester tester) async {
  final client = tester.testTextInput;
  final current = fieldText(tester);
  final value = current.isEmpty
      ? ''
      : current.substring(0, current.length - 1);
  client.updateEditingValue(
    TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    ),
  );
  await tester.pump();
}

String fieldText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText).first).controller.text;

Future<void> pumpPage(WidgetTester tester, Widget page) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([_Fake('a')]),
        playbackProvider.overrideWith(_IdlePlayback.new),
      ],
      child: MaterialApp(theme: createAppThemeSet().light, home: page),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('setup: delete a character and type another, nothing returns',
      (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpPage(tester, const SetupScreen());

    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();

    await type(tester, 'music.example.com');
    expect(fieldText(tester), 'music.example.com');

    // The reported sequence: delete a few characters, then type something new.
    await backspace(tester);
    await backspace(tester);
    await backspace(tester);
    expect(fieldText(tester), 'music.example.');

    await type(tester, 'org');
    expect(
      fieldText(tester),
      'music.example.org',
      reason: 'deleted characters must not come back',
    );
  });

  testWidgets('browse search: delete and retype keeps the edit', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpPage(tester, const BrowseScreen());

    await tester.tap(find.byType(SearchBar));
    await tester.pump();

    await type(tester, 'sunset');
    expect(fieldText(tester), 'sunset');

    await backspace(tester);
    await backspace(tester);
    await backspace(tester);
    expect(fieldText(tester), 'sun');

    await type(tester, 'rise');
    expect(fieldText(tester), 'sunrise');
  });

  testWidgets('the searched text reaches the provider, not a stale query',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpPage(tester, const BrowseScreen());

    await tester.tap(find.byType(SearchBar));
    await tester.pump();
    await type(tester, 'abc');
    await backspace(tester);
    await type(tester, 'd');

    // The field and the results header must agree; a stale query would show
    // the old text in the empty state.
    expect(fieldText(tester), 'abd');
    expect(find.textContaining('abd'), findsWidgets);
    expect(find.textContaining('abc'), findsNothing);
  });
}
