import 'package:flutter_test/flutter_test.dart';
import 'package:groovy_box/pulsar/links.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a link remembers the cloud playlist an origin was pushed into',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final links = PulsarPlaylistLinks(prefs);
      const key = 'device:7';

      expect(links.of(key), isNull);
      await links.set(key, 'cloud-1');
      expect(links.of(key), 'cloud-1');

      // A second origin is a separate link, even for the same cloud playlist.
      await links.set(
        PulsarPlaylistLinks.sourceKey('navidrome', 'pl-3'),
        'cloud-1',
      );
      expect(links.of(key), 'cloud-1');
      expect(
        links.of(PulsarPlaylistLinks.sourceKey('navidrome', 'pl-3')),
        'cloud-1',
      );
    },
  );

  test('deleting a cloud playlist drops every link that named it', () async {
    final prefs = await SharedPreferences.getInstance();
    final links = PulsarPlaylistLinks(prefs);
    await links.set(PulsarPlaylistLinks.deviceKey(1), 'cloud-1');
    await links.set(PulsarPlaylistLinks.deviceKey(2), 'cloud-2');
    await links.set(
      PulsarPlaylistLinks.sourceKey('jellyfin', 'pl-9'),
      'cloud-1',
    );

    await links.clearForCloud('cloud-1');

    expect(links.of(PulsarPlaylistLinks.deviceKey(1)), isNull);
    expect(links.of(PulsarPlaylistLinks.sourceKey('jellyfin', 'pl-9')), isNull);
    // The unrelated link is untouched: deleting one playlist is not a reset.
    expect(links.of(PulsarPlaylistLinks.deviceKey(2)), 'cloud-2');
  });
}
