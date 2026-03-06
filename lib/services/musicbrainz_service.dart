import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

const _baseUrl = 'https://musicbrainz.org/ws/2';
const _userAgent = 'LoonBox/0.1.0 (contact@loonbox.app)';
const _coverArtBase = 'https://coverartarchive.org';

/// A single recording result from MusicBrainz.
class MusicBrainzRecording {
  final String id;
  final String title;
  final String? artist;
  final String? artistId;
  final String? album;
  final String? releaseId;
  final int? trackNumber;
  final int? year;
  final int? durationMs;
  final int score;

  const MusicBrainzRecording({
    required this.id,
    required this.title,
    this.artist,
    this.artistId,
    this.album,
    this.releaseId,
    this.trackNumber,
    this.year,
    this.durationMs,
    this.score = 0,
  });
}

/// A release result from MusicBrainz (album-level).
class MusicBrainzRelease {
  final String id;
  final String title;
  final String? artist;
  final String? artistId;
  final int? year;
  final int trackCount;
  final int score;
  final List<MusicBrainzRecording> tracks;

  const MusicBrainzRelease({
    required this.id,
    required this.title,
    this.artist,
    this.artistId,
    this.year,
    this.trackCount = 0,
    this.score = 0,
    this.tracks = const [],
  });
}

/// Artist info from MusicBrainz including bio from Wikipedia.
class MusicBrainzArtist {
  final String id;
  final String name;
  final String? type; // Person, Group, etc.
  final String? country;
  final String? beginDate;
  final String? endDate;
  final String? disambiguation;
  final String? wikipediaUrl;
  final String? wikidataId;
  final String? imageUrl;
  final List<String> genres;
  final List<ArtistMember> members;
  final Map<String, String> externalLinks; // type → url

  const MusicBrainzArtist({
    required this.id,
    required this.name,
    this.type,
    this.country,
    this.beginDate,
    this.endDate,
    this.disambiguation,
    this.wikipediaUrl,
    this.wikidataId,
    this.imageUrl,
    this.genres = const [],
    this.members = const [],
    this.externalLinks = const {},
  });
}

/// A member/former member of a group.
class ArtistMember {
  final String name;
  final String? mbid;
  final bool current;
  final String? beginDate;
  final String? endDate;

  const ArtistMember({
    required this.name,
    this.mbid,
    this.current = true,
    this.beginDate,
    this.endDate,
  });
}

/// Artist bio fetched from Wikipedia.
class ArtistBio {
  final String extract;
  final String? fullExtract;
  final String? imageUrl;
  final String? pageUrl;

  const ArtistBio({
    required this.extract,
    this.fullExtract,
    this.imageUrl,
    this.pageUrl,
  });
}

/// REST client for the MusicBrainz API with rate limiting.
class MusicBrainzService {
  final http.Client _client;
  DateTime _lastRequest = DateTime.fromMillisecondsSinceEpoch(0);

  MusicBrainzService([http.Client? client])
      : _client = client ?? http.Client();

  /// Enforce 1 request/second rate limit per MusicBrainz policy.
  Future<void> _rateLimit() async {
    final elapsed = DateTime.now().difference(_lastRequest);
    if (elapsed < const Duration(seconds: 1)) {
      await Future.delayed(const Duration(seconds: 1) - elapsed);
    }
    _lastRequest = DateTime.now();
  }

