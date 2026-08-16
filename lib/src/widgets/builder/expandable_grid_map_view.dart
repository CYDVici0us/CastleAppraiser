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
  /// When nothing is selected, center the map on this index (e.g. throne).
  final int? initialCenterIndex;

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
    this.initialCenterIndex,
  });

  @override
  createState() => _ExpandableGridMapViewState<T>();
}

class _ExpandableGridMapViewState<T extends Object> extends State<ExpandableGridMapView<T>> {
  static const List<double> _zoomSteps = [0.5, 0.75, 1.0, 1.5, 2.0, 2.5];
  static const double _maxScale = 3.0;
  /// Re-center after the edit panel opens and shrinks the viewport.
  static const Duration _recenterAfterPanel = Duration(milliseconds: 300);

  final TransformationController _transformationController =
      TransformationController();

  Size? _viewportSize;
  int? _pendingCenterIndex;
  bool _didInitialCenter = false;

  double get _minScale =>
      Platform.isWindows ? .3 : 1 / widget.gridList.maxDimension;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCenterIndex;
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didInitialCenter) return;
        _centerOnIndex(initial);
        _didInitialCenter = true;
      });
    }
  }

  @override
  void didUpdateWidget(ExpandableGridMapView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedIndex;
    if (selected != null &&
        (selected != oldWidget.selectedIndex ||
            widget.gridList.width != oldWidget.gridList.width ||
            widget.gridList.height != oldWidget.gridList.height)) {
      _scheduleCenterOn(selected);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  double _currentScale() =>
      _transformationController.value.getMaxScaleOnAxis();

  Offset _scenePointForIndex(int index) {
    const cell = TileWidget.defaultTileWidthHeight;
    final gridWidth = widget.gridList.width;
    return Offset(
      (index % gridWidth + 0.5) * cell,
      (index ~/ gridWidth + 0.5) * cell,
    );
  }

  /// Scene point to keep focused: selected tile, else whatever is at view center.
  Offset _focalScenePoint() {
    final selected = widget.selectedIndex;
    if (selected != null &&
        selected >= 0 &&
        selected < widget.gridList.items.length) {
      return _scenePointForIndex(selected);
    }

    final viewport = _viewportSize;
    final scale = _currentScale();
    if (viewport == null || viewport.isEmpty || scale == 0) {
      return Offset.zero;
    }
    final matrix = _transformationController.value;
    final tx = matrix.storage[12];
    final ty = matrix.storage[13];
    return Offset(
      (viewport.width / 2 - tx) / scale,
      (viewport.height / 2 - ty) / scale,
    );
  }

  void _scheduleCenterOn(int index) {
    _pendingCenterIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingCenterIndex != index) return;
      _centerOnIndex(index);
    });
    Future<void>.delayed(_recenterAfterPanel, () {
      if (!mounted || widget.selectedIndex != index) return;
      _centerOnIndex(index);
    });
  }

  void _centerOnIndex(int index) {
    final viewport = _viewportSize;
    if (viewport == null || viewport.isEmpty) return;
    if (index < 0 || index >= widget.gridList.items.length) return;

    final scene = _scenePointForIndex(index);
    final scale = _currentScale();

    final dx = viewport.width / 2 - scene.dx * scale;
    final dy = viewport.height / 2 - scene.dy * scale;

    _transformationController.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }

  void _setScale(double newScale) {
    final clamped = newScale.clamp(_minScale, _maxScale);
    final oldScale = _currentScale();
    if (oldScale == 0 || (clamped - oldScale).abs() < 0.0001) return;

    final viewport = _viewportSize;
    final focal = _focalScenePoint();

    // Keep the focused tile at the center of the visible grid area.
    final double newTx;
    final double newTy;
    if (viewport != null && !viewport.isEmpty) {
      newTx = viewport.width / 2 - focal.dx * clamped;
      newTy = viewport.height / 2 - focal.dy * clamped;
    } else {
      final matrix = _transformationController.value;
      final oldTx = matrix.storage[12];
      final oldTy = matrix.storage[13];
      final viewportX = focal.dx * oldScale + oldTx;
      final viewportY = focal.dy * oldScale + oldTy;
      newTx = viewportX - focal.dx * clamped;
      newTy = viewportY - focal.dy * clamped;
    }

    _transformationController.value = Matrix4.identity()
      ..translateByDouble(newTx, newTy, 0, 1)
      ..scaleByDouble(clamped, clamped, clamped, 1);
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final nextSize = Size(constraints.maxWidth, constraints.maxHeight);
        final sizeChanged = _viewportSize != nextSize;
        final previous = _viewportSize;
        _viewportSize = nextSize;
        if (sizeChanged) {
          final focus = widget.selectedIndex ??
              (!_didInitialCenter ? widget.initialCenterIndex : null);
          if (focus != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (previous == null || previous != nextSize) {
                _centerOnIndex(focus);
                if (widget.selectedIndex == null) {
                  _didInitialCenter = true;
                }
              }
            });
          }
        }

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
      },
    );
  }
}
