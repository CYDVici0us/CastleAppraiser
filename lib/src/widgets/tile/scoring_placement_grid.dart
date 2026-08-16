import 'package:btcc/src/models/exports.dart';
import 'package:flutter/material.dart';

/// Logical cell kinds for placement diagrams.
enum PlacementCellKind {
  /// Unused — not painted.
  empty,
  /// Self tile or throne (west + east half).
  self,
  /// Active scoring position.
  scoring,
}

/// Directional cue for Above/Below and Secret copy-direction diagrams.
enum PlacementArrow {
  none,
  up,
  down,
  left,
  right,
}

/// Maps [ScoringPosition] lists onto standard (3×3) or throne (3×4) grids.
class ScoringPlacementMapping {
  ScoringPlacementMapping._();

  static const ordinal = {
    ScoringPosition.NW,
    ScoringPosition.N,
    ScoringPosition.NE,
    ScoringPosition.E,
    ScoringPosition.SE,
    ScoringPosition.S,
    ScoringPosition.SW,
    ScoringPosition.W,
  };

  /// Whether a placement diagram should be shown for [tile].
  static bool shouldShow(Tile tile) {
    if (tile.isEmpty() || tile.isPlaceholder()) return false;
    if (tile.isBonusCard() || tile.isRoyalAttendant()) return false;
    final positions = tile.scoringPositions;
    if (positions.isEmpty) return false;
    if (positions.contains(ScoringPosition.Type) ||
        positions.contains(ScoringPosition.Connected) ||
        positions.contains(ScoringPosition.Neighbor)) {
      return false;
    }
    if (tile.scoringCondition == ScoringCondition.Always) return false;
    if (tile.isThroneRoom()) return true;
    if (tile.isSecret() && secretArrow(positions) != PlacementArrow.none) {
      return true;
    }
    if (positions.any((p) =>
        p == ScoringPosition.Above ||
        p == ScoringPosition.Below ||
        ordinal.contains(p) ||
        p == ScoringPosition.EE ||
        p == ScoringPosition.SS)) {
      return true;
    }
    return false;
  }

  /// Secret rooms: a single N/E/S/W copy direction → arrow only.
  static PlacementArrow secretArrow(List<ScoringPosition> positions) {
    if (positions.length != 1) return PlacementArrow.none;
    switch (positions.first) {
      case ScoringPosition.N:
        return PlacementArrow.up;
      case ScoringPosition.S:
        return PlacementArrow.down;
      case ScoringPosition.W:
        return PlacementArrow.left;
      case ScoringPosition.E:
        return PlacementArrow.right;
      default:
        return PlacementArrow.none;
    }
  }

  static bool isVerticalOnly(List<ScoringPosition> positions) {
    if (positions.isEmpty) return false;
    final hasAbove = positions.contains(ScoringPosition.Above);
    final hasBelow = positions.contains(ScoringPosition.Below);
    if (!hasAbove && !hasBelow) return false;
    return positions.every(
      (p) => p == ScoringPosition.Above || p == ScoringPosition.Below,
    );
  }

  /// 3×3 row-major (0=NW … 4=center … 8=SE).
  static List<PlacementCellKind> standardCells(List<ScoringPosition> positions) {
    final cells =
        List<PlacementCellKind>.filled(9, PlacementCellKind.empty);
    cells[4] = PlacementCellKind.self;

    if (isVerticalOnly(positions)) {
      final hasAbove = positions.contains(ScoringPosition.Above);
      final hasBelow = positions.contains(ScoringPosition.Below);
      // White self + arrow only (no black scoring cells).
      cells[4] = PlacementCellKind.self;
      if (hasAbove && hasBelow) {
        // Both directions: self center with black marks both ways.
        cells[1] = PlacementCellKind.scoring;
        cells[7] = PlacementCellKind.scoring;
      }
      return cells;
    }

    for (final p in positions) {
      final i = _ordinalIndex(p);
      if (i != null && i != 4) cells[i] = PlacementCellKind.scoring;
    }
    return cells;
  }

  /// Arrow for vertical-only mode (Above / Below).
  static PlacementArrow verticalArrow(List<ScoringPosition> positions) {
    if (!isVerticalOnly(positions)) return PlacementArrow.none;
    final hasAbove = positions.contains(ScoringPosition.Above);
    final hasBelow = positions.contains(ScoringPosition.Below);
    if (hasAbove && hasBelow) return PlacementArrow.none;
    if (hasAbove) return PlacementArrow.up;
    if (hasBelow) return PlacementArrow.down;
    return PlacementArrow.none;
  }

