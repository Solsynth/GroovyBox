import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/core/app.dart';
import 'package:groovy_box/core/dynamic_color.dart';
import 'package:groovy_box/core/theme.dart';
import 'package:groovy_box/library/models.dart';
import 'package:groovy_box/library/providers.dart';
import 'package:groovy_box/library/source.dart';
import 'package:groovy_box/player/player.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// A red jacket with a dark border: the shape of a cover where the jacket, not
/// the vinyl, is the colour a theme wants.
Uint8List _redCover() {
  const width = 32;
  const height = 32;
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final edge = x < 3 || y < 3 || x >= width - 3 || y >= height - 3;
      final jitter = (x * 7 + y * 13) % 6;
      bytes[i] = edge ? 8 : 210 + jitter;
      bytes[i + 1] = edge ? 8 : 40 + jitter;
      bytes[i + 2] = edge ? 8 : 46 + jitter;
      bytes[i + 3] = 255;
    }
  }
  return bytes;
}

/// An 8×8 opaque red PNG: enough of a cover to decode and score.
const _redPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAEUlEQVR4nGM4omOCFTEMLQkAqmxJ'
    'ATWNTpIAAAAASUVORK5CYII=';

class _CoverSource extends LibrarySource {
  _CoverSource(this.cover);

  final Uri cover;

  @override
  SourceConfig get config => const SourceConfig(
    id: 'cover',
    kind: LibraryKind.subsonic,
    baseUrl: 'https://music.example.com',
    displayName: 'Cover',
  );

  @override
  Uri? artworkUri(String? artId, {int size = 600}) =>
      artId == null ? null : cover;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _Playing extends Playback {
  _Playing(this.song);

  final LibrarySong song;

  @override
  PlaybackState build() => PlaybackState(queue: [song], currentIndex: 0);
}

void main() {
  test('the dominant cover colour wins over the dark border', () async {
    final seed = await seedColorOfRgba(_redCover());
    expect(seed, isNotNull);

    final hct = Hct.fromInt(seed!.toARGB32());
    // HCT places red near hue 27; anything in that neighbourhood is the
    // jacket, not the near-black border (whose chroma is under 1).
    expect(MathUtils.sanitizeDegreesDouble(hct.hue), inInclusiveRange(15, 40));
    expect(hct.chroma, greaterThan(20));
  });

  test('a fully transparent image yields no seed', () async {
    expect(await seedColorOfRgba(Uint8List(16)), isNull);
  });

  test('the theme follows the cover seed while dynamic color is on', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const cover = Color(0xFF2E8B57);
    final expected = createAppThemeSet(seedColor: cover).light;

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        coverSeedProvider.overrideWith((ref) async => cover),
      ],
    );
    await container.read(coverSeedProvider.future);

    addTearDown(container.dispose);

    expect(container.read(dynamicColorEnabledProvider), isTrue);
    expect(
      container.read(appThemeProvider).light.colorScheme.primary,
      expected.colorScheme.primary,
    );

    await container.read(dynamicColorEnabledProvider.notifier).set(false);
    expect(
      container.read(appThemeProvider).light.colorScheme.primary,
      createAppThemeSet().light.colorScheme.primary,
    );
    expect(prefs.getBool('app_dynamic_color'), isFalse);
  });

  test('a playing track with a cover seeds the theme', () async {

    // The whole pipeline, not just the scorer: a cover on disk, the transport
    // naming its track, and the theme reading the result.
    final dir = await Directory.systemTemp.createTemp('gb-cover');
    addTearDown(() => dir.delete(recursive: true));
    final coverPath = p.join(dir.path, 'red.png');
    await File(coverPath).writeAsBytes(base64Decode(_redPng));

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        librarySourcesProvider.overrideWithValue([
          _CoverSource(Uri.file(coverPath)),
        ]),
        playbackProvider.overrideWith(
          () => _Playing(
            const LibrarySong(
              sourceId: 'cover',
              id: 'red',
              title: 'Red',
              duration: Duration(seconds: 10),
              artId: 'red.png',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final seed = await container.read(coverSeedProvider.future);
    expect(seed, isNotNull);
    expect(seed!.toARGB32(), isNot(kDefaultSeedColor.toARGB32()));

    final themed = container.read(appThemeProvider).light.colorScheme.primary;
    expect(themed, createAppThemeSet(seedColor: seed).light.colorScheme.primary);
  });
}
