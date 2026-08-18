import 'dart:io';
import 'dart:math' as math;

import 'package:btcc/src/utils/castle_frame_crop.dart';
import 'package:btcc/src/utils/image_helper.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/orientation_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:flutter/material.dart';

/// User frames the castle in a portrait or landscape box (zoom/pan the photo
/// under a fixed overlay), then we crop that region for detection.
class CastleFrameScreen extends StatefulWidget {
  final String imagePath;
  final ImageRotation rotation;
  final AddCastleToGameCallback addCastleCallback;
  final int numPicturesTaken;
  final String? gameTitle;
  final int? expectedRoomTileCount;

  const CastleFrameScreen({
    super.key,
    required this.imagePath,
    required this.addCastleCallback,
    this.rotation = ImageRotation.Normal,
    this.numPicturesTaken = 0,
    this.gameTitle,
    this.expectedRoomTileCount,
  });

  @override
  State<CastleFrameScreen> createState() => _CastleFrameScreenState();
}

class _CastleFrameScreenState extends State<CastleFrameScreen> {
  final TransformationController _transform = TransformationController();

  Size? _imageSize;
  Rect? _frame;
  bool _portraitFrame = true;
  bool _busy = false;
  String? _error;
  bool _didInitialFit = false;
  Size? _lastViewport;
  Size? _layoutSize;

  @override
  void initState() {
    super.initState();
    OrientationHelper.lockPortrait();
    _loadSize();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
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
      if (mounted) {
        setState(() => _error = 'Could not load image: $ex');
      }
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
    _lastViewport = viewport;
    _layoutSize = layout;
    _didInitialFit = true;
    _transform.value = CastleFrameGeom.coverFrame(
      frame: frame,
      layoutSize: layout,
    );
  }

  void _toggleOrientation() {
    setState(() {
      _portraitFrame = !_portraitFrame;
      _didInitialFit = false;
    });
  }

  Future<void> _useFrame() async {
    final imageSize = _imageSize;
    final frame = _frame;
    if (imageSize == null || frame == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final layout = _layoutSize ??
          CastleFrameGeom.displayLayoutSize(
            imageSize,
            _lastViewport ?? Size(frame.width, frame.height),
          );
      final crop = CastleFrameGeom.imageCropRect(
        frame: frame,
        transform: _transform.value,
        imageWidth: imageSize.width.round(),
        imageHeight: imageSize.height.round(),
        layoutSize: layout,
      );

      final dir = File(widget.imagePath).parent.path;
      final dest =
          '$dir/framed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await writeCastleFrameCrop(
        sourcePath: widget.imagePath,
        destPath: dest,
        crop: crop,
      );

      if (!mounted) return;
      NavigationHelper.goToPreCastleScreen(
        context,
        dest,
        rotation: ImageRotation.Normal,
        replace: true,
        addCastleCallback: widget.addCastleCallback,
        numPicturesTaken: widget.numPicturesTaken,
        gameTitle: widget.gameTitle,
        expectedRoomTileCount: widget.expectedRoomTileCount,
      );
    } catch (ex, st) {
      log(ex);
      log(st);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = ex.toString();
        });
      }
    }
  }

  Future<void> _useFullPhoto() async {
    if (_busy) return;
    setState(() => _busy = true);
    if (!mounted) return;
    NavigationHelper.goToPreCastleScreen(
      context,
      widget.imagePath,
      rotation: widget.rotation,
      replace: true,
      addCastleCallback: widget.addCastleCallback,
      numPicturesTaken: widget.numPicturesTaken,
      gameTitle: widget.gameTitle,
      expectedRoomTileCount: widget.expectedRoomTileCount,
    );
  }

  void _cancel() {
    OrientationHelper.lockPortrait();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final imageSize = _imageSize;

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
          segments: [widget.gameTitle ?? 'Game', 'Frame'],
          onSegmentTap: (index) {
            if (index == 0) _cancel();
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _busy ? null : _cancel,
        ),
      ),
      body: imageSize == null
          ? Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    )
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
                      final frame = CastleFrameGeom.frameRect(
                        viewport,
                        portrait: _portraitFrame,
                      );
                      _frame = frame;
                      final layout = CastleFrameGeom.displayLayoutSize(
                        imageSize,
                        viewport,
                      );
                      _layoutSize = layout;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        _fitIfNeeded(viewport, frame);
                      });

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          InteractiveViewer(
                            transformationController: _transform,
                            constrained: false,
                            panAxis: PanAxis.free,
                            boundaryMargin: const EdgeInsets.all(120),
                            minScale: 0.15,
                            maxScale: 8,
                            clipBehavior: Clip.none,
                            child: Image.file(
                              File(widget.imagePath),
                              width: layout.width,
                              height: layout.height,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _FrameOverlayPainter(frame: frame),
                              size: viewport,
                            ),
                          ),
                          Positioned(
                            left: frame.left,
                            top: math.max(8, frame.top - 28),
                            width: frame.width,
                            child: Text(
                              _portraitFrame
                                  ? 'Portrait castle — include basement, wings, '
                                      'bonus cards & attendants'
                                  : 'Landscape castle — include basement, wings, '
                                      'bonus cards & attendants',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 13,
                                shadows: const [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
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
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white54),
                                ),
                                onPressed: _busy ? null : _toggleOrientation,
                                icon: Icon(
                                  _portraitFrame
                                      ? Icons.crop_landscape
                                      : Icons.crop_portrait,
                                ),
                                label: Text(
                                  _portraitFrame
                                      ? 'Landscape box'
                                      : 'Portrait box',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _busy ? null : _useFrame,
                                icon: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.check),
                                label: const Text('Use frame'),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: _busy ? null : _useFullPhoto,
                          child: const Text(
                            'Use full photo',
                            style: TextStyle(color: Colors.white70),
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
    canvas.drawPath(
      scrim,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    canvas.drawRect(
      frame,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
    final tick = math.min(frame.width, frame.height) * 0.08;
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.lightBlueAccent;
    void corner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o.translate(dx * tick, 0), tickPaint);
      canvas.drawLine(o, o.translate(0, dy * tick), tickPaint);
    }

    corner(frame.topLeft, 1, 1);
    corner(frame.topRight, -1, 1);
    corner(frame.bottomLeft, 1, -1);
    corner(frame.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _FrameOverlayPainter oldDelegate) =>
      oldDelegate.frame != frame;
}
