import 'dart:collection';

import 'package:btcc/src/app/app_identity.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:btcc/src/models/exports.dart';

enum CameraTech {
  NATIVE,
  CAMERA_PLUGIN,
}

class CameraStore extends ChangeNotifier {

  CameraTech _cameraTech = CameraTech.CAMERA_PLUGIN;
  CameraTech get cameraTech => _cameraTech;
  set cameraTech(CameraTech other) {
    _cameraTech = other;
    notifyListeners();
  }

  Error _error = Error.NONE;
  Error get error => _error;
  bool get hasError => error != Error.NONE;


  bool _hasCameraPermissions = false;
  bool get hasCameraPermissions => _hasCameraPermissions;

  ResolutionPreset _resolution = ResolutionPreset.veryHigh;
  ResolutionPreset get resolution => _resolution;
  set resolution(ResolutionPreset other){
    _resolution = other;
    notifyListeners();
  }

  final List<CameraDescription> _cameras = [];
  UnmodifiableListView<CameraDescription> get cameras => UnmodifiableListView(_cameras);
  bool get readyForCameras => (hasCameraPermissions && cameras.length > 0);

  CameraStore() {
    // Cameras stay lazy until the user taps "Take a photo" so gallery
    // never touches the camera stack.
  }

  /// Permission + discover cameras (idempotent).
  Future<void> ensureCamerasReady() async {
    if (readyForCameras) return;
    if (!_hasCameraPermissions) {
      final granted = await Permission.camera.isGranted;
      if (granted) {
        _hasCameraPermissions = true;
      } else {
        await requestCameraPermission();
        return;
      }
    }
    if (_cameras.isEmpty) {
      await initCameras();
    }
  }

  Future<void> initCameras() async {
    _hasCameraPermissions = await Permission.camera.isGranted;
    if (!_hasCameraPermissions) {
      _error = Error.CAMERA_PERMISSION_DENIED;
    } else {
      final cameras = await _getCameras();
      _cameras
        ..clear()
        ..addAll(cameras);
    }

    notifyListeners();
  }

  Future<void> requestCameraPermission() async {
    PermissionStatus status = await Permission.camera.request();
    if (status.isGranted) {
      _hasCameraPermissions = true;
      final cameras = await _getCameras();
      _cameras
        ..clear()
        ..addAll(cameras);
    } else {
      _error = Error.CAMERA_PERMISSION_DENIED;
    }

    notifyListeners();
  }

  Future<List<CameraDescription>> _getCameras() async {
    List<CameraDescription> result = [];
    var cams = await availableCameras();
    log(cams);
    if (cams.length > 0) {
      _error = Error.NONE;
      result.addAll(cams);
    }
    else {
      _error = Error.NO_CAMERAS_FOUND;
    }

    return result;
  }

  static Future<String?> takePictureNative() async {
    try {
      PermissionStatus status = await Permission.camera.request();
      if (!status.isGranted) {
        return null;
      }

      const MethodChannel _channel = MethodChannel(AppIdentity.cameraChannel);
      var value = await _channel.invokeMethod('getPicture');
      return value as String?;
    } catch (e) {
      log('TakePicture: $e');
      return null;
    }
  }


}