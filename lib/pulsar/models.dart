/// Pulsar wire models, hand-mirrored from LightHouse's
/// `internal/pulsar/model/models.go` and the `collections`, `sessions`,
/// `scrobbles`, `catalog` and `metadata` modules' request/response shapes.
///
/// The same rule as `library_sync/models.dart` holds: snake_case keys exactly
/// as the Go JSON tags spell them, no screen ever sees a Pulsar field name.
library;

/// A fleet [ApiError] surfaced as a typed exception.
class PulsarException implements Exception {
  PulsarException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.detail,
    this.traceId,
  });

  final int statusCode;
  final String code;
  final String message;
  final String? detail;
  final String? traceId;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'PulsarException($statusCode $code): $message';
}

/// A 401: the session must be refreshed once and the call retried.
class PulsarUnauthorized extends PulsarException {
  PulsarUnauthorized({
    required super.code,
    required super.message,
    super.detail,
    super.traceId,
  }) : super(statusCode: 401);
}

/// The playlist kinds Pulsar collections can carry. Music uses [playlist].
enum CollectionKind {
  playlist('playlist'),
  watchlist('watchlist'),
  backlog('backlog'),
  favorites('favorites'),
  custom('custom');

  const CollectionKind(this.value);
  final String value;

  static CollectionKind? tryParse(String? value) =>
      value == null ? null : values.where((k) => k.value == value).firstOrNull;
}

/// A Pulsar catalog item: the server-side record of a track, deduped on
/// `provider` + `provider_key` or `domain` + `title` + `subtitle`.
class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.domain,
    required this.provider,
    this.providerKey,
    required this.title,
    this.subtitle,
    this.artworkUrl,
    this.durationSeconds,
  });

  final String id;
  final String domain;
  final String provider;
  final String? providerKey;
  final String title;
  final String? subtitle;
  final String? artworkUrl;
  final int? durationSeconds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'domain': domain,
    'provider': provider,
    if (providerKey != null) 'provider_key': providerKey,
    'title': title,
    if (subtitle != null) 'subtitle': subtitle,
    if (artworkUrl != null) 'artwork_url': artworkUrl,
    if (durationSeconds != null) 'duration_seconds': durationSeconds,
  };

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
    id: json['id']?.toString() ?? '',
    domain: json['domain'] as String? ?? 'music',
    provider: json['provider'] as String? ?? '',
    providerKey: json['provider_key'] as String?,
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String?,
    artworkUrl: json['artwork_url'] as String?,
    durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
  );
}

/// One track inside a [PulsarPlaylist].
class PlaylistItem {
  const PlaylistItem({
    required this.id,
    this.catalogId,
    this.position,
    this.catalogItem,
  });

  final String id;
  final String? catalogId;
  final int? position;
  final CatalogItem? catalogItem;

  factory PlaylistItem.fromJson(Map<String, dynamic> json) => PlaylistItem(
    id: json['id']?.toString() ?? '',
    catalogId: json['catalog_id']?.toString(),
    position: (json['position'] as num?)?.toInt(),
    catalogItem: (json['catalog_item'] as Map<String, dynamic>?) == null
        ? null
        : CatalogItem.fromJson(json['catalog_item'] as Map<String, dynamic>),
  );
}

/// A Pulsar collection with kind playlist. The server's list response is a
/// bare array and never preloads items; [items] is filled only by a detail
/// read.
class PulsarPlaylist {
  const PulsarPlaylist({
    required this.id,
    required this.name,
    this.description,
    required this.isPublic,
    this.artworkUrl,
    this.items = const [],
  });

  final String id;
  final String name;
  final String? description;
  final bool isPublic;
  final String? artworkUrl;
  final List<PlaylistItem> items;

  String get subtitle {
    final artist = items.firstOrNull?.catalogItem?.subtitle;
    return artist ?? description ?? '';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (description != null) 'description': description,
    'is_public': isPublic,
    if (artworkUrl != null) 'artwork_url': artworkUrl,
  };