  /// Search recordings by title, optionally filtered by artist and album.
  Future<List<MusicBrainzRecording>> searchRecordings({
    required String title,
    String? artist,
    String? album,
    int limit = 10,
  }) async {
    await _rateLimit();

    final parts = <String>[];
    parts.add('recording:"${_escape(title)}"');
    if (artist != null && artist.isNotEmpty) {
      parts.add('artist:"${_escape(artist)}"');
    }
    if (album != null && album.isNotEmpty) {
      parts.add('release:"${_escape(album)}"');
    }

    final query = parts.join(' AND ');
    final uri = Uri.parse('$_baseUrl/recording').replace(queryParameters: {
      'query': query,
      'fmt': 'json',
      'limit': '$limit',
    });

    final response = await _client.get(uri, headers: {
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('MusicBrainz API error: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final recordings = json['recordings'] as List<dynamic>? ?? [];

    return recordings.map(_parseRecording).toList();
  }

  /// Search releases (albums) by name, optionally filtered by artist.
  Future<List<MusicBrainzRelease>> searchReleases({
    required String album,
    String? artist,
    int limit = 10,
  }) async {
    await _rateLimit();

    final parts = <String>[];
    parts.add('release:"${_escape(album)}"');
    if (artist != null && artist.isNotEmpty) {
      parts.add('artist:"${_escape(artist)}"');
    }
    // Year filter intentionally omitted — local metadata often has
    // reissue/rip years that don't match MusicBrainz release dates,
    // causing false negatives. Album + artist is sufficient.

    final query = parts.join(' AND ');
    final uri = Uri.parse('$_baseUrl/release').replace(queryParameters: {
      'query': query,
      'fmt': 'json',
      'limit': '$limit',
    });

    debugPrint('[MusicBrainz] Release search: $uri');

    final response = await _client.get(uri, headers: {
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      debugPrint('[MusicBrainz] Error: ${response.statusCode} ${response.body}');
      throw Exception('MusicBrainz API error: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final releases = json['releases'] as List<dynamic>? ?? [];

    debugPrint('[MusicBrainz] Found ${releases.length} releases');
    return releases.map(_parseRelease).toList();
  }

  /// Fetch a release by MBID with full tracklist.
  Future<MusicBrainzRelease> getRelease(String mbid) async {
    await _rateLimit();

    final uri = Uri.parse('$_baseUrl/release/$mbid').replace(queryParameters: {
      'inc': 'recordings+artist-credits',
      'fmt': 'json',
    });

    final response = await _client.get(uri, headers: {
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('MusicBrainz API error: ${response.statusCode}');
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseReleaseDetail(map);
  }

  /// Download cover art for a MusicBrainz release. Returns bytes or null.
  Future<List<int>?> downloadCoverArt(String releaseMbid) async {
    final uri = Uri.parse('$_coverArtBase/release/$releaseMbid/front-500');
    debugPrint('[MusicBrainz] Cover art request: $uri');
    try {
      final response = await _client.get(uri, headers: {
        'User-Agent': _userAgent,
      });
      debugPrint('[MusicBrainz] Cover art response: ${response.statusCode} (${response.bodyBytes.length} bytes)');
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('[MusicBrainz] Cover art error: $e');
    }
    return null;
  }

  MusicBrainzRecording _parseRecording(dynamic r) {
    final map = r as Map<String, dynamic>;

    // First artist credit
    final artistCredits = map['artist-credit'] as List<dynamic>? ?? [];
    final firstArtist = artistCredits.isNotEmpty
        ? artistCredits.first['artist'] as Map<String, dynamic>?
        : null;

    // Build full artist name from credits (handles "feat." etc.)
    String? artistName;
    if (artistCredits.isNotEmpty) {
      final buf = StringBuffer();
      for (final credit in artistCredits) {
        final c = credit as Map<String, dynamic>;
        buf.write(c['artist']?['name'] ?? '');
        if (c['joinphrase'] != null) buf.write(c['joinphrase']);
      }
      artistName = buf.toString();
    }

    // First release
    final releases = map['releases'] as List<dynamic>? ?? [];
    final firstRelease =
        releases.isNotEmpty ? releases.first as Map<String, dynamic> : null;

    // Track number from release media
    int? trackNumber;
    if (firstRelease != null) {
      final media = firstRelease['media'] as List<dynamic>? ?? [];
      if (media.isNotEmpty) {
        final tracks =
            (media.first as Map<String, dynamic>)['track'] as List<dynamic>? ??
                [];
        if (tracks.isNotEmpty) {
          trackNumber = int.tryParse(
            (tracks.first as Map<String, dynamic>)['number']?.toString() ?? '',
          );
        }
      }
    }

    // Year from first release date
    int? year;
    final dateStr = firstRelease?['date']?.toString();
    if (dateStr != null && dateStr.length >= 4) {
      year = int.tryParse(dateStr.substring(0, 4));
    }

    return MusicBrainzRecording(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      artist: artistName ?? firstArtist?['name'] as String?,
      artistId: firstArtist?['id'] as String?,
      album: firstRelease?['title'] as String?,
      releaseId: firstRelease?['id'] as String?,
      trackNumber: trackNumber,
      year: year,
      durationMs: map['length'] as int?,
      score: map['score'] as int? ?? 0,
    );
  }

  MusicBrainzRelease _parseRelease(dynamic r) {
    final map = r as Map<String, dynamic>;

    // Artist from artist-credit
    final artistCredits = map['artist-credit'] as List<dynamic>? ?? [];
    String? artistName;
    String? artistId;
    if (artistCredits.isNotEmpty) {
      final buf = StringBuffer();
      for (final credit in artistCredits) {
        final c = credit as Map<String, dynamic>;
        buf.write(c['artist']?['name'] ?? '');
        if (c['joinphrase'] != null) buf.write(c['joinphrase']);
      }
      artistName = buf.toString();
      artistId = (artistCredits.first['artist'] as Map<String, dynamic>?)?['id'] as String?;
    }

    // Year from date
    int? year;
    final dateStr = map['date']?.toString();
    if (dateStr != null && dateStr.length >= 4) {
      year = int.tryParse(dateStr.substring(0, 4));
    }

    // Track count from media
    int trackCount = 0;
    final media = map['media'] as List<dynamic>? ?? [];
    for (final disc in media) {
      trackCount += (disc as Map<String, dynamic>)['track-count'] as int? ?? 0;
    }

    return MusicBrainzRelease(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      artist: artistName,
      artistId: artistId,
      year: year,
      trackCount: trackCount,
      score: map['score'] as int? ?? 0,
    );
  }

  MusicBrainzRelease _parseReleaseDetail(Map<String, dynamic> map) {
    // Artist
    final artistCredits = map['artist-credit'] as List<dynamic>? ?? [];
    String? artistName;
    String? artistId;
    if (artistCredits.isNotEmpty) {
      final buf = StringBuffer();
      for (final credit in artistCredits) {
        final c = credit as Map<String, dynamic>;
        buf.write(c['artist']?['name'] ?? '');
        if (c['joinphrase'] != null) buf.write(c['joinphrase']);
      }
      artistName = buf.toString();
      artistId = (artistCredits.first['artist'] as Map<String, dynamic>?)?['id'] as String?;
    }

    // Year
    int? year;
    final dateStr = map['date']?.toString();
    if (dateStr != null && dateStr.length >= 4) {
      year = int.tryParse(dateStr.substring(0, 4));
    }

    // Parse tracks from media
    final tracks = <MusicBrainzRecording>[];
    final media = map['media'] as List<dynamic>? ?? [];
    int totalTrackCount = 0;
    for (final disc in media) {
      final discMap = disc as Map<String, dynamic>;
      totalTrackCount += discMap['track-count'] as int? ?? 0;
      final discTracks = discMap['tracks'] as List<dynamic>? ?? [];
      for (final t in discTracks) {
        final tMap = t as Map<String, dynamic>;
        final recording = tMap['recording'] as Map<String, dynamic>? ?? {};

        // Track-level artist credit (falls back to release artist)
        final trackArtistCredits = recording['artist-credit'] as List<dynamic>? ?? artistCredits;
        String? trackArtist;
        String? trackArtistId;
        if (trackArtistCredits.isNotEmpty) {
          final buf = StringBuffer();
          for (final credit in trackArtistCredits) {
            final c = credit as Map<String, dynamic>;
            buf.write(c['artist']?['name'] ?? '');
            if (c['joinphrase'] != null) buf.write(c['joinphrase']);
          }
          trackArtist = buf.toString();
          trackArtistId = (trackArtistCredits.first['artist'] as Map<String, dynamic>?)?['id'] as String?;
        }

        tracks.add(MusicBrainzRecording(
          id: recording['id'] as String? ?? '',
          title: recording['title'] as String? ?? tMap['title'] as String? ?? '',
          artist: trackArtist ?? artistName,
          artistId: trackArtistId ?? artistId,
          album: map['title'] as String?,
          releaseId: map['id'] as String?,
          trackNumber: int.tryParse(tMap['number']?.toString() ?? ''),
          year: year,
          durationMs: recording['length'] as int? ?? tMap['length'] as int?,
          score: 100, // Detail fetch — no search score
        ));
      }
    }

    return MusicBrainzRelease(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      artist: artistName,
      artistId: artistId,
      year: year,
      trackCount: totalTrackCount,
      tracks: tracks,
    );
  }

  /// Fetch artist details from MusicBrainz by MBID, including Wikipedia links.
  Future<MusicBrainzArtist> getArtist(String mbid) async {
    await _rateLimit();

    final uri = Uri.parse('$_baseUrl/artist/$mbid').replace(queryParameters: {
      'inc': 'url-rels+artist-rels+genres',
      'fmt': 'json',
    });

    final response = await _client.get(uri, headers: {
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) {
      throw Exception('MusicBrainz API error: ${response.statusCode}');
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return _parseArtist(map);
  }

  /// Search for an artist by name. Returns the best match MBID.
  Future<MusicBrainzArtist?> searchArtist(String name) async {
    await _rateLimit();

    final uri = Uri.parse('$_baseUrl/artist').replace(queryParameters: {
      'query': 'artist:"${_escape(name)}"',
      'fmt': 'json',
      'limit': '1',
    });

    final response = await _client.get(uri, headers: {
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    });

    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final artists = json['artists'] as List<dynamic>? ?? [];
    if (artists.isEmpty) return null;

    final best = artists.first as Map<String, dynamic>;
    final score = best['score'] as int? ?? 0;
    if (score < 80) return null;

    // Fetch full details with URL relations
    return getArtist(best['id'] as String);
  }

  /// Fetch artist bio extract from Wikipedia via their REST API.
  Future<ArtistBio?> getWikipediaBio(String wikipediaUrl) async {
    // Extract the title from the Wikipedia URL
    // e.g. https://en.wikipedia.org/wiki/Radiohead -> Radiohead
    final wikiUri = Uri.tryParse(wikipediaUrl);
    if (wikiUri == null) return null;

    final pathSegments = wikiUri.pathSegments;
    if (pathSegments.length < 2 || pathSegments[0] != 'wiki') return null;

    final title = pathSegments.sublist(1).join('/');
    final lang = wikiUri.host.split('.').first; // 'en' from 'en.wikipedia.org'

    // Use Wikipedia REST API for a page summary
    final apiUri = Uri.parse('https://$lang.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title)}');

    try {
      final response = await _client.get(apiUri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
      });

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final extract = json['extract'] as String?;
      if (extract == null || extract.isEmpty) return null;

      // Get the thumbnail image if available
      final thumbnail = json['thumbnail'] as Map<String, dynamic>?;
      final imageUrl = thumbnail?['source'] as String?;
      final pageUrl = json['content_urls']?['desktop']?['page'] as String?;

      // Fetch full intro section via MediaWiki API
      String? fullExtract;
      try {
        final fullUri = Uri.parse(
          'https://$lang.wikipedia.org/w/api.php'
        ).replace(queryParameters: {
          'action': 'query',
          'titles': title,
          'prop': 'extracts',
          'exintro': '1',
          'explaintext': '1',
          'format': 'json',
        });
        final fullResp = await _client.get(fullUri, headers: {
          'User-Agent': _userAgent,
        });
        if (fullResp.statusCode == 200) {
          final fullJson = jsonDecode(fullResp.body) as Map<String, dynamic>;
          final pages = fullJson['query']?['pages'] as Map<String, dynamic>?;
          if (pages != null && pages.isNotEmpty) {
            final page = pages.values.first as Map<String, dynamic>;
            fullExtract = page['extract'] as String?;
          }
        }
      } catch (_) {}

      return ArtistBio(
        extract: extract,
        fullExtract: fullExtract,
        imageUrl: imageUrl,
        pageUrl: pageUrl,
      );
    } catch (e) {
      debugPrint('[MusicBrainz] Wikipedia fetch error: $e');
      return null;
    }
  }

  /// Fetch Wikidata image URL for an artist.
  Future<String?> getWikidataImage(String wikidataId) async {
    final uri = Uri.parse('https://www.wikidata.org/wiki/Special:EntityData/$wikidataId.json');

    try {
      final response = await _client.get(uri, headers: {
        'User-Agent': _userAgent,
      });

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final entities = json['entities'] as Map<String, dynamic>?;
      final entity = entities?[wikidataId] as Map<String, dynamic>?;
      final claims = entity?['claims'] as Map<String, dynamic>?;

      // P18 is the "image" property in Wikidata
      final imageClaimList = claims?['P18'] as List<dynamic>?;
      if (imageClaimList == null || imageClaimList.isEmpty) return null;

      final imageName = imageClaimList.first['mainsnak']?['datavalue']?['value'] as String?;
      if (imageName == null) return null;

      // Construct Wikimedia Commons thumbnail URL
      final encoded = Uri.encodeComponent(imageName.replaceAll(' ', '_'));
      return 'https://commons.wikimedia.org/wiki/Special:FilePath/$encoded?width=400';
    } catch (e) {
      debugPrint('[MusicBrainz] Wikidata image error: $e');
      return null;
    }
  }

  MusicBrainzArtist _parseArtist(Map<String, dynamic> map) {
    String? wikipediaUrl;
    String? wikidataId;
    String? imageUrl;
    final externalLinks = <String, String>{};
    final members = <ArtistMember>[];

    final relations = map['relations'] as List<dynamic>? ?? [];
    for (final rel in relations) {
      final r = rel as Map<String, dynamic>;
      final type = r['type'] as String?;
      final targetType = r['target-type'] as String?;

      // URL relations
      if (targetType == 'url') {
        final url = (r['url'] as Map<String, dynamic>?)?['resource'] as String?;
        if (url == null || type == null) continue;

        if (type == 'wikipedia') {
          wikipediaUrl = url;
        } else if (type == 'wikidata') {
          final wdUri = Uri.tryParse(url);
          if (wdUri != null && wdUri.pathSegments.isNotEmpty) {
            wikidataId = wdUri.pathSegments.last;
          }
        } else if (type == 'image') {
          imageUrl = url;
        }
        // Collect interesting external links
        if (const {'official homepage', 'bandcamp', 'soundcloud', 'youtube',
            'social network', 'streaming', 'discogs', 'allmusic', 'last.fm',
            'setlist.fm', 'IMDb'}.contains(type)) {
          externalLinks[type] = url;
        }
      }

      // Artist-to-artist relations (band members)
      if (targetType == 'artist' && type == 'member of band') {
        final direction = r['direction'] as String?;
        // direction == 'backward' means "this artist has member X"
        if (direction == 'backward') {
          final memberArtist = r['artist'] as Map<String, dynamic>?;
          if (memberArtist != null) {
            final lifeSpan = r['begin'] as String?;
            final endSpan = r['end'] as String?;
            final ended = r['ended'] as bool? ?? false;
            members.add(ArtistMember(
              name: memberArtist['name'] as String? ?? '',
              mbid: memberArtist['id'] as String?,
              current: !ended,
              beginDate: lifeSpan,
              endDate: endSpan,
            ));
          }
        }
      }
    }

    // Genres
    final genresList = map['genres'] as List<dynamic>? ?? [];
    final genres = genresList
        .map((g) => (g as Map<String, dynamic>)['name'] as String? ?? '')
        .where((g) => g.isNotEmpty)
        .toList()
      ..sort((a, b) {
        // Sort by count descending (most popular genre first)
        final aCount = genresList.firstWhere(
          (g) => (g as Map<String, dynamic>)['name'] == a,
          orElse: () => {'count': 0},
        ) as Map<String, dynamic>;
        final bCount = genresList.firstWhere(
          (g) => (g as Map<String, dynamic>)['name'] == b,
          orElse: () => {'count': 0},
        ) as Map<String, dynamic>;
        return (bCount['count'] as int? ?? 0).compareTo(aCount['count'] as int? ?? 0);
      });

    final lifeSpan = map['life-span'] as Map<String, dynamic>?;

    return MusicBrainzArtist(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      type: map['type'] as String?,
      country: map['country'] as String?,
      beginDate: lifeSpan?['begin'] as String?,
      endDate: (lifeSpan?['ended'] == true) ? (lifeSpan?['end'] as String?) : null,
      disambiguation: map['disambiguation'] as String?,
      wikipediaUrl: wikipediaUrl,
      wikidataId: wikidataId,
      imageUrl: imageUrl,
      genres: genres,
      members: members,
      externalLinks: externalLinks,
    );
  }

  /// Escape characters for MusicBrainz quoted search queries.
  /// Inside double quotes, only " and \ need escaping.
  String _escape(String s) => s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  void dispose() => _client.close();
}

final musicBrainzServiceProvider = Provider<MusicBrainzService>((ref) {
  final service = MusicBrainzService();
  ref.onDispose(() => service.dispose());
  return service;
});
