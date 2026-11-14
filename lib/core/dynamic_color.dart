/// The cover's own colour, as a theme seed.
///
/// Dynamic colour is one pipeline: the track that is playing names its cover,
/// the cover is decoded small, its dominant usable colour is scored by Material
/// Color Utilities, and that colour seeds the app's theme. Only a seed crosses
/// into `lib/core/app.dart`; everything else here is a fetch and a decode.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../library/models.dart';
import '../library/providers.dart';
import '../library/source.dart';
import '../player/player.dart';
import 'identity.dart';
import 'theme.dart';

part 'dynamic_color.g.dart';

/// The seed the player's current cover yields, or null when there is nothing
/// to read: no track, no cover, no server that can name one, or an image that
/// would not decode.
///
/// Rebuilt when the playing track changes, not on every position tick: the
/// transport's `current` is the same song instance until the track does.
@Riverpod(keepAlive: true)
Future<Color?> coverSeed(Ref ref) async {
  final song = ref.watch(playbackProvider.select((state) => state.current));
  if (song == null) return null;

  final source = ref.watch(librarySourceByIdProvider)[song.sourceId];
  if (source == null) return null;

  final uri = await _coverUri(source, song);
  if (uri == null) return null;
  if (_seeds.length >= _maxCachedSeeds) _seeds.remove(_seeds.keys.first);
  return _seeds.putIfAbsent(uri, () => _seedOf(uri));
}

/// Seed per cover URL, so skipping back to a track does not download and
/// decode its cover again. Small and insertion-ordered: a listening session
/// touches a handful of albums, not a catalogue.
final _seeds = <String, Future<Color?>>{};

const _maxCachedSeeds = 32;

Future<Color?> _seedOf(String key) async {
  // Registered before the first await, so a second listener shares this run
  // instead of starting its own.
  final bytes = await _readBytes(Uri.parse(key));
  if (bytes == null) return null;
  return seedColorOfImage(bytes);
}

Future<String?> _coverUri(LibrarySource source, LibrarySong song) async {
  // A cover the source can name outright.
  final direct = source.artworkUri(song.artId, size: _analysisWidth);
  if (direct != null) return direct.toString();

  // A platform-played item may only have reported a handle its own player can
  // read (Apple Music stations). Ask the source to turn it into a real URL.
  if (source is PlatformPlayedSource) {
    final template = await source.artworkTemplate(song);
    final resolved = source.artworkUri(template, size: _analysisWidth);
    if (resolved != null) return resolved.toString();
  }
  return null;
}

Future<Uint8List?> _readBytes(Uri uri) async {
  try {
    if (uri.isScheme('file')) {
      return await File(uri.toFilePath()).readAsBytes();
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, appUserAgent);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        // A missing cover is an ordinary answer, not a failure to report: the
        // theme stays on the app's own seed.
        await response.drain<void>();
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await response.forEach(builder.add);
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  } on Object {
    debugPrint('[DynamicColor] Could not read cover $uri');
    return null;
  }
}

/// The dominant colour of an encoded image (JPEG, PNG, WebP …).
///
/// Decoded at [_analysisWidth] pixels wide: the seed is a hue and a rough
/// chroma, and a 128 px cover answers both without paying for a full-size
/// bitmap or an animation's frames.
Future<Color?> seedColorOfImage(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: _analysisWidth);
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) return null;
      return await seedColorOfRgba(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } finally {
      image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

/// The colour in [rgba] (straight RGBA, row-major) that carries a UI theme
/// best, or null when the image has no opaque pixels.
///
/// Ranking is Material's own: Celebi's quantizer folds the cover into at most
/// 128 colours, and `Score` prefers a hue that covers much of the image at a
/// chroma near A1, so a red jacket beats the black vinyl around it. Art with
/// no usable hue (a gray cover, a photo of a white wall) falls back to the
/// app's own seed rather than to Material's off-brand blue.
Future<Color?> seedColorOfRgba(Uint8List rgba) async {
  final population = <int, int>{};
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    final a = rgba[i + 3];
    if (a < 0x80) continue;
    final argb = (a << 24) |
        (rgba[i] << 16) |
        (rgba[i + 1] << 8) |
        rgba[i + 2];
    population[argb] = (population[argb] ?? 0) + 1;
  }
  if (population.isEmpty) return null;

  final result = await QuantizerCelebi().quantize(population.keys, _maxColors);
  if (result.colorToCount.isEmpty) return null;
  final best = Score.score(
    result.colorToCount,
    desired: 1,
    fallbackColorARGB: kDefaultSeedColor.toARGB32(),
  ).first;
  return Color(best);
}

const _analysisWidth = 128;
const _maxColors = 128;
