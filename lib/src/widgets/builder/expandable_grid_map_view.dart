import 'dart:io';

import 'package:btcc/src/utils/grid_expander.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/tile/tile_widget.dart';
import 'package:flutter/material.dart';

import 'expandable_drag_and_drop_grid.dart';

class ExpandableGridMapView<T extends Object> extends StatefulWidget {

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
  final IndexItemCallback<T> onDragCancelled;
  final ExpandCollapseCallback<T> onExpandCollapse;
  final DragItemCallback? onTapItem;
  final int? selectedIndex;

  ExpandableGridMapView({
    required this.gridList,
    required this.getEmpty,
    required this.builder,
    required this.feedback,
    required this.wrapperOnDropHover,
    required this.canDragItem,
    required this.canDropOnItem,
    this.canAcceptDraggedItem,
    required this.isOccupied,
    required this.onDropOnItem,
    required this.onDragItem,
    required this.onDragCancelled,
    required this.onExpandCollapse,
    this.replaceWithEmptyOnDragStart=true,
    this.onTapItem,
    this.selectedIndex,
  });

  @override
  createState() => _ExpandableGridMapViewState<T>();
}

class _ExpandableGridMapViewState<T extends Object> extends State<ExpandableGridMapView<T>> {
  static const List<double> _zoomSteps = [0.5, 0.75, 1.0, 1.5, 2.0, 2.5];
  static const double _maxScale = 3.0;

  final TransformationController _transformationController =
      TransformationController();

  double get _minScale =>
      Platform.isWindows ? .3 : 1 / widget.gridList.maxDimension;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  double _currentScale() =>
      _transformationController.value.getMaxScaleOnAxis();

  void _setScale(double newScale) {
    final clamped = newScale.clamp(_minScale, _maxScale);
    final current = _currentScale();
    if (current == 0) return;
    final factor = clamped / current;
    _transformationController.value =
        Matrix4.copy(_transformationController.value)..scaleByDouble(factor, factor, factor, 1);
    setState(() {});
  }

  void _zoomIn() {
    final current = _currentScale();
    final next = _zoomSteps.firstWhere(
      (step) => step > current + 0.01,
      orElse: () => _zoomSteps.last,
    );
    _setScale(next.clamp(_minScale, _maxScale));
  }

  void _zoomOut() {
    final current = _currentScale();
    final previous = _zoomSteps.lastWhere(
      (step) => step < current - 0.01,
      orElse: () => _zoomSteps.first,
    );
    _setScale(previous.clamp(_minScale, _maxScale));
  }

  Widget _zoomButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool enabled,
  }) =>
      Material(
        color: Colors.blueGrey.shade700,
        elevation: 4,
        shadowColor: Colors.black87,
        shape: const CircleBorder(
          side: BorderSide(color: Colors.white70, width: 1.5),
        ),
        child: IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: enabled ? onPressed : null,
          disabledColor: Colors.white38,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scale = _currentScale();
    final canZoomIn = scale < _maxScale - 0.01 && scale < _zoomSteps.last + 0.01;
    final canZoomOut = scale > _minScale + 0.01;

    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _transformationController,
          minScale: _minScale,
          maxScale: _maxScale,
          constrained: false,
          boundaryMargin: EdgeInsets.all(
            widget.gridList.maxDimension.toDouble() *
                TileWidget.defaultTileWidthHeight /
                2.5,
          ),
          child: Center(
            child: ExpandableDragAndDropGrid<T>(
              gridList: widget.gridList,
              getEmpty: widget.getEmpty,
              canDragItem: widget.canDragItem,
              canDropOnItem: widget.canDropOnItem,
              canAcceptDraggedItem: widget.canAcceptDraggedItem,
              isOccupied: widget.isOccupied,
              builder: widget.builder,
              feedback: widget.feedback,
              wrapperOnDropHover: widget.wrapperOnDropHover,
              onDropOnItem: widget.onDropOnItem,
              onDragItem: widget.onDragItem,
              onDragCancelled: widget.onDragCancelled,
              onExpandCollapse: widget.onExpandCollapse,
              onTapItem: widget.onTapItem,
              selectedIndex: widget.selectedIndex,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Column(
            children: [
              _zoomButton(
                icon: Icons.add,
                onPressed: _zoomIn,
                enabled: canZoomIn,
              ),
              const SizedBox(height: 8),
              _zoomButton(
                icon: Icons.remove,
                onPressed: _zoomOut,
                enabled: canZoomOut,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
