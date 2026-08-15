import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:flutter/material.dart';

class DragAndDropGrid<T extends Object> extends StatefulWidget {
  final GridList<T> gridList;
  final CreateItemCallback<T> getEmpty;
  final GridItemBuilder<T> builder;
  final GridItemBuilder<T> feedback;
  final WidgetWrapper<T> wrapperOnDropHover;
  final ItemToBoolCallback<T> canDragItem;
  final IndexItemToBoolCallback<T> canDropOnItem;
  final IndexItemToBoolCallback<T>? canAcceptDraggedItem;
  final bool replaceWithEmptyOnDragStart;
  final IndexItemCallback<T> onDropOnItem;
  final DragItemCallback onDragItem;
  final IndexItemCallback<T> onDragCancelled;
  final DragItemCallback? onTapItem;
  final int? selectedIndex;

  static const Duration dragDelay = Duration(milliseconds: 200);

  DragAndDropGrid({
    required this.gridList,
    required this.getEmpty,
    required this.builder,
    required this.feedback,
    required this.wrapperOnDropHover,
    required this.canDragItem,
    required this.canDropOnItem,
    this.canAcceptDraggedItem,
    this.replaceWithEmptyOnDragStart = true,
    required this.onDropOnItem,
    required this.onDragItem,
    required this.onDragCancelled,
    this.onTapItem,
    this.selectedIndex,
  });

  @override
  _DragAndDropGridState<T> createState() => _DragAndDropGridState<T>();
}

class _DragAndDropGridState<T extends Object> extends State<DragAndDropGrid<T>> {
  Widget _wrapDroppable(BuildContext context, int index, Widget built) {
    var item = widget.gridList.items[index];
    if (!widget.canDropOnItem(index, item)) {
      return built;
    }

    return DragTarget<T>(
      onWillAcceptWithDetails: (details) {
        if (widget.canAcceptDraggedItem == null) return true;
        return widget.canAcceptDraggedItem!(index, details.data);
      },
      onAcceptWithDetails: (DragTargetDetails<T> details) {
        widget.onDropOnItem(index, details.data);
      },
      builder: (_, candidateData, rejectedData) => candidateData.isNotEmpty
          ? widget.wrapperOnDropHover(item, built)
          : built,
    );
  }

  Widget _wrapDraggable(BuildContext context, int index, Widget built) {
    var item = widget.gridList.items[index];
    if (!widget.canDragItem(item)) {
      return built;
    }

    return LongPressDraggable<T>(
      delay: DragAndDropGrid.dragDelay,
      childWhenDragging: widget.builder(context, index, widget.getEmpty()),
      child: built,
      feedback: widget.feedback(context, index, item),
      data: item,
      onDraggableCanceled: (velocity, offset) {
        widget.onDragCancelled(index, item);
      },
      onDragStarted: () {
        widget.onDragItem(index);
      },
    );
  }

  Widget _wrapTappable(BuildContext context, int index, Widget built) {
    final selected = widget.selectedIndex == index;
    final child = selected
        ? Container(
            foregroundDecoration: BoxDecoration(
              border: Border.all(
                width: 4,
                color: Colors.lightBlueAccent,
              ),
            ),
            child: built,
          )
        : built;

    if (widget.onTapItem == null) {
      return child;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onTapItem!(index),
      child: child,
    );
  }

  Widget _getGridItemWidget(BuildContext context, int index) {
    var built = widget.builder(context, index, widget.gridList.items[index]);
    return _wrapTappable(
      context,
      index,
      _wrapDroppable(context, index, _wrapDraggable(context, index, built)),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> columnChildren = [];
    List<Widget> widgetList = [];
    for (int i = 0; i < widget.gridList.items.length; i++) {
      if (i % widget.gridList.width == 0 && i != 0) {
        columnChildren.add(Row(children: widgetList));
        widgetList = [];
      }
      widgetList.add(_getGridItemWidget(context, i));
    }
    columnChildren.add(Row(children: widgetList));
    return Column(children: columnChildren);
  }
}
