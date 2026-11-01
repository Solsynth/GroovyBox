// One test, one file: the translator is a process-wide singleton whose
// `setLocale` reloads through the asset bundle, so a second test in the same
// process would inherit both the locale and the in-flight load. `flutter test`
// runs each file in its own isolate, which keeps this honest.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/player/player.dart';
import 'package:groovy_box/screens/settings.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Idle extends Playback {
  @override
  PlaybackState build() => const PlaybackState();
}

/// Mirrors main.dart's builder: the content is keyed on the locale, so a
/// language change remounts it and every `.tr()` re-reads the new catalog.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('the language dropdown switches the page to Chinese', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            librarySourcesProvider.overrideWithValue(const []),
            libraryDatabaseProvider.overrideWithValue(null),
            playbackProvider.overrideWith(_Idle.new),
          ],
          child: EasyLocalization(
            supportedLocales: const [Locale('en', 'US'), Locale('zh', 'CN')],
            path: 'assets/i18n',
            fallbackLocale: const Locale('en', 'US'),
            useFallbackTranslations: true,
            child: Builder(
              builder: (context) => MaterialApp(
                theme: createAppThemeSet().light,
                locale: context.locale,
                supportedLocales: const [
                  Locale('en', 'US'),
                  Locale('zh', 'CN'),
                ],
                localizationsDelegates: [
                  ...context.localizationDelegates,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                builder: (context, child) =>
                    KeyedSubtree(key: ValueKey(context.locale), child: child!),
                home: const SettingsScreen(),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // English to start with.
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('语言'), findsNothing);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文').last);
    // The pick reloads the catalog through the asset bundle, which needs a
    // real turn of the event loop rather than the test's fake clock.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    // The whole page is Chinese now, the picker's own row included.
    expect(prefs.getString('locale'), 'zh_CN');
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('液态玻璃'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
