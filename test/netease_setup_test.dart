import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/store.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/setup.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kQrDataUrl =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

/// An interactive adapter with no network: the screen's job is to drive the
/// steps, and the steps are what this stands in for.
class _FakeInteractive implements InteractiveLoginAdapter {
  String? baseUrlSeen;
  int pollCalls = 0;
  bool prepared = false;

  @override
  LibraryKind get kind => LibraryKind.netease;

  @override
  bool get needsCredentials => false;

  @override
  bool get isAvailable => true;

  @override
  Future<SourceConfig> connect({
    required String baseUrl,
    required String username,
    required String password,
  }) async => throw UnimplementedError();

  @override
  LibrarySource sourceFor(SourceConfig config) => throw UnimplementedError();

  @override
  List<LoginStep> loginSteps(String baseUrl) {
    baseUrlSeen = baseUrl;
    return [
      QrLoginStep(
        id: 'qr',
        prompt: 'setupNeteaseScanQr'.tr(),
        prepare: () async {
          prepared = true;
          return _kQrDataUrl;
        },
        poll: () {
          pollCalls++;
          return Stream.fromIterable(const [801, 802, 803]);
        },
      ),
    ];
  }

  @override
  Future<SourceConfig> completeLogin(
    String baseUrl,
    List<LoginStep> steps,
  ) async => SourceConfig(
    id: 'netease-test',
    kind: LibraryKind.netease,
    baseUrl: baseUrl,
    displayName: 'Someone',
    auth: const {'cookie': 'fake'},
  );
}

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
  tester.view.physicalSize = const Size(900, 1000);
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

/// Picks a provider from the page's dropdown the way a person does: open the
/// menu, then tap the row.
Future<void> pickKind(WidgetTester tester, LibraryKind kind) async {
  await tester.tap(find.byType(DropdownButtonFormField<LibraryKind>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(kind.label).last);
  await tester.pumpAndSettle();
}

void main() {
  late _FakeInteractive fake;
  late LibraryAdapter original;

  setUp(() {
    fake = _FakeInteractive();
    original = libraryAdapters[LibraryKind.netease]!;
    libraryAdapters[LibraryKind.netease] = fake;
  });
  tearDown(() => libraryAdapters[LibraryKind.netease] = original);

  testWidgets('picking NetEase asks for an address only', (tester) async {
    await _pump(tester);

    await pickKind(tester, LibraryKind.netease);

    // One field: the bridge address. No username, no password: the account
    // signs in by scanning.
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('setupUsername'.tr()), findsNothing);
    expect(find.text('setupPassword'.tr()), findsNothing);
    expect(find.text('setupTestConnection'.tr()), findsNothing);
    expect(find.text('setupStartLogin'.tr()), findsOneWidget);
  });

  testWidgets('the code is shown, and an authorized scan stores the source', (
    tester,
  ) async {
    await _pump(tester);
    await pickKind(tester, LibraryKind.netease);

    await tester.enterText(find.byType(TextFormField), 'bridge.example.com');
    await tester.tap(find.text('setupStartLogin'.tr()));
    await tester.pumpAndSettle();

    expect(fake.prepared, isTrue);
    expect(fake.baseUrlSeen, 'bridge.example.com');
    expect(fake.pollCalls, 1);
    // The code is on screen, and the prompt says what to do with it.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('setupNeteaseScanQr'.tr()), findsOneWidget);

    // 803 completes the login; the store write goes through a platform
    // channel, which only resolves outside the fake clock.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SetupScreen)),
    );
    expect(container.read(sourceStoreProvider), isNotEmpty);
    expect(container.read(sourceStoreProvider).single.auth['cookie'], 'fake');
  });

  testWidgets('the button goes back to "show code" after a failure', (
    tester,
  ) async {
    await _pump(tester);
    await pickKind(tester, LibraryKind.netease);

    // No address: the form refuses, and no code is minted.
    await tester.tap(find.text('setupStartLogin'.tr()));
    await tester.pumpAndSettle();
    expect(fake.prepared, isFalse);
    expect(find.text('setupStartLogin'.tr()), findsOneWidget);
  });
}
