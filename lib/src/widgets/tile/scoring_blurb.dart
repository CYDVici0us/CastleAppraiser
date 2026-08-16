import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/token_tile_grid.dart';
import 'package:btcc/src/widgets/tile/tile_type_widget.dart';
import 'package:flutter/material.dart';

/// Maps a scoring condition to a room-category icon, when applicable.
TileType? tileTypeForScoringCondition(ScoringCondition condition) {
  switch (condition) {
    case ScoringCondition.Food:
      return TileType.Food;
    case ScoringCondition.Living:
      return TileType.Living;
    case ScoringCondition.Utility:
      return TileType.Utility;
    case ScoringCondition.Outdoor:
      return TileType.Outdoor;
    case ScoringCondition.Sleeping:
      return TileType.Sleeping;
    case ScoringCondition.Corridor:
      return TileType.Corridor;
    case ScoringCondition.Downstairs:
      return TileType.Downstairs;
    case ScoringCondition.Secret:
      return TileType.Secret;
    case ScoringCondition.Activity:
      return TileType.Activity;
    case ScoringCondition.Special:
      return TileType.Special;
    default:
      return null;
  }
}

bool _hasCategoryImage(TileType type) {
  switch (type) {
    case TileType.Corridor:
    case TileType.Downstairs:
    case TileType.Food:
    case TileType.Living:
    case TileType.Outdoor:
    case TileType.Sleeping:
    case TileType.Utility:
    case TileType.Secret:
    case TileType.Activity:
      return true;
    default:
      return false;
  }
}

String _enumLabel(Object value) => value.toString().split('.').last;

String _conditionLabel(ScoringCondition c) =>
    TokenTileGrid.humanizeCamelCase(_enumLabel(c));

/// One run of scoring copy; optional [category] inserts that icon before [text].
class _ScoringRun {
  final String text;
  final TileType? category;

  const _ScoringRun(this.text, {this.category});
}

/// Scoring description with inline category icons (picker + details).
class ScoringBlurb extends StatelessWidget {
  final Tile tile;
  final TextStyle? style;
  final TextAlign textAlign;
  final double iconScale;
  /// When false, ornament text (Torch/Mirror/…) is omitted from the blurb.
  final bool includeDecoration;

  const ScoringBlurb({
    super.key,
    required this.tile,
    this.style,
    this.textAlign = TextAlign.start,
    this.iconScale = 0.28,
    this.includeDecoration = true,
  });

  /// Whether this tile has any scoring blurb to show.
  static bool hasContent(Tile tile, {bool includeDecoration = true}) =>
      _runsFor(tile, includeDecoration: includeDecoration).isNotEmpty;

  static List<_ScoringRun> _runsFor(
    Tile tile, {
    bool includeDecoration = true,
  }) {
    if (tile.isEmpty() || tile.isPlaceholder()) return const [];

    // Secrets copy another room for scoring only; UI always shows the arrow.
    if (tile.isSecret()) return const [];

    if (tile.isThroneRoom()) {
      return _throneRuns(tile);
    }
    if (tile.isRoyalAttendant()) {
      return _attendantRuns(tile);
    }
    if (tile.isBonusCard()) {
      return _bonusRuns(tile);
    }
    if (tile.tileType == TileType.Special) {
      return _specialRuns(tile);
    }
    return _standardRuns(tile, includeDecoration: includeDecoration);
  }

  static List<_ScoringRun> _throneRuns(Tile tile) {
    final cats = <ScoringCondition>[];
    if (tile.scoringCondition != ScoringCondition.None) {
      cats.add(tile.scoringCondition);
    }
    if (tile.throneRoomCondition != ScoringCondition.None) {
      cats.add(tile.throneRoomCondition);
    }
    if (cats.isEmpty) return const [];

    final runs = <_ScoringRun>[_ScoringRun('+${tile.scorePer} per ')];
    for (var i = 0; i < cats.length; i++) {
      if (i > 0) runs.add(const _ScoringRun(' or '));
      final label = _conditionLabel(cats[i]);
      runs.add(_ScoringRun(label, category: tileTypeForScoringCondition(cats[i])));
    }
    return runs;
  }

