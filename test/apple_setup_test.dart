import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
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
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _IdlePlayback extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([_Fake('a')]),
        playbackProvider.overrideWith(_IdlePlayback.new),
      ],
      child: MaterialApp(
        theme: createAppThemeSet().light,
        home: const SetupScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('the picker offers a kind only where it can run', (tester) async {
    await _pump(tester);

    // Every adapter in the map, minus the ones this platform cannot run. The
    // local library is not a connection, so it is never in the picker at all.
    final expected = [
      for (final entry in libraryAdapters.entries)
        if (entry.value.isAvailable) entry.key.label,
    ];
    final segments = tester
        .widget<SegmentedButton<LibraryKind>>(
          find.byType(SegmentedButton<LibraryKind>),
        )
        .segments
        .map((segment) => (segment.label as Text).data)
        .toList();

    expect(segments, expected);
    expect(segments, isNot(contains(LibraryKind.local.label)));
    // Apple Music is in the picker on macOS 14+, which is what CI runs on.
    expect(segments, contains(LibraryKind.appleMusic.label));
  });

  testWidgets('picking Apple Music hides the server fields', (tester) async {
    await _pump(tester);

    // A server kind has three fields to fill in.
    expect(find.byType(TextFormField), findsNWidgets(3));
    expect(find.text('setupTestConnection'.tr()), findsOneWidget);

    await tester.tap(find.text(LibraryKind.appleMusic.label));
    await tester.pumpAndSettle();

    // Apple Music has nothing to type: the account is the system's.
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('setupAppleMusicNote'.tr()), findsOneWidget);
    // "Test connection" is gone too: there is no address to try.
    expect(find.text('setupTestConnection'.tr()), findsNothing);
    expect(find.text('setupConnect'.tr()), findsOneWidget);

    // Switching back restores the form.
    await tester.tap(find.text(LibraryKind.subsonic.label));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(3));
  });
}
