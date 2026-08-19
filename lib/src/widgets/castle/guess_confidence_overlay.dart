import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/cell_guess_info.dart';
import 'package:flutter/material.dart';

/// Scan confidence tint / `?` overlay. High-confidence cells stay unmarked.
class GuessConfidenceOverlay extends StatelessWidget {
  final CellGuessInfo? info;
  final Tile tile;
  final Widget child;
  final double scale;
  final bool highlight;

  const GuessConfidenceOverlay({
    super.key,
    required this.info,
    required this.tile,
    required this.child,
    this.scale = 1,
    this.highlight = false,
  });

  Color? get _overlayColor {
    final current = info;
    if (current == null) return null;
    if (current.unidentified && tile.isEmpty()) {
      return Colors.orange.withValues(alpha: 0.45);
    }
    switch (current.level) {
      case GuessConfidenceLevel.high:
        return null;
      case GuessConfidenceLevel.medium:
        return Colors.amber.withValues(alpha: 0.35);
      case GuessConfidenceLevel.low:
        return Colors.deepOrange.withValues(alpha: 0.4);
      case GuessConfidenceLevel.unidentified:
        return Colors.orange.withValues(alpha: 0.45);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlay = _overlayColor;
    if (overlay == null && !highlight) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (overlay != null || highlight)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: overlay,
                  border: highlight
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                ),
              ),
            ),
          ),
        if (info?.unidentified == true && tile.isEmpty())
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Text(
                  '?',
                  style: TextStyle(
                    fontSize: 28 * scale,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
