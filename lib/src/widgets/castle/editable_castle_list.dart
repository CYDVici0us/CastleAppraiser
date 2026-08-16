import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:flutter/material.dart';

import 'castle_list_item.dart';

class EditableCastleList extends StatelessWidget {

  final List<Castle> castles;
  final DeleteCastleCallback deleteCallback;
  final RearrangedCastlesCallback rearrangedCallback;
  final GetCastleColorCallback getColorCallback;
  EditableCastleList({
    required this.castles,
    required this.deleteCallback,
    required this.rearrangedCallback,
    required this.getColorCallback,
  });

  @override
  Widget build(BuildContext context) => ReorderableListView(
    onReorder: rearrangedCallback,
    children: List.generate(
      castles.length,
      (index) => Column(
        mainAxisSize: MainAxisSize.min,
        key: Key('$index'),
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            child: CastleListItem(
              castle: castles[index],
              deleteCallback: deleteCallback,
              color: getColorCallback(castles[index]),
              onOpen: () => NavigationHelper.goToCastleScreen(
                context,
                castles[index],
              ),
            )
          )
        ] 
      )
    )
  );
}
