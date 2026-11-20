import 'package:groovy_box/desktop/mini_player/link.dart';
import 'package:groovy_box/widgets/artwork_pixels.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// The mini window's cover art, resolved by the host.
///
/// The guest holds no library sources — it never loads the source store — so
/// an art handle is opaque to it, and it keeps no cover cache of its own: a
/// second writer on the same folder would only race the host's. The host owns
/// both, so the guest asks over the link and paints whatever comes back.
class MiniArtworkSource {
  final MiniPlayerLink? _link;

  const MiniArtworkSource(this._link);

  /// The cover's pixels, or null when the host has nothing to paint.
  Future<ArtworkPixels?> pixels(ArtworkHandle handle) async {
    final reply = await _link?.command<Object?>(kResolveArtworkMethod, {
      'sourceId': handle.sourceId,
      'artId': handle.artId,
      'size': handle.size,
    });
    if (reply is! Map) return null;
    return ArtworkPixels.fromUri(reply[kArtworkUriField] as String?);
  }
}

/// The link-backed resolver. `main()` overrides this with the guest's link;
/// the default answers null, so a widget test can draw the view and see the
/// placeholder without a second engine on the other end.
final miniArtworkSourceProvider = Provider<MiniArtworkSource>(
  (ref) => const MiniArtworkSource(null),
);
