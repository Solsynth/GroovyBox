/// The fleet's answer for one artist or album page: the catalog record a
/// MusicBrainz resolve produced, with the biography, portrait and
/// discography (or tracklist) Pulsar cached alongside it.
///
/// The app never talks to MusicBrainz: the fleet does, once, and every device
/// reads the same row. So this is a read-through mirror of `UnifiedMedia` in
/// LightHouse's `internal/pulsar/metadata/types.go`.
library;

import 'models.dart';

/// A link off the record: MusicBrainz, Wikipedia, the artist's own site.
class PulsarExternalLink {
  const PulsarExternalLink({
    required this.platform,
    required this.label,
    required this.url,
  });

  final String platform;
  final String label;
  final String url;

  static List<PulsarExternalLink> listOf(Object? raw) => [
    for (final entry in (raw as List<dynamic>? ?? const []))
      if (entry is Map<String, dynamic>)
        PulsarExternalLink(
          platform: entry['platform'] as String? ?? '',
          label: entry['label'] as String? ?? '',
          url: entry['url'] as String? ?? '',
        ),
  ];

  /// The first link whose platform is in [platforms], or null.
  static PulsarExternalLink? firstOf(
    List<PulsarExternalLink> links,
    Set<String> platforms,
  ) {
    for (final link in links) {
      if (platforms.contains(link.platform)) return link;
    }
    return null;
  }
}

/// What MusicBrainz knows about a person or group beyond the name.
class PulsarArtistProfile {
  const PulsarArtistProfile({
    this.mbid,
    this.type,
    this.sortName,
    this.disambiguation,
    this.country,
    this.area,
    this.beginArea,
    this.born,
    this.died,
    this.genres = const [],
    this.url,
  });

  final String? mbid;

  /// "Person", "Group", "Orchestra", "Choir", or null when untyped.
  final String? type;
  final String? sortName;
  final String? disambiguation;
  final String? country;
  final String? area;
  final String? beginArea;

  /// Full dates ("1981-07-03") or bare years ("1991"): a birth and death for
  /// a person, a formation and dissolution for a group.
  final String? born;
  final String? died;
  final List<String> genres;
  final String? url;

