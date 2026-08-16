import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/statistics_helper.dart';
import 'package:btcc/src/widgets/castle/castle_tiles_grid.dart';
import 'package:flutter/material.dart';

/// Castle grid with name + total score — used for zoom modal / gallery export.
class CastleExportCard extends StatelessWidget {
  final Castle castle;
  final double scalePercentScreenWidth;

  const CastleExportCard({
    super.key,
    required this.castle,
    this.scalePercentScreenWidth = 0.92,
  });

  @override
  Widget build(BuildContext context) {
    final title = castle.hiveCastle?.title ?? castle.title;
    final score = castle.getScore();
    final theme = Theme.of(context);

    return Material(
      color: const Color(0xFF2E2E2E),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$score',
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: StatHelper.getColorBasedOnScore(score),
                height: 1.0,
              ),
            ),
            const SizedBox(height: 16),
            CastleTilesGrid(
              castle.castleTiles,
              scalePercentScreenWidth: scalePercentScreenWidth,
            ),
          ],
        ),
      ),
    );
  }
}
