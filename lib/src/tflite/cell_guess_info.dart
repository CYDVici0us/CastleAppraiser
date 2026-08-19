import 'package:btcc/src/models/enums/tile_labels.dart';

/// ML confidence for a grid cell.
enum GuessConfidenceLevel {
  high,
  medium,
  low,
  unidentified,
}

/// Per-cell detection metadata for Confirm / review.
///
/// Debug builds persist this with the castle (Hive) and include it in fixture
/// export. Release builds never write it.
class CellGuessInfo {
  final double score;
  final double coverage;
  final bool unidentified;
  final List<TileLabels> alternatives;

  const CellGuessInfo({
    this.score = 0,
    this.coverage = 0,
    this.unidentified = false,
    this.alternatives = const [],
  });

  GuessConfidenceLevel get level {
    if (unidentified) return GuessConfidenceLevel.unidentified;
    if (score >= 0.45 && coverage >= 0.4) return GuessConfidenceLevel.high;
    if (score >= 0.22) return GuessConfidenceLevel.medium;
    return GuessConfidenceLevel.low;
  }

  bool get needsReview =>
      unidentified || level == GuessConfidenceLevel.low || level == GuessConfidenceLevel.medium;

  String get _scorePercent => '${(score * 100).round()}%';

  String get reviewHint {
    if (unidentified || level == GuessConfidenceLevel.unidentified) {
      return 'Unidentified — confirm this cell';
    }
    switch (level) {
      case GuessConfidenceLevel.high:
        return 'High confidence from scan ($_scorePercent)';
      case GuessConfidenceLevel.medium:
        return 'Medium confidence ($_scorePercent) — worth a look';
      case GuessConfidenceLevel.low:
        return 'Low confidence ($_scorePercent) — check this tile';
      case GuessConfidenceLevel.unidentified:
        return 'Unidentified — confirm this cell';
    }
  }

  CellGuessInfo copyWith({
    double? score,
    double? coverage,
    bool? unidentified,
    List<TileLabels>? alternatives,
  }) {
    return CellGuessInfo(
      score: score ?? this.score,
      coverage: coverage ?? this.coverage,
      unidentified: unidentified ?? this.unidentified,
      alternatives: alternatives ?? this.alternatives,
    );
  }

  static CellGuessInfo unidentifiedCell({List<TileLabels> alternatives = const []}) {
    return CellGuessInfo(
      score: 0,
      coverage: 0,
      unidentified: true,
      alternatives: alternatives,
    );
  }

  static CellGuessInfo fromGuess({
    required double score,
    required double coverage,
    List<TileLabels> alternatives = const [],
  }) {
    return CellGuessInfo(
      score: score,
      coverage: coverage,
      alternatives: alternatives,
    );
  }

  Map<String, Object?> toJson() => {
        'score': score,
        'coverage': coverage,
        'unidentified': unidentified,
        'level': level.name,
        if (alternatives.isNotEmpty)
          'alternatives': [for (final label in alternatives) label.name],
      };

  factory CellGuessInfo.fromJson(Map json) {
    final altsRaw = json['alternatives'] as List<dynamic>? ?? const [];
    final alternatives = <TileLabels>[];
    for (final raw in altsRaw) {
      final label = _labelNamed(raw.toString());
      if (label != null) alternatives.add(label);
    }
    return CellGuessInfo(
      score: (json['score'] as num?)?.toDouble() ?? 0,
      coverage: (json['coverage'] as num?)?.toDouble() ?? 0,
      unidentified: json['unidentified'] as bool? ?? false,
      alternatives: alternatives,
    );
  }

  static TileLabels? _labelNamed(String name) {
    for (final label in TileLabels.values) {
      if (label.name == name) return label;
    }
    return null;
  }
}
