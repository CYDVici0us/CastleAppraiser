import 'dart:io';

import 'package:btcc/src/state/camera_store.dart';
import 'package:btcc/src/state/data_store.dart';
import 'package:btcc/src/state/tf_store.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';
import 'package:btcc/src/utils/image_helper.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/orientation_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class CameraScreen extends StatefulWidget {

  final int numPicturesTaken;
  final List<CameraDescription> cameras;
  final AddCastleToGameCallback addCastleCallback;
  final String? gameTitle;
  CameraScreen({
    required this.cameras,
    required this.addCastleCallback,
    this.numPicturesTaken=0,
    this.gameTitle,
  });

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with TickerProviderStateMixin {
  late CameraController controller;
  late bool controllerInitialized;

  _CameraScreenState();

  String? imagePath;
  bool savingImage = false;
  double _startScaleFactor = 1;
  double _scaleFactor = 1;

  double _zoomMin = 1;
  double _zoomMax = 2;
  List<TfliteProcessedGuess> guesses = [];

  @override
  void initState() {
    super.initState();
    controllerInitialized = false;
    CameraStore store = Provider.of<CameraStore>(context, listen: false);
    controller = CameraController(
      widget.cameras[0],
      store.resolution,
      enableAudio: false,
    );

    const MethodChannel _channel = const MethodChannel('com.btcc.app/camera');
    _channel.invokeMethod('setSensorOrientation');

    var tfStore = Provider.of<TfStore>(context, listen: false);

    if (tfStore.useIdentifyModel) {
      tfStore.prepareForIdentify().then((_) async {
        controller.initialize().then((__) async {

          if (!mounted) {
            return;
          }

          _zoomMin = await controller.getMinZoomLevel();
          _zoomMax = await controller.getMaxZoomLevel();
          print('Zoom: $_zoomMin, $_zoomMax');

          controller.startImageStream((image) async {
            if (!mounted) {
              return;
            }
            var innerTfStore = Provider.of<TfStore>(context, listen: false);
            var res = await innerTfStore.runOnFrame(image);

            if (mounted) {
              setState(() {
                guesses = res;
              });
            }
          });

          setState(() {controllerInitialized = true;});
        });
      });
    }
    else {
      tfStore.prepareForScoring().then((_) async {
        controller.initialize().then((__) async {
          setState(() {controllerInitialized = true;});
        });
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    const MethodChannel _channel = const MethodChannel('com.btcc.app/camera');
    _channel.invokeMethod('setUserOrientation');
    OrientationHelper.lockPortrait();

    super.dispose();
  }

  bool _readyForPicture() {
    return controller.value.isInitialized &&
        !controller.value.isTakingPicture;
  }

  Future<void> _onTakePicturePressed(String dirPath) async {
    if (!_readyForPicture()) {
      log('not ready for picture');
      return;
    }

    setState((){
      savingImage = true;
    });

    logNow(tag:'1TakePicture');
    String? res = await _takePicture(dirPath);
    logNow(tag:'2TakePicture');

    if (res == null) {
      log('error when taking picture');

      setState((){
        savingImage = false;
      });
      return;
    }

    var rotation = await ImageHelper.getImageRotation(res);

    NavigationHelper.goToPreCastleScreen(context, res,
      rotation: rotation,
      replace: true,
      addCastleCallback: widget.addCastleCallback,
      numPicturesTaken: widget.numPicturesTaken+1,
      gameTitle: widget.gameTitle,
    );
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<String?> _takePicture(String dirPath) async {
    if (!_readyForPicture()) {
      log('still not ready for picture');
      return '';
    }

    try {
      var picture = await controller.takePicture();

      var dir = Directory(dirPath);
      bool exists = await dir.exists();
      if (!exists) {
        await dir.create(recursive: true);
      }

      final String filePath = '$dirPath/${timestamp()}.jpg';

      await picture.saveTo(filePath);

      File file = new File(picture.path);
      await file.delete();

      return filePath;
    } on CameraException catch (e) {
      log(e.toString());
      return null;
    }
  }

  /// Same landscape check CameraPreview uses when choosing its AspectRatio.
  double _previewAspectRatio(CameraValue value) {
    final orientation = value.previewPauseOrientation ??
        value.lockedCaptureOrientation ??
        value.deviceOrientation;
    final isLandscape = orientation == DeviceOrientation.landscapeLeft ||
        orientation == DeviceOrientation.landscapeRight;
    return isLandscape ? value.aspectRatio : 1 / value.aspectRatio;
  }

  /// Fills available space with cover-fit. Child size tracks CameraPreview's
  /// portrait/landscape aspect so portrait is not a cropped landscape frame.
  Widget _cameraPreviewWidget(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) async {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final local = box.globalToLocal(details.globalPosition);
        final x = (local.dx / box.size.width).clamp(0.0, 1.0);
        final y = (local.dy / box.size.height).clamp(0.0, 1.0);
        await controller.setFocusPoint(Offset(x, y));
      },
      onScaleStart: (details) {
        _startScaleFactor = _scaleFactor;
      },
      onScaleUpdate: (details) {
        _scaleFactor = _startScaleFactor * details.scale;

        if (_scaleFactor < _zoomMin) {
          _scaleFactor = _zoomMin;
        }

        if (_scaleFactor > _zoomMax) {
          _scaleFactor = _zoomMax;
        }

        controller.setZoomLevel(_scaleFactor);
      },
      onScaleEnd: (details) async {
        _startScaleFactor = 1;
      },
      child: ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(
          child: !controller.value.isInitialized
              ? const SizedBox.shrink()
              : ValueListenableBuilder<CameraValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    final previewAspect = _previewAspectRatio(value);
                    return FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: 1000,
                        height: 1000 / previewAspect,
                        child: child,
                      ),
                    );
                  },
                  child: CameraPreview(controller),
                ),
        ),
      ),
    );
  }

  void _goBack() {
    OrientationHelper.lockPortrait();
    Navigator.of(context).pop();
  }

  Widget _controlsWidget(String dirPath, {required bool portrait}) {
    final backButton = FloatingActionButton(
      heroTag: 'camera_back',
      backgroundColor: Colors.blueGrey,
      onPressed: _goBack,
      child: const Icon(Icons.arrow_back),
    );
    final shutterButton = FloatingActionButton(
      heroTag: 'camera_shutter',
      onPressed: savingImage ? null : () => _onTakePicturePressed(dirPath),
      child: !savingImage
          ? const Icon(Icons.camera)
          : const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
    );

    if (portrait) {
      return SizedBox(
        height: 96,
        child: Stack(
          alignment: Alignment.center,
          children: [
            shutterButton,
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 24),
                child: backButton,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          shutterButton,
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: backButton,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!controllerInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Initializing cameras...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 8,
              child: FloatingActionButton(
                heroTag: 'camera_back_loading',
                mini: true,
                backgroundColor: Colors.blueGrey,
                onPressed: _goBack,
                child: const Icon(Icons.arrow_back),
              ),
            ),
          ],
        ),
      );
    }

    return Consumer<DataStore>(
      builder: (_, model, __) {
        final portrait =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        final preview = Expanded(
          child: _cameraPreviewWidget(context),
        );
        final controls = _controlsWidget(
          model.imagesTempPath,
          portrait: portrait,
        );

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: portrait
                ? Column(children: [preview, controls])
                : Row(children: [preview, controls]),
          ),
        );
      },
    );
  }
}