  static List<_ScoringRun> _attendantRuns(Tile tile) {
    final condition = _enumLabel(tile.scoringCondition);
    final cat = tileTypeForScoringCondition(tile.scoringCondition);
    if (cat != null) {
      return [
        _ScoringRun('+${tile.scorePer} per '),
        _ScoringRun('$condition in castle', category: cat),
      ];
    }
    return [
      _ScoringRun('+${tile.scorePer} per $condition in castle'),
    ];
  }

  static List<_ScoringRun> _specialRuns(Tile tile) {
    final per = tile.scorePer;
    if (tile.name.startsWith('BallRoom')) {
      final cat = tileTypeForScoringCondition(tile.scoringCondition);
      final label = _conditionLabel(tile.scoringCondition);
      return [
        _ScoringRun('+$per per '),
        _ScoringRun('$label in neighboring castles', category: cat),
      ];
    }
    if (tile.scoringCondition == ScoringCondition.Always) {
      return [_ScoringRun('+$per')];
    }
    final positions = tile.scoringPositions;
    if (positions.contains(ScoringPosition.Below)) {
      return [_ScoringRun('+$per per room below')];
    }
    if (positions.contains(ScoringPosition.Above)) {
      return [_ScoringRun('+$per per room above')];
    }
    if (positions.length >= 4) {
      if (tile.scoringCondition == ScoringCondition.Any) {
        return [_ScoringRun('+$per per surrounding room')];
      }
      final cat = tileTypeForScoringCondition(tile.scoringCondition);
      final label = _conditionLabel(tile.scoringCondition);
      return [
        _ScoringRun('+$per per surrounding '),
        _ScoringRun(label, category: cat),
      ];
    }
    if (per != 0) return [_ScoringRun('+$per')];
    return const [];
  }

  static List<_ScoringRun> _bonusRuns(Tile tile) {
    final per = tile.scorePer;
    switch (tile.id) {
      case TileId.BCPerUtility:
        return [
          _ScoringRun('+$per per '),
          _ScoringRun('Utility room', category: TileType.Utility),
        ];
      case TileId.BCPerOutdoor:
        return [
          _ScoringRun('+$per per '),
          _ScoringRun('Outdoor room', category: TileType.Outdoor),
        ];
      case TileId.BCPerDownstairs:
        return [
          _ScoringRun('+$per per '),
          _ScoringRun('Downstairs room', category: TileType.Downstairs),
        ];
      case TileId.BCPerLiving:
        return [
          _ScoringRun('+$per per '),
          _ScoringRun('Living room', category: TileType.Living),
        ];
      case TileId.BCPerSpecial:
        return [_ScoringRun('+$per per Special room')];
      case TileId.BCPerCorridor:
        return [
          _ScoringRun('+$per per '),
          _ScoringRun('Corridor', category: TileType.Corridor),
        ];
      case TileId.BCPerSleeping:
        return [
          _ScoringRun('+$per per '),
          _ScoringRun('Sleeping room', category: TileType.Sleeping),
        ];
      case TileId.BCPerFood:
        return [
          _ScoringRun('+$per per '),
          _ScoringRun('Food room', category: TileType.Food),
        ];
      case TileId.BCPerActivity:
        return [
          _ScoringRun('+$per per '),
          _ScoringRun('Activity room', category: TileType.Activity),
        ];
      case TileId.BCPerSecret:
        return [
          _ScoringRun('+$per per '),
          _ScoringRun('Secret room', category: TileType.Secret),
        ];
      case TileId.BCPerSpecialInNeighborCastles:
        return [_ScoringRun('+$per per Special room in neighboring castles')];
      default:
        final text = TokenTileGrid.scoringDescription(tile);
        return text.isEmpty ? const [] : [_ScoringRun(text)];
    }
  }

