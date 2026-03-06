import 'dart:convert';

/// Match mode for smart playlist rules.
enum MatchMode { all, any, advanced }

/// How to limit results.
enum LimitUnit { tracks, minutes, mb }

/// Sort order.
enum SortOrder { asc, desc }

/// A field that a smart playlist rule can test.
enum RuleField {
  title,
  artist,
  albumArtist,
  album,
  genre,
  year,
  trackNumber,
  discNumber,
  duration,
  rating,
  playCount,
  skipCount,
  dateAdded,
  lastPlayed,
  lastSkipped,
  fileSize,
  bitrate,
  sampleRate,
  bitDepth,
  filePath,
  codec,
  hasAlbumArt,
  comment,
  bpm,
  loved,
}

/// An operator for smart playlist condition evaluation.
enum RuleOperator {
  contains,
  doesNotContain,
  isEqualTo,
  isNot,
  startsWith,
  endsWith,
  matchesRegex,
  greaterThan,
  lessThan,
  inRange,
  isBlank,
  isNotBlank,
  isTrue,
  isFalse,
  inTheLast,
  notInTheLast,
  before,
  after,
  between,
}

/// A single condition in a smart playlist.
class SmartRule {
  const SmartRule({
    required this.field,
    required this.operator,
    this.value,
    this.value2,
    this.unit,
  });

  final RuleField field;
  final RuleOperator operator;

  /// Primary value for comparison.
  final dynamic value;

  /// Second value for range operators (BETWEEN, inRange).
  final dynamic value2;

  /// Unit for date operators (days, weeks, months).
  final String? unit;

  Map<String, dynamic> toJson() => {
        'field': field.name,
        'operator': operator.name,
        'value': value,
        'value2': value2,
        'unit': unit,
      };

  factory SmartRule.fromJson(Map<String, dynamic> json) => SmartRule(
        field: RuleField.values.byName(json['field'] as String),
        operator: RuleOperator.values.byName(json['operator'] as String),
        value: json['value'],
        value2: json['value2'],
        unit: json['unit'] as String?,
      );
}

/// A smart playlist definition.
class SmartPlaylist {
  const SmartPlaylist({
    this.id,
    required this.name,
    this.description,
    this.matchMode = MatchMode.all,
    this.rules = const [],
    this.sortField,
    this.sortOrder,
    this.limitCount,
    this.limitUnit,
    this.liveUpdate = true,
    this.createdAt,
    this.updatedAt,
    this.trackCount = 0,
  });

  final int? id;
  final String name;
  final String? description;
  final MatchMode matchMode;
  final List<SmartRule> rules;
  final String? sortField;
  final SortOrder? sortOrder;
  final int? limitCount;
  final LimitUnit? limitUnit;
  final bool liveUpdate;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int trackCount;

  String get rulesJson => jsonEncode(rules.map((r) => r.toJson()).toList());

  static List<SmartRule> parseRules(String json) {
    final list = jsonDecode(json) as List;
    return list
        .map((e) => SmartRule.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
