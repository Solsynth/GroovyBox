import 'package:groovy_box/core/updates.dart';
import 'package:solsynth_express/api.dart';

/// A release feed that answers from memory, so a widget or a provider can be
/// exercised without a socket.
///
/// `check` reports whatever [updateAvailable] says, which is what makes the
/// difference visible between "you are current" and a sheet; [fails] makes
/// `latest` throw, which is the state the settings row draws as "did not
/// answer" rather than as an empty channel.
class FakeReleaseFeed extends ReleaseFeed {
  FakeReleaseFeed({
    this.updateAvailable = false,
    this.release,
    this.configured = true,
    this.fails = false,
    this.publishedChannels = const ['beta'],
  });

  final bool updateAvailable;
  final DistributionReleaseInfo? release;
  final bool configured;
  final bool fails;

  /// Channel names the publisher exposes. Empty is a product that exists but
  /// has nowhere to publish yet.
  final List<String> publishedChannels;

  /// How many times the launch check or the "check now" row asked.
  int checks = 0;

  static DistributionReleaseInfo build({
    String version = '2.1.0+24',
    String name = 'GroovyBox 2.1',
    String body = 'Playlist **import** is back.',
    String channel = 'stable',
  }) => DistributionReleaseInfo(
    id: 'r1',
    tagName: version,
    name: name,
    body: body,
    htmlUrl: 'https://example.com/release',
    createdAt: DateTime.utc(2026, 11, 18, 12),
    publishedAt: DateTime.utc(2026, 11, 18, 12),
    channel: channel,
    forceUpdate: false,
    metadata: const {},
    artifacts: const [
      DistributionArtifact(
        id: 'a1',
        platform: 'macos',
        architecture: 'arm64',
        fileName: 'GroovyBox.dmg',
        mimeType: 'application/x-apple-diskimage',
        size: 44040192,
        hash: 'abc',
        downloadUrl: 'https://example.com/GroovyBox.dmg',
        expired: false,
      ),
    ],
  );

  @override
  bool get isConfigured => configured;

  @override
  Future<ReleaseCheck?> check(
    AppTarget target, {
    required String channel,
    String? locale,
  }) async {
    checks++;
    if (fails || release == null) return null;
    return ReleaseCheck(
      release: release!,
      currentVersion: target.version,
      updateAvailable: updateAvailable,
    );
  }

  @override
  Future<DistributionReleaseInfo?> latest({
    required String channel,
    AppTarget? target,
  }) async {
    if (fails) throw StateError('feed unreachable');
    return release;
  }

  @override
  Future<List<DistributionChannel>> channels() async => [
    for (final name in publishedChannels)
      DistributionChannel(
        id: name,
        name: name,
        displayName: name[0].toUpperCase() + name.substring(1),
        displayNames: const {},
        description: '',
        descriptions: const {},
        latest: null,
      ),
  ];
}