  /// 3×4 row-major. Throne occupies indices 5 and 6 (row 2, cols 2–3).
  static List<PlacementCellKind> throneCells(List<ScoringPosition> positions) {
    final cells =
        List<PlacementCellKind>.filled(12, PlacementCellKind.empty);
    cells[5] = PlacementCellKind.self;
    cells[6] = PlacementCellKind.self;
    for (final p in positions) {
      final i = _throneIndex(p);
      if (i != null) cells[i] = PlacementCellKind.scoring;
    }
    return cells;
  }

  static int? _ordinalIndex(ScoringPosition p) {
    switch (p) {
      case ScoringPosition.NW:
        return 0;
      case ScoringPosition.N:
        return 1;
      case ScoringPosition.NE:
        return 2;
      case ScoringPosition.W:
        return 3;
      case ScoringPosition.E:
        return 5;
      case ScoringPosition.SW:
        return 6;
      case ScoringPosition.S:
        return 7;
      case ScoringPosition.SE:
        return 8;
      default:
        return null;
    }
  }

  static int? _throneIndex(ScoringPosition p) {
    switch (p) {
      case ScoringPosition.NW:
        return 0; // (1,1)
      case ScoringPosition.N:
        return 1; // (1,2)
      case ScoringPosition.NE:
        return 2; // (1,3)
      case ScoringPosition.W:
        return 4; // (2,1)
      case ScoringPosition.EE:
        return 7; // (2,4)
      case ScoringPosition.SW:
        return 8; // (3,1)
      case ScoringPosition.S:
        return 9; // (3,2)
      case ScoringPosition.SE:
        return 10; // (3,3)
      case ScoringPosition.E:
        return null; // throne east half
      case ScoringPosition.SS:
        return null;
      default:
        return null;
    }
  }
}

/// Visual scoring-position diagram: white = self, black = scoring, unused invisible.
class ScoringPlacementGrid extends StatelessWidget {
  final List<PlacementCellKind> cells;
  final int columns;
  final double cellSize;
  final double gap;
  final PlacementArrow arrow;
  /// When true, only the arrow is shown (Secret copy direction).
  final bool arrowOnly;

  const ScoringPlacementGrid._({
    required this.cells,
    required this.columns,
    this.cellSize = 18,
    this.arrow = PlacementArrow.none,
    this.arrowOnly = false,
  }) : gap = 3;

  factory ScoringPlacementGrid.standard({
    required List<ScoringPosition> positions,
    double cellSize = 18,
  }) {
    return ScoringPlacementGrid._(
      cells: ScoringPlacementMapping.standardCells(positions),
      columns: 3,
      cellSize: cellSize,
      arrow: ScoringPlacementMapping.verticalArrow(positions),
    );
  }

  factory ScoringPlacementGrid.throne({
    required List<ScoringPosition> positions,
    double cellSize = 16,
  }) {
    return ScoringPlacementGrid._(
      cells: ScoringPlacementMapping.throneCells(positions),
      columns: 4,
      cellSize: cellSize,
    );
  }