  factory PulsarPlaylist.fromJson(Map<String, dynamic> json) => PulsarPlaylist(
    id: json['id']?.toString() ?? '',
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    isPublic: json['is_public'] as bool? ?? true,
    artworkUrl: json['artwork_url'] as String?,
    items: ((json['items'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PlaylistItem.fromJson)
        .toList(),
  );
}

/// A friend's live listening state, merged from Stargate's
/// `GET /api/friends/overview` (account + status + presence activities).
class FriendListening {
  const FriendListening({required this.account, required this.activities});

  final FriendAccount account;
  final List<PresenceActivity> activities;

  /// The most recent, still-live activity, or null when the friend is not
  /// listening to anything.
  PresenceActivity? get nowPlaying {
    final live =
        activities
            .where((a) => !a.isExpired && a.type == null || a.type == 'music')
            .toList()
          ..sort(
            (a, b) => (b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
          );
    return live.firstOrNull;
  }

  factory FriendListening.fromJson(Map<String, dynamic> json) =>
      FriendListening(
        account: FriendAccount.fromJson(
          (json['account'] as Map<String, dynamic>?) ?? const {},
        ),
        activities: ((json['activities'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PresenceActivity.fromJson)
            .toList(),
      );
}

/// The slice of a Stargate account this screen renders.
class FriendAccount {
  const FriendAccount({
    required this.id,
    required this.name,
    this.nick,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String? nick;
  final String? avatarUrl;

  String get displayName =>
      (nick != null && nick!.trim().isNotEmpty) ? nick!.trim() : name;

  factory FriendAccount.fromJson(Map<String, dynamic> json) {
    String? avatar;
    final profile = json['profile'] as Map<String, dynamic>?;
    final picture = profile?['picture'];
    if (picture is Map<String, dynamic>) {
      avatar = picture['url'] as String?;
    }
    return FriendAccount(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      nick: json['nick'] as String?,
      avatarUrl: avatar,
    );
  }
}

/// One presence activity, mirrored from Stargate's
/// `model.PresenceActivity` (the shape `/api/friends/overview` returns).
class PresenceActivity {
  const PresenceActivity({
    required this.id,
    this.type,
    required this.accountId,
    this.title,
    this.subtitle,
    this.caption,
    this.artworkUrl,
    this.startedAt,
    this.leaseExpiresAt,
  });

  final String id;
  final String? type;
  final String accountId;
  final String? title;
  final String? subtitle;
  final String? caption;
  final String? artworkUrl;
  final DateTime? startedAt;
  final DateTime? leaseExpiresAt;

  bool get isExpired {
    final expiry = leaseExpiresAt;
    return expiry != null && expiry.isBefore(DateTime.now());
  }

  factory PresenceActivity.fromJson(Map<String, dynamic> json) =>
      PresenceActivity(
        id: json['id']?.toString() ?? '',
        type: json['type'] as String?,
        accountId: json['account_id']?.toString() ?? '',
        title: json['title'] as String?,
        subtitle: json['subtitle'] as String?,
        caption: json['caption'] as String?,
        artworkUrl:
            json['artwork_url'] as String? ?? json['large_image'] as String?,
        startedAt: _parseTime(json['started_at']),
        leaseExpiresAt: _parseTime(json['lease_expires_at']),
      );

  static DateTime? _parseTime(Object? raw) {
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    return null;
  }
}

/// A resolved share target: a [CatalogItem] plus the public OpenGraph page
/// Blade serves at `/m/:id`.
class MusicShare {
  const MusicShare({required this.item, required this.shareUrl});

  final CatalogItem item;
  final String shareUrl;
}

/// One row of a Pulsar taste summary: a track or a creator, with how many
/// scrobbles and seconds it accounts for in the window.
class PulsarTopEntity {
  const PulsarTopEntity({
    required this.name,
    this.subtitle,
    required this.count,
    required this.seconds,
  });

  final String name;
  final String? subtitle;
  final int count;
  final int seconds;

  factory PulsarTopEntity.fromJson(Map<String, dynamic> json) =>
      PulsarTopEntity(
        name: json['name'] as String? ?? '',
        subtitle: json['subtitle'] as String?,
        count: (json['count'] as num?)?.toInt() ?? 0,
        seconds: (json['seconds'] as num?)?.toInt() ?? 0,
      );
}

/// The account's listening profile from Pulsar's rewind service
/// (`GET /pulsar/stats?domain=music`). Aggregates every scrobble the fleet
/// has: any device, any window the query names.
class PulsarMediaStats {
  const PulsarMediaStats({
    required this.totalScrobbles,
    required this.totalSeconds,
    required this.topItems,
    required this.topCreators,
    required this.daysActive,
  });

  final int totalScrobbles;
  final int totalSeconds;
  final List<PulsarTopEntity> topItems;
  final List<PulsarTopEntity> topCreators;

  /// How many distinct days carry at least one scrobble in the window.
  final int daysActive;

  static List<PulsarTopEntity> _topItems(Object? raw) => [
    for (final entry in (raw as List<dynamic>? ?? const []))
      if (entry is Map<String, dynamic>) PulsarTopEntity.fromJson(entry),
  ];

  factory PulsarMediaStats.fromJson(Map<String, dynamic> json) =>
      PulsarMediaStats(
        totalScrobbles: (json['total_scrobbles'] as num?)?.toInt() ?? 0,
        totalSeconds: (json['total_seconds'] as num?)?.toInt() ?? 0,
        topItems: _topItems(json['top_items']),
        topCreators: _topItems(json['top_creators']),
        daysActive: (json['days_active'] as num?)?.toInt() ?? 0,
      );
}
