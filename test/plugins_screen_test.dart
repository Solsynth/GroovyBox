import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/plugins/plugin_host.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/library/store.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/plugins_section.dart';
import 'package:groovy_box/screens/setup.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final Directory root;

  @override
  Future<String?> getApplicationSupportPath() async => root.path;
}

class _IdlePlayback extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

/// Boots a host over a temp support directory and installs the Kugou plugin
/// from this repo's own `plugins/` folder, the way the folder picker does.
Future<PluginHost> _bootWithKugou() async {
  SharedPreferences.setMockInitialValues({});
  PathProviderPlatform.instance = _FakePathProvider(
    Directory.systemTemp.createTempSync('groovybox_plugin_ui_'),
  );
  final host = PluginHost();
  PluginHost.instance = host;
  await host.boot();
  final installed = await host.installFromFolder(
    p.join(Directory.current.path, 'plugins', 'kugou'),
  );
  expect(installed, isTrue);
  addTearDown(() {
    host.controller.dispose();
    PluginHost.instance = null;
  });
  return host;
}

Future<Widget> _setupScreen() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      librarySourcesProvider.overrideWithValue(const []),
      playbackProvider.overrideWith(_IdlePlayback.new),
    ],
    child: MaterialApp(
      theme: createAppThemeSet().light,
      home: const SetupScreen(),
    ),
  );
}

void main() {
  testWidgets('the plugins section explains what an empty list means', (
    tester,
  ) async {
    // A platform without a plugin runtime says so; a platform with one points
    // at the folder picker. Either way the page never offers a dead control.
    PluginHost.instance = null;
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: createAppThemeSet().light,
          home: const Scaffold(
            body: SingleChildScrollView(child: PluginsSection()),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Plugins'), findsWidgets);
    if (pluginRuntimeSupported) {
      expect(find.text('Install from folder…'), findsOneWidget);
      expect(find.text('Reload'), findsOneWidget);
    } else {
      expect(find.textContaining('This build cannot run them'), findsOneWidget);
      expect(find.text('Install from folder…'), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('an installed plugin appears in the picker and connects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Installing copies files and loads a JS sandbox: real I/O and a real
    // engine, so it has to run outside the widget test's fake clock.
    final host = (await tester.runAsync(_bootWithKugou))!;

    await tester.pumpWidget(await _setupScreen());
    await tester.pump();
    await tester.pump();

    // The plugin's own library name, beside the built-ins.
    await tester.tap(find.byType(DropdownButtonFormField<SetupOption>));
    await tester.pumpAndSettle();
    expect(find.text('Kugou Music'), findsWidgets);
    await tester.tap(find.text('Kugou Music').last);
    await tester.pumpAndSettle();

    // No address, no username, no password: the provider declares none, so the
    // one-line note stands where the form fields would be.
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('setupPluginNote'.tr()), findsOneWidget);

    await tester.tap(find.text('setupConnect'.tr()));
    // The store write goes through a platform channel, which only resolves
    // outside the fake clock — the same reason the NetEase login test waits.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SetupScreen)),
    );
    final stored = container.read(sourceStoreProvider);
    expect(stored, hasLength(1));
    expect(stored.single.kind, LibraryKind.plugin);
    // The manifest id is the config's address; the provider is what makes the
    // connection addressable inside the plugin.
    expect(stored.single.baseUrl, 'dev.groovybox.kugou');
    expect(stored.single.auth, {'providerId': 'kugou'});
    expect(stored.single.displayName, 'Kugou Music');
    expect(host.providers.single.providerId, 'kugou');
  });
}
