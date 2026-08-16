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
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  /// When true, hide the tile grid and show only the title/score row.
  final bool headerOnly;

  CastleListItem({
    required this.castle,
    required this.deleteCallback,
    this.key,
    this.color = AppColors.card,
    this.onOpen,
    this.onRename,
    this.onEdit,
    this.onMoveUp,
    this.onMoveDown,
    this.headerOnly = false,
  }) : super(key: key);

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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Column(
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
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10.0,
                            ),
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
                      ),
                      if (onMoveUp != null || onMoveDown != null)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Move up',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 28,
                              ),
                              onPressed: onMoveUp,
                              icon: Icon(
                                Icons.keyboard_arrow_up,
                                color: onMoveUp != null
                                    ? Colors.white
                                    : Colors.white38,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Move down',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 28,
                              ),
                              onPressed: onMoveDown,
                              icon: Icon(
                                Icons.keyboard_arrow_down,
                                color: onMoveDown != null
                                    ? Colors.white
                                    : Colors.white38,
                              ),
                            ),
                          ],
                        ),
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) => _onMenuSelected(context, value),
                        itemBuilder: (_) => [
                          if (onOpen != null)
                            const PopupMenuItem(
                              value: 'scoring',
                              child: Text('Scoring'),
                            ),
                          if (onEdit != null)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit'),
                            ),
                          if (onRename != null)
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                      const Icon(Icons.drag_handle, color: Colors.white70),
                      const SizedBox(width: 4),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: headerOnly
                        ? const SizedBox(width: double.infinity)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final grid = castle.castleTiles;
                                  final scale = constraints.maxWidth /
                                      (grid.width *
                                          TileWidget.defaultTileWidthHeight);
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: CastleTilesGrid(
                                      grid,
                                      scaleWithScreen: false,
                                      scalePercentScreenWidth: 0,
                                      scale: scale.clamp(0.12, 1.0),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
