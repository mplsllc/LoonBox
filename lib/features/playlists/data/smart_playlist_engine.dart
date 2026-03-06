import 'package:drift/drift.dart' hide Column;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/database.dart';
import '../domain/smart_playlist.dart';

/// Translates SmartPlaylist rules into Drift queries and returns matching tracks.
class SmartPlaylistEngine {
  SmartPlaylistEngine(this._db);

  final LoonBoxDatabase _db;

  /// Evaluate a smart playlist and return matching tracks.
  Future<List<Track>> evaluate(SmartPlaylist playlist) async {
    var query = _db.select(_db.tracks);

    // Apply rules as WHERE clauses
    if (playlist.rules.isNotEmpty) {
      query = query
        ..where((t) {
          final expressions = playlist.rules
              .map((rule) => _buildExpression(t, rule))
              .whereType<Expression<bool>>()
              .toList();

          if (expressions.isEmpty) return const Constant(true);

          return switch (playlist.matchMode) {
            MatchMode.all => expressions.reduce((a, b) => a & b),
            MatchMode.any => expressions.reduce((a, b) => a | b),
            MatchMode.advanced => expressions.reduce((a, b) => a & b),
          };
        });
    }

    // Apply sort
    if (playlist.sortField != null) {
      final ascending = playlist.sortOrder != SortOrder.desc;
      final sortField = playlist.sortField!;
      query = query
        ..orderBy([
          (t) {
            final col = _getColumn(t, sortField);
            if (col == null) return OrderingTerm.asc(t.title);
            return OrderingTerm(
              expression: col,
              mode: ascending ? OrderingMode.asc : OrderingMode.desc,
            );
          },
        ]);
    }

    // Apply limit
    if (playlist.limitCount != null && playlist.limitUnit == LimitUnit.tracks) {
      query = query..limit(playlist.limitCount!);
    }

    return query.get();
  }

  /// Create a smart playlist and persist it.
  Future<int> createSmartPlaylist(SmartPlaylist playlist) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.into(_db.playlists).insert(PlaylistsCompanion.insert(
          name: playlist.name,
          description: Value(playlist.description),
          isSmart: const Value(true),
          smartRules: Value(playlist.rulesJson),
          sortField: Value(playlist.sortField),
          sortOrder: Value(playlist.sortOrder?.name),
          limitCount: Value(playlist.limitCount),
          limitUnit: Value(playlist.limitUnit?.name),
          liveUpdate: Value(playlist.liveUpdate),
          createdAt: now,
          updatedAt: now,
        ));
  }

  /// Load a SmartPlaylist from a DB row.
  SmartPlaylist fromRow(Playlist row) {
    return SmartPlaylist(
      id: row.id,
      name: row.name,
      description: row.description,
      matchMode: MatchMode.all,
      rules: row.smartRules != null ? SmartPlaylist.parseRules(row.smartRules!) : [],
      sortField: row.sortField,
      sortOrder: row.sortOrder != null ? SortOrder.values.byName(row.sortOrder!) : null,
      limitCount: row.limitCount,
      limitUnit: row.limitUnit != null ? LimitUnit.values.byName(row.limitUnit!) : null,
      liveUpdate: row.liveUpdate,
      trackCount: row.trackCount,
    );
  }

  Expression<bool>? _buildExpression($TracksTable t, SmartRule rule) {
    return switch (rule.operator) {
      RuleOperator.contains => _textCol(t, rule.field)?.like('%${rule.value}%'),
      RuleOperator.doesNotContain => _textCol(t, rule.field)?.like('%${rule.value}%').not(),
      RuleOperator.isEqualTo => _textCol(t, rule.field)?.equals(rule.value.toString()),
      RuleOperator.isNot => _textCol(t, rule.field)?.equals(rule.value.toString()).not(),
      RuleOperator.startsWith => _textCol(t, rule.field)?.like('${rule.value}%'),
      RuleOperator.endsWith => _textCol(t, rule.field)?.like('%${rule.value}'),
      RuleOperator.greaterThan => _intCol(t, rule.field)?.isBiggerThanValue((rule.value as num).toInt()),
      RuleOperator.lessThan => _intCol(t, rule.field)?.isSmallerThanValue((rule.value as num).toInt()),
      RuleOperator.isBlank => () {
          final col = _textCol(t, rule.field);
          if (col == null) return null;
          return col.equals('') | col.isNull();
        }(),
      RuleOperator.isNotBlank => () {
          final col = _textCol(t, rule.field);
          if (col == null) return null;
          return col.equals('').not() & col.isNotNull();
        }(),
      RuleOperator.isTrue => _boolCol(t, rule.field)?.equals(true),
      RuleOperator.isFalse => _boolCol(t, rule.field)?.equals(false),
      _ => null, // matchesRegex, inRange, date operators — later
    };
  }

  GeneratedColumn? _getColumn($TracksTable t, String fieldName) {
    return switch (fieldName) {
      'title' => t.title,
      'artist' => t.artist,
      'albumArtist' => t.albumArtist,
      'album' => t.album,
      'genre' => t.genre,
      'year' => t.year,
      'trackNumber' => t.trackNumber,
      'discNumber' => t.discNumber,
      'duration' => t.durationMs,
      'rating' => t.rating,
      'playCount' => t.playCount,
      'skipCount' => t.skipCount,
      'dateAdded' => t.dateAdded,
      'lastPlayed' => t.lastPlayedAt,
      'lastSkipped' => t.lastSkippedAt,
      'fileSize' => t.fileSize,
      'bitrate' => t.bitrate,
      'sampleRate' => t.sampleRate,
      'bitDepth' => t.bitDepth,
      'filePath' => t.filePath,
      'codec' => t.codec,
      'hasAlbumArt' => t.hasAlbumArt,
      'comment' => t.comment,
      'bpm' => t.bpm,
      'loved' => t.loved,
      _ => null,
    };
  }

  GeneratedColumn<String>? _textCol($TracksTable t, RuleField field) {
    return switch (field) {
      RuleField.title => t.title,
      RuleField.artist => t.artist,
      RuleField.albumArtist => t.albumArtist,
      RuleField.album => t.album,
      RuleField.genre => t.genre,
      RuleField.filePath => t.filePath,
      RuleField.codec => t.codec,
      RuleField.comment => t.comment,
      _ => null,
    };
  }

  GeneratedColumn<int>? _intCol($TracksTable t, RuleField field) {
    return switch (field) {
      RuleField.year => t.year,
      RuleField.trackNumber => t.trackNumber,
      RuleField.discNumber => t.discNumber,
      RuleField.duration => t.durationMs,
      RuleField.rating => t.rating,
      RuleField.playCount => t.playCount,
      RuleField.skipCount => t.skipCount,
      RuleField.dateAdded => t.dateAdded,
      RuleField.lastPlayed => t.lastPlayedAt,
      RuleField.lastSkipped => t.lastSkippedAt,
      RuleField.fileSize => t.fileSize,
      RuleField.bitrate => t.bitrate,
      RuleField.sampleRate => t.sampleRate,
      RuleField.bitDepth => t.bitDepth,
      _ => null,
    };
  }

  GeneratedColumn<bool>? _boolCol($TracksTable t, RuleField field) {
    return switch (field) {
      RuleField.hasAlbumArt => t.hasAlbumArt,
      RuleField.loved => t.loved,
      _ => null,
    };
  }
}

final smartPlaylistEngineProvider = Provider<SmartPlaylistEngine>((ref) {
  return SmartPlaylistEngine(ref.watch(databaseProvider));
});