  factory ScoringPlacementGrid.forTile(Tile tile, {double? cellSize}) {
    final size = cellSize ?? (tile.isThroneRoom() ? 16.0 : 18.0);
    if (tile.isSecret()) {
      final secret = ScoringPlacementMapping.secretArrow(tile.scoringPositions);
      if (secret != PlacementArrow.none) {
        return ScoringPlacementGrid._(
          cells: const [],
          columns: 1,
          cellSize: size,
          arrow: secret,
          arrowOnly: true,
        );
      }
    }
    if (tile.isThroneRoom()) {
      return ScoringPlacementGrid.throne(
        positions: tile.scoringPositions,
        cellSize: size,
      );
    }
    return ScoringPlacementGrid.standard(
      positions: tile.scoringPositions,
      cellSize: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVerticalAboveBelow =
        arrow == PlacementArrow.up || arrow == PlacementArrow.down;
    final Widget? arrowWidget;
    if (arrow == PlacementArrow.none) {
      arrowWidget = null;
    } else if (isVerticalAboveBelow && !arrowOnly) {
      // Above/Below: thick black arrows next to the white self cell.
      arrowWidget = _ThickPlacementArrow(
        direction: arrow,
        size: cellSize * 0.95,
      );
    } else {
      final arrowColor =
          Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75);
      arrowWidget = Icon(
        _arrowIcon(arrow)!,
        size: cellSize * (arrowOnly ? 1.4 : 0.85),
        color: arrowColor,
      );
    }

    if (arrowOnly) {
      return arrowWidget ?? const SizedBox.shrink();
    }

    final hasScoring = cells.any((c) => c == PlacementCellKind.scoring);
    // Above/Below with only the white self cell: keep arrow tight to the box
    // (don't leave empty 3×3 rows between them).
    if (arrowWidget != null &&
        !hasScoring &&
        (arrow == PlacementArrow.up || arrow == PlacementArrow.down)) {
      const arrowGap = 2.0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (arrow == PlacementArrow.up) ...[
            arrowWidget,
            const SizedBox(height: arrowGap),
          ],
          SizedBox(
            width: cellSize,
            height: cellSize,
            child: _cell(PlacementCellKind.self),
          ),
          if (arrow == PlacementArrow.down) ...[
            const SizedBox(height: arrowGap),
            arrowWidget,
          ],
        ],
      );
    }

    final rows = (cells.length / columns).ceil();
    final width = columns * cellSize + (columns - 1) * gap;
    final height = rows * cellSize + (rows - 1) * gap;

    Widget grid = SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          for (var i = 0; i < cells.length; i++)
            if (cells[i] != PlacementCellKind.empty)
              Positioned(
                left: (i % columns) * (cellSize + gap),
                top: (i ~/ columns) * (cellSize + gap),
                width: cellSize,
                height: cellSize,
                child: _cell(cells[i]),
              ),
        ],
      ),
    );

    if (arrow == PlacementArrow.none || arrowWidget == null) return grid;

    if (arrow == PlacementArrow.left || arrow == PlacementArrow.right) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (arrow == PlacementArrow.left) ...[
            arrowWidget,
            const SizedBox(width: 2),
          ],
          grid,
          if (arrow == PlacementArrow.right) ...[
            const SizedBox(width: 2),
            arrowWidget,
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (arrow == PlacementArrow.up) ...[
          arrowWidget,
          const SizedBox(height: 2),
        ],
        grid,
        if (arrow == PlacementArrow.down) ...[
          const SizedBox(height: 2),
          arrowWidget,
        ],
      ],
    );
  }

  IconData? _arrowIcon(PlacementArrow direction) {
    switch (direction) {
      case PlacementArrow.up:
        return Icons.arrow_upward;
      case PlacementArrow.down:
        return Icons.arrow_downward;
      case PlacementArrow.left:
        return Icons.arrow_back;
      case PlacementArrow.right:
        return Icons.arrow_forward;
      case PlacementArrow.none:
        return null;
    }
  }

  Widget _cell(PlacementCellKind kind) {
    final isSelf = kind == PlacementCellKind.self;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSelf ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(3),
        // Outline so black cells stay visible on dark cards/surfaces.
        border: Border.all(
          color: isSelf ? const Color(0xFF9E9E9E) : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
    );
  }
}

/// Filled black arrow for Above / Below placement diagrams.
class _ThickPlacementArrow extends StatelessWidget {
  final PlacementArrow direction;
  final double size;

  const _ThickPlacementArrow({
    required this.direction,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.7),
      painter: _ThickArrowPainter(direction: direction),
    );
  }
}

class _ThickArrowPainter extends CustomPainter {
  final PlacementArrow direction;

  _ThickArrowPainter({required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();
    final w = size.width;
    final h = size.height;
    // Shaft thickness relative to width.
    final shaftW = w * 0.34;
    final headH = h * 0.48;
    final cx = w / 2;

    if (direction == PlacementArrow.up) {
      path.moveTo(cx, 0);
      path.lineTo(w, headH);
      path.lineTo(cx + shaftW / 2, headH);
      path.lineTo(cx + shaftW / 2, h);
      path.lineTo(cx - shaftW / 2, h);
      path.lineTo(cx - shaftW / 2, headH);
      path.lineTo(0, headH);
      path.close();
    } else {
      path.moveTo(cx, h);
      path.lineTo(w, h - headH);
      path.lineTo(cx + shaftW / 2, h - headH);
      path.lineTo(cx + shaftW / 2, 0);
      path.lineTo(cx - shaftW / 2, 0);
      path.lineTo(cx - shaftW / 2, h - headH);
      path.lineTo(0, h - headH);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ThickArrowPainter oldDelegate) =>
      oldDelegate.direction != direction;
}
