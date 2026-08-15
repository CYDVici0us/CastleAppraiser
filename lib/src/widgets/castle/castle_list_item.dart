import 'package:auto_size_text/auto_size_text.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/async_confirmation_dialog.dart';
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

  CastleListItem({
    required this.castle,
    required this.deleteCallback,
    this.key,
    this.color = Colors.redAccent,
    this.onOpen,
    this.onRename,
    this.onEdit,
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
  Widget build(BuildContext context) => Material(
    elevation: 8.0,
    key: key ?? Key('${castle.hiveCastle!.key}'),
    borderRadius: BorderRadius.circular(20.0),
    color: color,
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(20.0),
      child: Container(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 60,
                  width: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${castle.getScore()}',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.black,
                      ),
                    ),
                  )
                ),
                Container(height: 20),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width/3),
                  padding: EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(8.0)),
                  ),
                  child: AutoSizeText('${castle.hiveCastle!.title}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                    maxLines: 3,
                  ),
                ),
              ]
            ),
            Flexible(
              fit: FlexFit.tight,
              child: Row(
                children: [
                  Flexible(child: Container()),
                  CastleTilesGrid(castle.castleTiles,
                    scalePercentScreenWidth: .5,
                  ),
                  Flexible(child: Container())
                ],
              )
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) => _onMenuSelected(context, value),
              itemBuilder: (_) => [
                if (onOpen != null)
                  const PopupMenuItem(value: 'scoring', child: Text('Scoring')),
                if (onEdit != null)
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (onRename != null)
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            Icon(Icons.drag_handle, color: Colors.white70),
            Container(width: 8),
          ],
        )
      )
    )
  );
}
