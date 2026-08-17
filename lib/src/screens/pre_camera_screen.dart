import 'dart:io';

import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/screens/camera_screen.dart';
import 'package:btcc/src/state/camera_store.dart';
import 'package:btcc/src/state/data_store.dart';
import 'package:btcc/src/utils/image_helper.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/orientation_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:btcc/src/widgets/flow_breadcrumb.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Chooser before any camera open: gallery never touches CameraX.
class PreCameraScreen extends StatefulWidget {
  final int numPicturesTaken;
  final AddCastleToGameCallback addCastleCallback;
  final String? gameTitle;

  PreCameraScreen({
    required this.addCastleCallback,
    this.numPicturesTaken = 0,
    this.gameTitle,
  });

  @override
  State<PreCameraScreen> createState() => _PreCameraScreenState();
}

class _PreCameraScreenState extends State<PreCameraScreen> {
  bool _openCamera = false;
  bool _busy = false;
  String? _galleryError;

  Future<void> _onTakePhoto() async {
    setState(() {
      _busy = true;
      _galleryError = null;
    });
    final store = Provider.of<CameraStore>(context, listen: false);
    await store.ensureCamerasReady();
    if (!mounted) return;
    OrientationHelper.unlockForCamera();
    setState(() {
      _busy = false;
      _openCamera = true;
    });
  }

  Future<void> _onPickFromGallery() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _galleryError = null;
    });

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final dataStore = Provider.of<DataStore>(context, listen: false);
      final dirPath = dataStore.imagesTempPath;
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final destPath =
          '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(picked.path).copy(destPath);

      final rotation = await ImageHelper.getImageRotation(destPath);
      if (!mounted) return;

      NavigationHelper.goToPhotoWorkflowScreen(
        context,
        destPath,
        rotation: rotation,
        replace: true,
        addCastleCallback: widget.addCastleCallback,
        numPicturesTaken: widget.numPicturesTaken + 1,
        gameTitle: widget.gameTitle,
      );
    } catch (ex) {
      log(ex);
      if (mounted) {
        setState(() {
          _busy = false;
          _galleryError = ex.toString();
        });
      }
    }
  }

  void _backFromCameraAttempt() {
    OrientationHelper.lockPortrait();
    setState(() => _openCamera = false);
  }

  Widget _chooser(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FlowBreadcrumb(
          showHome: true,
          onHomeTap: () => NavigationHelper.popToHome(context),
          segments: [widget.gameTitle ?? 'Game', 'Add castle'],
          onSegmentTap: (index) {
            if (index == 0) Navigator.of(context).pop();
          },
        ),
      ),
      body: BackgroundContainer(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Add a castle photo',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _onPickFromGallery,
                    icon: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library),
                    label: const Text('Choose from gallery'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _onTakePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take a photo'),
                  ),
                ),
                if (_galleryError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _galleryError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cameraGate(BuildContext context, CameraStore model) {
    if (model.readyForCameras) {
      return CameraScreen(
        cameras: model.cameras,
        addCastleCallback: widget.addCastleCallback,
        numPicturesTaken: widget.numPicturesTaken,
        gameTitle: widget.gameTitle,
      );
    }

    final permissionsNeeded = Column(
      children: [
        const Text(
          'We need permission to use the camera to take a picture of the castle.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            await model.requestCameraPermission();
          },
          child: const Text('Grant camera permission'),
        ),
        TextButton(
          onPressed: _backFromCameraAttempt,
          child: const Text('Back'),
        ),
      ],
    );

    final noCamerasFound = Column(
      children: [
        const Text(
          'No cameras were found on this device. Please try restarting the app.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async => await model.initCameras(),
          child: const Text('Try again'),
        ),
        TextButton(
          onPressed: _backFromCameraAttempt,
          child: const Text('Back'),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: FlowBreadcrumb(
          showHome: true,
          onHomeTap: () => NavigationHelper.popToHome(context),
          segments: [widget.gameTitle ?? 'Game', 'Camera'],
          onSegmentTap: (index) {
            if (index == 0) Navigator.of(context).pop();
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _backFromCameraAttempt,
        ),
      ),
      body: BackgroundContainer(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (model.error == Error.CAMERA_PERMISSION_DENIED)
                  permissionsNeeded,
                if (model.error == Error.NO_CAMERAS_FOUND) noCamerasFound,
                if (model.error == Error.NONE && !model.readyForCameras)
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraStore>(
      builder: (_, model, __) {
        if (_openCamera) return _cameraGate(context, model);
        return _chooser(context);
      },
    );
  }
}
