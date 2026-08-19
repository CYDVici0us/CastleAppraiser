import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/state/tf_store.dart';
import 'package:btcc/src/tflite/castle_occupancy.dart';
import 'package:btcc/src/tflite/tile_selection_builder.dart';
import 'package:btcc/src/tflite/tile_selection_geom.dart';
import 'package:btcc/src/tflite/tile_selection_match.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/tflite/windowed_detect.dart';
import 'package:btcc/src/utils/castle_frame_crop.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/orientation_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum _TileSelectionStep { throne, bounds, mark, process }

/// Manual grid workflow: throne box → castle bounds → mark tiles → classify.
class TileSelectionFlowScreen extends StatefulWidget {
  final String imagePath;
  final AddCastleToGameCallback addCastleCallback;
  final int numPicturesTaken;
  final String? gameTitle;
  final int? expectedRoomTileCount;

  const TileSelectionFlowScreen({
    super.key,
    required this.imagePath,
    required this.addCastleCallback,
    this.numPicturesTaken = 0,
    this.gameTitle,
    this.expectedRoomTileCount,
  });

  @override
  State<TileSelectionFlowScreen> createState() => _TileSelectionFlowScreenState();
}

class _TileSelectionFlowScreenState extends State<TileSelectionFlowScreen> {
  final TransformationController _transform = TransformationController();

  _TileSelectionStep _step = _TileSelectionStep.throne;
  Size? _imageSize;
  Rect? _frame;
  bool _portraitFrame = true;
  bool _busy = false;
  String? _error;
  bool _didInitialFit = false;
  bool _markFitReady = false;
  Size? _lastViewport;
  Size? _layoutSize;
  double _viewerMinScale = 0.01;
  double? _boundsFitScale;

  ui.Rect? _throneRect;
  ui.Rect? _boundsRect;
  Matrix4? _throneTransformSnapshot;
  Matrix4? _boundsTransformSnapshot;
  double? _throneViewerMinScaleSnapshot;
  double? _boundsViewerMinScaleSnapshot;
  bool _restoreViewOnNextFrame = false;
  final Set<GridCell> _marked = {
    const GridCell(0, 0),
    const GridCell(1, 0),
  };

  int _classifyDone = 0;
  int _classifyTotal = 0;