  factory PulsarArtistProfile.fromJson(Map<String, dynamic> json) =>
      PulsarArtistProfile(
        mbid: json['mbid'] as String?,
        type: json['type'] as String?,
        sortName: json['sort_name'] as String?,
        disambiguation: json['disambiguation'] as String?,
        country: json['country'] as String?,
        area: json['area'] as String?,
        beginArea: json['begin_area'] as String?,
        born: json['born'] as String?,
        died: json['died'] as String?,
        genres: ((json['genres'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        url: json['url'] as String?,
      );
}

/// One track of an album, in disc and track order.
class PulsarAlbumTrack {
  const PulsarAlbumTrack({
    this.recordingMbid,
    required this.title,
    this.artist,
    this.disc = 1,
    this.position = 0,
    this.lengthMs = 0,
  });

  final String? recordingMbid;
  final String title;
  final String? artist;
  final int disc;
  final int position;
  final int lengthMs;

  Duration get length => Duration(milliseconds: lengthMs);

  factory PulsarAlbumTrack.fromJson(Map<String, dynamic> json) =>
      PulsarAlbumTrack(
        recordingMbid: json['recording_mbid'] as String?,
        title: json['title'] as String? ?? '',
        artist: json['artist'] as String?,
        disc: (json['disc'] as num?)?.toInt() ?? 1,
        position: (json['position'] as num?)?.toInt() ?? 0,
        lengthMs: (json['length_ms'] as num?)?.toInt() ?? 0,
      );
}

/// One record in an artist's discography.
class PulsarAlbumSummary {
  const PulsarAlbumSummary({
    required this.mbid,
    required this.title,
    this.year,
    this.type,
    this.artworkUrl,
  });

  final String mbid;
  final String title;
  final int? year;

  /// "Album", "Single", "EP", or a compound like "Album + Live".
  final String? type;
  final String? artworkUrl;

  factory PulsarAlbumSummary.fromJson(Map<String, dynamic> json) =>
      PulsarAlbumSummary(
        mbid: json['mbid'] as String? ?? '',
        title: json['title'] as String? ?? '',
        year: (json['year'] as num?)?.toInt(),
        type: json['type'] as String?,
        artworkUrl: json['artwork_url'] as String?,
      );
}

/// A resolved artist or album, as `GET /pulsar/metadata/artist|album`
/// answers it.
///
/// One type for both: the two pages draw the same record, and they differ
/// only in which of [albums], [tracks] and [artist] are filled.
class PulsarEntityMetadata {
  const PulsarEntityMetadata({
    this.id,
    this.urn,
    this.domain = 'music',
    this.slug,
    required this.title,
    this.subtitle,
    this.caption,
    this.description,
    this.artworkUrl,
    this.imageUrl,
    this.bannerUrl,
    this.durationSeconds,
    this.releaseDate,
    this.genres = const [],
    this.creators = const [],
    this.externalLinks = const [],
    this.artist,
    this.tracks = const [],
    this.albums = const [],
    this.releaseGroupCount = 0,
    this.bio,
    this.bioSource,
    this.shareUrl,
    this.scrobbleCount = 0,
    this.activeListenerCount = 0,
  });

  final String? id;
  final String? urn;
  final String domain;
  final String? slug;
  final String title;
  final String? subtitle;
  final String? caption;

  /// The album's own description, when it has one.
  final String? description;

  /// The cover: an album's front image, or an artist's portrait.
  final String? artworkUrl;
  final String? imageUrl;
  final String? bannerUrl;
  final int? durationSeconds;
  final String? releaseDate;
  final List<String> genres;
  final List<PulsarCreatorCredit> creators;
  final List<PulsarExternalLink> externalLinks;

  /// Filled on an artist resolve.
  final PulsarArtistProfile? artist;

  /// Filled on an album resolve.
  final List<PulsarAlbumTrack> tracks;
  final List<PulsarAlbumSummary> albums;
  final int releaseGroupCount;

  /// The prose a page shows: an artist's biography, an album's summary.
  final String? bio;
  final String? bioSource;
  final String? shareUrl;
  final int scrobbleCount;
  final int activeListenerCount;

  /// The longest description the record carries: the biography on an artist,
  /// the article extract on an album.
  String? get prose {
    if (bio != null && bio!.trim().isNotEmpty) return bio;
    if (description != null && description!.trim().isNotEmpty) {
      return description;
    }
    return null;
  }

  /// Who wrote the prose, e.g. "EN Wikipedia"; null when it has no source.
  String? get proseSource =>
      (bio != null && bio!.trim().isNotEmpty) ? bioSource : null;

  /// "1981" or "1985 – 1991": a life span, or a group's years together.
  String? get lifespan {
    final profile = artist;
    final born = profile?.born;
    if (born == null || born.trim().isEmpty) return null;
    final died = profile?.died;
    if (died == null || died.trim().isEmpty) return born;
    return '$born – $died';
  }

  /// Where the act is from: an area, else a country code.
  String? get origin {
    final profile = artist;
    final area = profile?.area;
    if (area != null && area.trim().isNotEmpty) return area;
    final country = profile?.country;
    return (country != null && country.trim().isNotEmpty) ? country : null;
  }

  /// The link a "read more" opens, when the record carries one.
  PulsarExternalLink? get wikipedia =>
      PulsarExternalLink.firstOf(externalLinks, const {'wikipedia'});

  factory PulsarEntityMetadata.fromJson(Map<String, dynamic> json) =>
      PulsarEntityMetadata(
        id: json['id']?.toString(),
        urn: json['urn'] as String?,
        domain: json['domain'] as String? ?? 'music',
        slug: json['slug'] as String?,
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String?,
        caption: json['caption'] as String?,
        description: json['description'] as String?,
        artworkUrl: json['artwork_url'] as String?,
        imageUrl: json['image_url'] as String?,
        bannerUrl: json['banner_url'] as String?,
        durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
        releaseDate: json['release_date'] as String?,
        genres: ((json['genres'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        creators: PulsarCreatorCredit.listOf(json['creators']),
        externalLinks: PulsarExternalLink.listOf(json['external_links']),
        artist: switch (json['artist']) {
          final Map<String, dynamic> profile => PulsarArtistProfile.fromJson(
            profile,
          ),
          final Map profile => PulsarArtistProfile.fromJson(
            Map<String, dynamic>.from(profile),
          ),
          _ => null,
        },
        tracks: ((json['tracks'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PulsarAlbumTrack.fromJson)
            .toList(),
        albums: ((json['albums'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PulsarAlbumSummary.fromJson)
            .toList(),
        releaseGroupCount: (json['release_group_count'] as num?)?.toInt() ?? 0,
        bio: json['bio'] as String?,
        bioSource: json['bio_source'] as String?,
        shareUrl: json['share_url'] as String?,
        scrobbleCount: (json['scrobble_count'] as num?)?.toInt() ?? 0,
        activeListenerCount:
            (json['active_listener_count'] as num?)?.toInt() ?? 0,
      );
}
