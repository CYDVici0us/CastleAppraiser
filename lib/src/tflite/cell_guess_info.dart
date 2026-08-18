import 'package:btcc/src/models/enums/tile_labels.dart';

/// Session-only ML confidence for a grid cell (not persisted in Hive).
enum GuessConfidenceLevel {
  high,
  medium,
  low,
  unidentified,
}

/// Per-cell detection metadata for Confirm / review (discarded on save).
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
}