  static List<_ScoringRun> _standardRuns(
    Tile tile, {
    bool includeDecoration = true,
  }) {
    final runs = <_ScoringRun>[];

    if (tile.scoringCondition != ScoringCondition.None) {
      final cat = tileTypeForScoringCondition(tile.scoringCondition);
      final label = _conditionLabel(tile.scoringCondition);
      final positions = tile.scoringPositions;

      if (positions.contains(ScoringPosition.Connected)) {
        if (tile.scorePer != 0) {
          runs.add(_ScoringRun('+${tile.scorePer} per Connected '));
        } else {
          runs.add(const _ScoringRun('Connected '));
        }
        runs.add(_ScoringRun(label, category: cat));
      } else {
        var where = '';
        if (positions.contains(ScoringPosition.Type)) {
          where = ' in castle';
        } else if (positions.contains(ScoringPosition.Neighbor)) {
          where = ' in neighboring castles';
        } else if (positions.contains(ScoringPosition.Above)) {
          where = ' above';
        } else if (positions.contains(ScoringPosition.Below)) {
          where = ' below';
        } else if (positions.length >= 4) {
          where = ' surrounding';
        }
        if (tile.scorePer != 0) {
          runs.add(_ScoringRun('+${tile.scorePer} per '));
          runs.add(_ScoringRun('$label$where', category: cat));
        } else {
          runs.add(_ScoringRun('$label$where', category: cat));
        }
      }
    } else if (tile.scorePer != 0) {
      runs.add(_ScoringRun('+${tile.scorePer}'));
    }

    if (tile.throneRoomCondition != ScoringCondition.None) {
      if (runs.isNotEmpty) runs.add(const _ScoringRun(' · '));
      final cat = tileTypeForScoringCondition(tile.throneRoomCondition);
      runs.add(_ScoringRun('+${tile.scorePer} per '));
      runs.add(_ScoringRun(
        _conditionLabel(tile.throneRoomCondition),
        category: cat,
      ));
    }

    if (includeDecoration && tile.decorationType != DecorationType.None) {
      if (runs.isNotEmpty) runs.add(const _ScoringRun(' · '));
      runs.add(_ScoringRun(
        TokenTileGrid.humanizeCamelCase(_enumLabel(tile.decorationType)),
      ));
    }

    return runs;
  }

  /// Title line that may embed a category (e.g. Bonus · Food).
  static Widget titleWithCategories({
    required String title,
    required TextStyle? style,
    TextAlign textAlign = TextAlign.start,
    double iconScale = 0.28,
  }) {
    final parts = title.split(' · ');
    if (parts.length < 2) {
      return Text(title, style: style, textAlign: textAlign);
    }

    final children = <Widget>[
      Text(parts.first, style: style),
    ];
    for (var i = 1; i < parts.length; i++) {
      children.add(Text(' · ', style: style));
      final segment = parts[i];
      final cat = _tileTypeFromLabel(segment);
      if (cat != null && _hasCategoryImage(cat)) {
        children.add(TileTypeWidget(cat, scale: iconScale));
        children.add(SizedBox(width: 6 * iconScale / 0.28));
      }
      children.add(Text(segment, style: style));
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: textAlign == TextAlign.center
          ? WrapAlignment.center
          : WrapAlignment.start,
      children: children,
    );
  }

  static TileType? _tileTypeFromLabel(String label) {
    final key = label.trim().toLowerCase();
    for (final type in TileType.values) {
      final name = type.toString().split('.').last;
      if (name.toLowerCase() == key) return type;
      if (TokenTileGrid.humanizeCamelCase(name).toLowerCase() == key) {
        return type;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final runs = _runsFor(tile, includeDecoration: includeDecoration);
    if (runs.isEmpty) return const SizedBox.shrink();

    final effectiveStyle = style ??
        Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.72),
            );

    final children = <Widget>[];
    for (final run in runs) {
      if (run.category != null && _hasCategoryImage(run.category!)) {
        children.add(TileTypeWidget(run.category!, scale: iconScale));
        children.add(SizedBox(width: 6 * iconScale / 0.28));
      }
      if (run.text.isNotEmpty) {
        children.add(Text(run.text, style: effectiveStyle));
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: textAlign == TextAlign.center
          ? WrapAlignment.center
          : WrapAlignment.start,
      children: children,
    );
  }
}