  @override
  void initState() {
    super.initState();
    OrientationHelper.lockPortrait();
    _transform.addListener(_onTransformChanged);
    _loadSize();
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransformChanged);
    _transform.dispose();
    super.dispose();
  }

  void _onTransformChanged() {
    if (_step == _TileSelectionStep.mark && mounted) {
      setState(() {});
    }
  }

  void _scheduleFit(VoidCallback fit) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      fit();
      setState(() {});
    });
  }

  Future<void> _loadSize() async {
    try {
      final size = await decodeImagePixelSize(widget.imagePath);
      if (!mounted) return;
      setState(() {
        _imageSize = size;
        _portraitFrame = size.height >= size.width;
      });
    } catch (ex) {
      log(ex);
      if (mounted) setState(() => _error = ex.toString());
    }
  }

  double get _frameAspect => switch (_step) {
        _TileSelectionStep.throne => TileSelectionFrameAspect.throne,
        _TileSelectionStep.bounds => TileSelectionFrameAspect.castleBounds(
            portrait: _portraitFrame,
          ),
        _ => TileSelectionFrameAspect.castleBounds(portrait: _portraitFrame),
      };

  static const _wizardStepLabels = [
    'Align throne',
    'Mark tiles',
  ];

  int get _wizardStepIndex => switch (_step) {
        _TileSelectionStep.throne => 0,
        _TileSelectionStep.bounds => 0,
        _TileSelectionStep.mark => 1,
        _TileSelectionStep.process => 1,
      };

  List<String> get _breadcrumbSegments => [
        widget.gameTitle ?? 'Game',
        ..._wizardStepLabels.sublist(0, _wizardStepIndex + 1),
      ];

  String get _stepHint => switch (_step) {
        _TileSelectionStep.throne =>
          'Fit the throne room (2 tiles wide) in the box',
        _TileSelectionStep.bounds =>
          'Include the whole castle, bonus cards, and royal attendants '
              '(on the throne or beside it)',
        _TileSelectionStep.mark =>
          'Review auto-marked tiles — tap to add or remove rooms',
        _TileSelectionStep.process => 'Identifying marked tiles…',
      };

  /// Room tiles tapped by the user. Throne + placeholder are always marked
  /// and do not count toward [expectedRoomTileCount].
  int get _markedRoomCellCount => countMarkedRoomTiles(_marked);

  String get _markProgressLabel {
    final expected = widget.expectedRoomTileCount;
    if (expected != null) {
      return '$_markedRoomCellCount / $expected room tiles marked — $_stepHint';
    }
    return '$_markedRoomCellCount tiles marked — $_stepHint';
  }

  bool get _underExpectedMarkCount {
    final expected = widget.expectedRoomTileCount;
    return TfliteHelper.isUnderExpectedRoomCount(
      _markedRoomCellCount,
      expected,
    );
  }

  void _snapshotThroneView() {
    _throneTransformSnapshot = Matrix4.copy(_transform.value);
    _throneViewerMinScaleSnapshot = _viewerMinScale;
  }

  void _snapshotBoundsView() {
    _boundsTransformSnapshot = Matrix4.copy(_transform.value);
    _boundsViewerMinScaleSnapshot = _viewerMinScale;
  }

  void _scheduleRestoreView({
    required Matrix4? transformSnapshot,
    required double? minScaleSnapshot,
  }) {
    if (transformSnapshot == null) {
      _restoreViewOnNextFrame = false;
      _didInitialFit = false;
      _viewerMinScale = 0.01;
      return;
    }
    _restoreViewOnNextFrame = true;
    _didInitialFit = true;
    _scheduleFit(() {
      if (!mounted || !_restoreViewOnNextFrame) return;
      _transform.value = Matrix4.copy(transformSnapshot);
      _viewerMinScale = minScaleSnapshot ?? 0.01;
      _restoreViewOnNextFrame = false;
    });
  }

  void _goToStep(_TileSelectionStep target) {
    if (_busy) return;

    final targetIndex = switch (target) {
      _TileSelectionStep.throne => 0,
      _TileSelectionStep.bounds => 1,
      _TileSelectionStep.mark => 2,
      _TileSelectionStep.process => 2,
    };
    if (targetIndex >= _wizardStepIndex) return;

    setState(() {
      _error = null;
      _markFitReady = false;
      _step = target;

      switch (target) {
        case _TileSelectionStep.throne:
          _boundsRect = null;
          _boundsTransformSnapshot = null;
          _boundsViewerMinScaleSnapshot = null;
          _scheduleRestoreView(
            transformSnapshot: _throneTransformSnapshot,
            minScaleSnapshot: _throneViewerMinScaleSnapshot,
          );
        case _TileSelectionStep.bounds:
          _scheduleRestoreView(
            transformSnapshot: _boundsTransformSnapshot,
            minScaleSnapshot: _boundsViewerMinScaleSnapshot,
          );
        case _TileSelectionStep.mark:
        case _TileSelectionStep.process:
          break;
      }
    });
  }

  void _onBreadcrumbTap(int index) {
    if (index == 0) {
      Navigator.of(context).pop();
      return;
    }
    final target = switch (index) {
      1 => _TileSelectionStep.throne,
      2 => _TileSelectionStep.bounds,
      3 => _TileSelectionStep.mark,
      _ => null,
    };
    if (target != null) _goToStep(target);
  }

  void _applyFrameFit(Size viewport, Rect frame) {
    final imageSize = _imageSize;
    if (imageSize == null) return;
    final layout = CastleFrameGeom.displayLayoutSize(imageSize, viewport);
    if (_didInitialFit &&
        _lastViewport == viewport &&
        _layoutSize == layout) {
      return;
    }
    _lastViewport = viewport;
    _layoutSize = layout;
    _didInitialFit = true;
    final matrix = switch (_step) {
      _TileSelectionStep.throne => CastleFrameGeom.coverFrame(
          frame: frame,
          layoutSize: layout,
        ),
      _TileSelectionStep.bounds when _throneRect != null =>
        CastleFrameGeom.fitBoundsStep(
          frame: frame,
          layoutSize: layout,
          imageSize: imageSize,
          throneRectImage: _throneRect!,
        ),
      _TileSelectionStep.bounds => CastleFrameGeom.containFrame(
          frame: frame,
          layoutSize: layout,
        ),
      _ => CastleFrameGeom.coverFrame(
          frame: frame,
          layoutSize: layout,
        ),
    };
    _transform.value = matrix;
    _viewerMinScale = CastleFrameGeom.viewerMinScale(
      layoutSize: layout,
      viewport: viewport,
      initialTransform: matrix,
    );
    if (_step == _TileSelectionStep.bounds) {
      _boundsFitScale = matrix.getMaxScaleOnAxis();
    }
  }

  void _fitIfNeeded(Size viewport, Rect frame) {
    final imageSize = _imageSize;
    if (imageSize == null) return;
    final layout = CastleFrameGeom.displayLayoutSize(imageSize, viewport);
    if (_didInitialFit &&
        _lastViewport == viewport &&
        _layoutSize == layout) {
      return;
    }
    _scheduleFit(() => _applyFrameFit(viewport, frame));
  }

  void _applyMarkStepFit(
    Size viewport,
    Size layout,
    TileSelectionCalibration cal,
  ) {
    if (_didInitialFit &&
        _lastViewport == viewport &&
        _layoutSize == layout) {
      _markFitReady = true;
      return;
    }
    _lastViewport = viewport;
    _layoutSize = layout;
    _didInitialFit = true;
    _markFitReady = true;
    final imageSize = _imageSize!;
    final b = cal.boundsRect;
    final toLayout = CastleFrameGeom.layoutToImageScale(imageSize, layout);
    final bLeft = b.left / toLayout;
    final bTop = b.top / toLayout;
    final bW = b.width / toLayout;
    final bH = b.height / toLayout;
    final scale = math.min(
          viewport.width / bW,
          viewport.height / bH,
        ) *
        0.80;
    final dx = viewport.width / 2 - (bLeft + bW / 2) * scale;
    final dy = viewport.height / 2 - (bTop + bH / 2) * scale;
    final matrix = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
    _transform.value = matrix;
    _viewerMinScale = CastleFrameGeom.viewerMinScale(
      layoutSize: layout,
      viewport: viewport,
      initialTransform: matrix,
    );
  }

  void _fitMarkStepIfNeeded(
    Size viewport,
    Size layout,
    TileSelectionCalibration cal,
  ) {
    if (_didInitialFit &&
        _lastViewport == viewport &&
        _layoutSize == layout &&
        _markFitReady) {
      return;
    }
    _markFitReady = false;
    _scheduleFit(() => _applyMarkStepFit(viewport, layout, cal));
  }

  ui.Rect _imageCropFromFrame({
    required Rect frame,
    required Size viewport,
    bool forThroneCalibration = false,
  }) {
    final imageSize = _imageSize!;
    final layout = CastleFrameGeom.displayLayoutSize(imageSize, viewport);
    final crop = CastleFrameGeom.imageCropRect(
      frame: frame,
      transform: _transform.value,
      imageWidth: imageSize.width.round(),
      imageHeight: imageSize.height.round(),
      layoutSize: layout,
      controller: _transform,
      forThroneCalibration: forThroneCalibration,
    );
    return ui.Rect.fromLTRB(crop.left, crop.top, crop.right, crop.bottom);
  }

  Future<void> _autoseedFromDetections(ui.Rect bounds) async {
    final throne = _throneRect;
    if (throne == null) return;
    try {
      final store = Provider.of<TfStore>(context, listen: false);
      await store.prepareForScoring();
      final expectedSize = await decodeImagePixelSize(widget.imagePath);
      final decoded = await decodeOrientedImage(
        widget.imagePath,
        expectedSize: expectedSize,
      );
      if (decoded.width == 0 || decoded.height == 0) return;

      final cal = TileSelectionCalibration(
        imagePath: widget.imagePath,
        throneRect: throne,
        boundsRect: bounds,
      );
      final detectRect = Rect.fromLTRB(
        bounds.left.clamp(0, decoded.width.toDouble()),
        bounds.top.clamp(0, decoded.height.toDouble()),
        bounds.right.clamp(0, decoded.width.toDouble()),
        bounds.bottom.clamp(0, decoded.height.toDouble()),
      );
      final guesses = await WindowedDetect.detectCastleWindows(
        store: store,
        decoded: decoded,
        bounds: detectRect,
        tileW: cal.tileWidth,
        tileH: cal.tileHeight,
      );
      final refined = refineCalibrationFromGuesses(cal, guesses);
      _throneRect = refined.throneRect;
      final seeded = WindowedDetect.seedMarkedCells(
        guesses: guesses,
        calibration: refined,
        alwaysMarked: _marked,
      );
      // Remove autoseed artifacts that are not connected to the throne.
      final prunedRel = CastleOccupancy.pruneDisconnected(
        cells: seeded.map((c) => (c.x, c.y)).toSet(),
        throneCell: (0, 0),
      );
      final pruned = prunedRel.map((t) => GridCell(t.$1, t.$2)).toSet();
      _marked
        ..clear()
        ..addAll(pruned);
      log('autoseed marked ${_marked.length} cells from ${guesses.length} detections '
          'tile=${refined.tileWidth.toStringAsFixed(1)}x'
          '${refined.tileHeight.toStringAsFixed(1)} '
          '(throne was ${cal.tileWidth.toStringAsFixed(1)}x'
          '${cal.tileHeight.toStringAsFixed(1)})');
    } catch (ex, st) {
      log('autoseed failed: $ex');
      log(st);
    }
  }

  Future<void> _onContinue() async {
    if (_busy || _imageSize == null || _frame == null || _lastViewport == null) {
      return;
    }

    if (_step == _TileSelectionStep.throne) {
      _snapshotThroneView();
      final throneRect = _imageCropFromFrame(
        frame: _frame!,
        viewport: _lastViewport!,
        forThroneCalibration: true,
      );
      final imageSize = _imageSize!;
      final bounds = ui.Rect.fromLTWH(
        0, 0,
        imageSize.width.toDouble(),
        imageSize.height.toDouble(),
      );
      setState(() {
        _throneRect = throneRect;
        _busy = true;
        _error = null;
      });
      await _autoseedFromDetections(bounds);
      if (!mounted) return;
      setState(() {
        _boundsRect = bounds;
        _step = _TileSelectionStep.mark;
        _busy = false;
        _didInitialFit = false;
        _markFitReady = false;
        _restoreViewOnNextFrame = false;
        _viewerMinScale = 0.01;
      });
      return;
    }

    if (_step == _TileSelectionStep.bounds) {
      _snapshotBoundsView();
      final bounds = _imageCropFromFrame(
        frame: _frame!,
        viewport: _lastViewport!,
      );
      setState(() {
        _busy = true;
        _error = null;
      });
      await _autoseedFromDetections(bounds);
      if (!mounted) return;
      setState(() {
        _boundsRect = bounds;
        _step = _TileSelectionStep.mark;
        _busy = false;
        _didInitialFit = false;
        _markFitReady = false;
        _restoreViewOnNextFrame = false;
        _viewerMinScale = 0.01;
      });
      return;
    }

    if (_step == _TileSelectionStep.mark) {
      if (_marked.length < 3) {
        setState(() => _error = 'Mark at least the throne row and one more tile');
        return;
      }
      await _runClassification();
    }
  }

  Future<void> _runClassification() async {
    final throne = _throneRect;
    final bounds = _boundsRect;
    if (throne == null || bounds == null) return;

    setState(() {
      _busy = true;
      _step = _TileSelectionStep.process;
      _error = null;
      _classifyDone = 0;
      _classifyTotal = _marked.where((c) => !(c.x == 1 && c.y == 0)).length;
    });

    try {
      final store = Provider.of<TfStore>(context, listen: false);
      final calibration = TileSelectionCalibration(
        imagePath: widget.imagePath,
        throneRect: throne,
        boundsRect: bounds,
      );
      final result = await TileSelectionBuilder.buildCastleWithInfo(
        calibration: calibration,
        marked: _marked,
        store: store,
        onProgress: (done, total) {
          if (!mounted) return;
          setState(() {
            _classifyDone = done;
            _classifyTotal = total;
          });
        },
      );
      final grid = result.grid;

      if (!mounted) return;
      if (!grid.items.any((t) => t.tileType == TileType.ThroneRoom)) {
        setState(() {
          _busy = false;
          _step = _TileSelectionStep.mark;
          _error = 'Could not identify a throne room — check alignment or edit in builder';
        });
        return;
      }

      NavigationHelper.goToCastleConfirmScreen(
        context,
        castleTiles: grid,
        imagePath: widget.imagePath,
        replace: true,
        addCastleCallback: widget.addCastleCallback,
        numPicturesTaken: widget.numPicturesTaken,
        gameTitle: widget.gameTitle,
        expectedRoomTileCount: widget.expectedRoomTileCount,
        cellGuesses: result.cellGuesses,
      );
    } catch (ex, st) {
      log(ex);
      log(st);
      if (mounted) {
        setState(() {
          _busy = false;
          _step = _TileSelectionStep.mark;
          _error = ex.toString();
        });
      }
    }
  }

  void _onTapMark(Offset viewportPoint) {
    final throne = _throneRect;
    final bounds = _boundsRect;
    if (throne == null || bounds == null) return;

    final imageSize = _imageSize!;
    final layout = _layoutSize ??
        CastleFrameGeom.displayLayoutSize(
          imageSize,
          _lastViewport ?? const Size(400, 600),
        );
    final imagePoint = CastleFrameGeom.viewportToImageFromController(
      viewportPoint,
      _transform,
      imageSize: imageSize,
      layoutSize: layout,
    );
    final cal = TileSelectionCalibration(
      imagePath: widget.imagePath,
      throneRect: throne,
      boundsRect: bounds,
    );
    final cell = cal.cellAtImagePoint(
      ui.Offset(imagePoint.dx, imagePoint.dy),
    );
    if (cell == null) return;

    setState(() {
      if (cell.x == 0 && cell.y == 0 || cell.x == 1 && cell.y == 0) {
        return; // throne row always on
      }
      if (_marked.contains(cell)) {
        _marked.remove(cell);
      } else {
        _marked.add(cell);
      }
      _error = null;
    });
  }

  void _back() {
    switch (_step) {
      case _TileSelectionStep.bounds:
        _goToStep(_TileSelectionStep.throne);
      case _TileSelectionStep.mark:
        _goToStep(_TileSelectionStep.throne);
      default:
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = _imageSize;
    final isMark = _step == _TileSelectionStep.mark;
    final isProcess = _step == _TileSelectionStep.process;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: FlowBreadcrumb(
          showHome: true,
          onHomeTap: () {
            OrientationHelper.lockPortrait();
            NavigationHelper.popToHome(context);
          },
          segments: _breadcrumbSegments,
          onSegmentTap: _busy ? null : _onBreadcrumbTap,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : _back,
        ),
      ),
      body: imageSize == null
          ? Center(
              child: _error != null
                  ? Text(_error!, style: const TextStyle(color: Colors.white))
                  : const CircularProgressIndicator(),
            )
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final viewport = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );

                      if (!isMark && !isProcess) {
                        final frame = CastleFrameGeom.frameRectAspect(
                          viewport,
                          _frameAspect,
                          maxHeightFraction: _step == _TileSelectionStep.bounds
                              ? 0.82
                              : 0.72,
                        );
                        _frame = frame;
                        final layout = CastleFrameGeom.displayLayoutSize(
                          imageSize,
                          viewport,
                        );
                        _lastViewport = viewport;
                        _layoutSize = layout;
                        if (!_didInitialFit && !_restoreViewOnNextFrame) {
                          _fitIfNeeded(viewport, frame);
                        }

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            InteractiveViewer(
                              transformationController: _transform,
                              constrained: false,
                              panEnabled: _boundsFitScale == null,
                              scaleEnabled: _boundsFitScale == null,
                              panAxis: PanAxis.free,
                              boundaryMargin: const EdgeInsets.all(500),
                              minScale: _boundsFitScale ?? _viewerMinScale,
                              maxScale: _boundsFitScale ?? 8,
                              clipBehavior: Clip.none,
                              child: Image.file(
                                File(widget.imagePath),
                                width: layout.width,
                                height: layout.height,
                                fit: BoxFit.fill,
                              ),
                            ),
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _FrameOverlayPainter(frame: frame),
                                size: viewport,
                              ),
                            ),
                            Positioned(
                              left: 16,
                              right: 16,
                              top: 8,
                              child: Text(
                                _stepHint,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 14,
                                  shadows: const [
                                    Shadow(blurRadius: 4, color: Colors.black),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      final cal = (_throneRect != null && _boundsRect != null)
                          ? TileSelectionCalibration(
                              imagePath: widget.imagePath,
                              throneRect: _throneRect!,
                              boundsRect: _boundsRect!,
                            )
                          : null;

                      final markLayout = CastleFrameGeom.displayLayoutSize(
                        imageSize,
                        viewport,
                      );
                      _lastViewport = viewport;
                      _layoutSize = markLayout;

                      if (isMark && cal != null && !_didInitialFit) {
                        _fitMarkStepIfNeeded(viewport, markLayout, cal);
                      }

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          InteractiveViewer(
                            transformationController: _transform,
                            constrained: false,
                            panAxis: PanAxis.free,
                            boundaryMargin: const EdgeInsets.all(500),
                            minScale: _viewerMinScale,
                            maxScale: 8,
                            clipBehavior: Clip.none,
                            child: Image.file(
                              File(widget.imagePath),
                              width: markLayout.width,
                              height: markLayout.height,
                              fit: BoxFit.fill,
                            ),
                          ),
                          if (cal != null && isMark && _markFitReady)
                            GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTapUp: (d) => _onTapMark(d.localPosition),
                              child: CustomPaint(
                                painter: _GridOverlayPainter(
                                  calibration: cal,
                                  marked: _marked,
                                  transform: _transform.value,
                                  imageToLayoutScale: 1 /
                                      CastleFrameGeom.layoutToImageScale(
                                        imageSize,
                                        markLayout,
                                      ),
                                ),
                                size: viewport,
                              ),
                            ),
                          if (isProcess)
                            Container(
                              color: Colors.black54,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(
                                    '$_classifyDone / $_classifyTotal tiles',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          if (isMark)
                            Positioned(
                              left: 16,
                              right: 16,
                              top: 8,
                              child: Text(
                                _markProgressLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 14,
                                  shadows: const [
                                    Shadow(blurRadius: 4, color: Colors.black),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
                if (!isProcess)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      child: Column(
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Colors.redAccent),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          if (_step == _TileSelectionStep.mark &&
                              _underExpectedMarkCount)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Marked $_markedRoomCellCount of '
                                '${widget.expectedRoomTileCount} expected room tiles '
                                '(throne is not counted) — keep tapping or classify anyway',
                                style: TextStyle(
                                  color: Colors.amber.shade200,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                                iconSize: 22,
                              ),
                              onPressed: _busy ? null : _onContinue,
                              icon: const Icon(Icons.arrow_forward),
                              label: Text(
                                _step == _TileSelectionStep.mark
                                    ? 'Classify tiles'
                                    : 'Continue',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _FrameOverlayPainter extends CustomPainter {
  final Rect frame;

  _FrameOverlayPainter({required this.frame});

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()
      ..addRect(Offset.zero & size)
      ..addRect(frame)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(scrim, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _FrameOverlayPainter old) => old.frame != frame;
}

class _GridOverlayPainter extends CustomPainter {
  final TileSelectionCalibration calibration;
  final Set<GridCell> marked;
  final Matrix4 transform;
  final double imageToLayoutScale;

  _GridOverlayPainter({
    required this.calibration,
    required this.marked,
    required this.transform,
    required this.imageToLayoutScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final cell in calibration.cellsInBounds()) {
      final ir = calibration.cellRect(cell);
      final tl = CastleFrameGeom.layoutToViewport(
        Offset(ir.left * imageToLayoutScale, ir.top * imageToLayoutScale),
        transform,
      );
      final br = CastleFrameGeom.layoutToViewport(
        Offset(ir.right * imageToLayoutScale, ir.bottom * imageToLayoutScale),
        transform,
      );
      final rect = Rect.fromPoints(tl, br);
      final isMarked = marked.contains(cell);
      final isThroneRow = cell.y == 0 && (cell.x == 0 || cell.x == 1);

      canvas.drawRect(
        rect,
        Paint()
          ..color = isMarked
              ? (isThroneRow
                  ? Colors.amber.withValues(alpha: 0.35)
                  : Colors.lightGreen.withValues(alpha: 0.35))
              : Colors.white.withValues(alpha: 0.08)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = isMarked ? Colors.lightGreenAccent : Colors.white38
          ..style = PaintingStyle.stroke
          ..strokeWidth = isMarked ? 2 : 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GridOverlayPainter old) =>
      old.marked != marked ||
      ! _matricesNearEqual(old.transform, transform);

  static bool _matricesNearEqual(Matrix4 a, Matrix4 b) {
    for (var i = 0; i < 16; i++) {
      if ((a.storage[i] - b.storage[i]).abs() > 1e-9) return false;
    }
    return true;
  }
}
