import 'package:auto_size_text/auto_size_text.dart';
import 'package:btcc/src/app/app_widget.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/async_confirmation_dialog.dart';
import 'package:btcc/src/widgets/tile/tile_widget.dart';
import 'package:flutter/material.dart';

import 'castle_tiles_grid.dart';

class CastleListItem extends StatelessWidget {
  final Castle castle;
  final DeleteCastleCallback deleteCallback;
  final Key? key;
  final Color color;
  final VoidCallback? onOpen;
  final VoidCallback? onRename;
  final VoidCallback? onEdit;
  /// When true, hide the tile grid and show only the title/score row.
  final bool headerOnly;
  /// Reorder drag affordance; omitted outside sorting mode.
  final Widget? dragHandle;
  /// Max height for the castle tile grid (not the whole card).
  final double? maxGridHeight;

  CastleListItem({
    required this.castle,
    required this.deleteCallback,
    this.key,
    this.color = AppColors.card,
    this.onOpen,
    this.onRename,
    this.onEdit,
    this.headerOnly = false,
    this.dragHandle,
    this.maxGridHeight,
  }) : super(key: key);

  bool get _showMenu => !headerOnly;

  void _onMenuSelected(BuildContext context, String value) {
    if (value == 'scoring') {
      onOpen?.call();
      return;
    }
    if (value == 'edit') {
      onEdit?.call();
      return;
    }
    if (value == 'rename') {
      onRename?.call();
      return;
    }
    if (value == 'delete') {
      showDialog(
        context: context,
        builder: (_) => AsyncConfirmationDialog(
          confirmationText: 'Are you sure you want to delete this castle?',
          progressText: 'Deleting castle...',
          popOnYes: true,
          onPressedYes: () async {
            await deleteCallback(castle);
            return 'Successfully deleted castle!';
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = castle.hiveCastle?.title ?? castle.title;
    final score = castle.getScore();

    return Material(
      elevation: 8.0,
      key: key ?? Key('${castle.hiveCastle!.key}'),
      borderRadius: BorderRadius.circular(20.0),
      color: color,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onOpen,
                    child: Tooltip(
                      message: 'Scoring',
                      child: SizedBox(
                        height: 40,
                        width: 40,
                        child: Center(
                          child: Text(
                            '$score',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: AutoSizeText(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                        height: 1.0,
                      ),
                      maxLines: 1,
                      minFontSize: 12,
                    ),
                  ),
                ),
                if (dragHandle != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    child: dragHandle!,
                  ),
                if (_showMenu)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) => _onMenuSelected(context, value),
                    itemBuilder: (_) => [
                      if (onOpen != null)
                        const PopupMenuItem(
                          value: 'scoring',
                          child: Row(
                            children: [
                              Icon(Icons.assessment),
                              SizedBox(width: 12),
                              Text('Scoring'),
                            ],
                          ),
                        ),
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 12),
                              Text('Edit'),
                            ],
                          ),
                        ),
                      if (onRename != null)
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.drive_file_rename_outline),
                              SizedBox(width: 12),
                              Text('Rename'),
                            ],
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete),
                            SizedBox(width: 12),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 4),
              ],
            ),
            if (!headerOnly) ...[
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final grid = castle.castleTiles;
                  final tile = TileWidget.defaultTileWidthHeight;
                  final naturalW = grid.width * tile;
                  final naturalH = grid.height * tile;

                  var scale = constraints.maxWidth / naturalW;
                  if (maxGridHeight != null) {
                    final scaleH = maxGridHeight! / naturalH;
                    if (scaleH < scale) scale = scaleH;
                  }
                  scale = scale.clamp(0.12, 1.0);

                  return Center(
                    child: CastleTilesGrid(
                      grid,
                      scaleWithScreen: false,
                      scalePercentScreenWidth: 0,
                      scale: scale,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
