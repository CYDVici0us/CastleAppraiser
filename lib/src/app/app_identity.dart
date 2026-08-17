/// Platform identity for Castle Appraiser 2.0 — a separate install from the
/// published app (`com.btcc.app`).
class AppIdentity {
  AppIdentity._();

  static const String androidApplicationId = 'com.btcc.app2';
  static const String iosBundleId = 'com.btcc.app2';

  static const String cameraChannel = '$androidApplicationId/camera';
  static const String tfliteChannel = '$androidApplicationId/tflite';

  static const String displayName = 'Castle Appraiser 2.0';
}
