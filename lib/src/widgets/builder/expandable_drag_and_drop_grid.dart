import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:flutter/material.dart';

import 'drag_and_drop_grid.dart';

class ExpandableDragAndDropGrid<T extends Object> extends StatelessWidget {
  final GridList<T> gridList;
  final CreateItemCallback<T> getEmpty;
  final GridItemBuilder<T> builder;
  final GridItemBuilder<T> feedback;
  final WidgetWrapper<T> wrapperOnDropHover;
  final ItemToBoolCallback<T> canDragItem;
  final IndexItemToBoolCallback<T> canDropOnItem;
  final IndexItemToBoolCallback<T>? canAcceptDraggedItem;
  final ItemToBoolCallback<T> isOccupied;
  final bool replaceWithEmptyOnDragStart;
  final IndexItemCallback<T> onDropOnItem;
  final DragItemCallback onDragItem;
  final ExpandCollapseCallback<T> onExpandCollapse;
  final IndexItemCallback<T> onDragCancelled;
  final DragItemCallback? onTapItem;
  final int? selectedIndex;

  ExpandableDragAndDropGrid({
    required this.gridList,
    required this.getEmpty,
    required this.builder,
    required this.feedback,
    required this.wrapperOnDropHover,
    required this.canDragItem,
    required this.canDropOnItem,
    this.canAcceptDraggedItem,
    required this.isOccupied,
    this.replaceWithEmptyOnDragStart = true,
    required this.onDropOnItem,
    required this.onDragItem,
    required this.onExpandCollapse,
    required this.onDragCancelled,
    this.onTapItem,
    this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    var onDrop = (int i, T item) {
      onDropOnItem(i, item);
      log(gridList.width);
      final normalized = GridListNormalizer.normalizePerimeter(
        gridList,
        isOccupied: isOccupied,
        getEmpty: getEmpty,
      );
      if (normalized.changed) {
        onExpandCollapse(normalized.grid);
      }
    };

    return DragAndDropGrid<T>(
      gridList: gridList,
      getEmpty: getEmpty,
      builder: builder,
      feedback: feedback,
      wrapperOnDropHover: wrapperOnDropHover,
      canDragItem: canDragItem,
      canDropOnItem: canDropOnItem,
      canAcceptDraggedItem: canAcceptDraggedItem,
      replaceWithEmptyOnDragStart: replaceWithEmptyOnDragStart,
      onDragItem: onDragItem,
      onDropOnItem: onDrop,
      onDragCancelled: onDragCancelled,
      onTapItem: onTapItem,
      selectedIndex: selectedIndex,
    );
  }
}
