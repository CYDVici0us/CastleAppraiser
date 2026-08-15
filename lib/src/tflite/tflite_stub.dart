/// Temporary stub for the removed `package:tflite` API.
/// Full detection rewrite (tflite_flutter) is handled separately.
library tflite;

class Tflite {
  static Future<String?> loadModel({
    required String model,
    required String labels,
    bool isAsset = true,
    int numThreads = 1,
    bool useGpuDelegate = false,
  }) async {
    return 'stub';
  }

  static Future<List> detectObjectOnImageGeneric({
    required String path,
    required int inputImageSize,
    required double scoreThreshold,
    required double overlapThreshold,
    required double mean,
    required double std,
    required int rotations,
    bool logExtra = false,
  }) async {
    return [];
  }

  static Future<List> detectObjectOnFrameGeneric({
    required List bytesList,
    required int inputImageSize,
    required int imageHeight,
    required int imageWidth,
    required double scoreThreshold,
    required double overlapThreshold,
    required double mean,
    required double std,
    required int rotations,
  }) async {
    return [];
  }

  static Future close() async {}
}
