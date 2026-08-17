import 'dart:io';
import 'dart:typed_data';

import 'package:btcc/src/tflite/tflite_detector.dart';
import 'package:btcc/src/tflite/tflite_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Loads the scoring model and prints tensor shapes + a smoke detection count.
/// Run with: flutter test test/tflite_smoke_test.dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('scoring model smoke detection', () async {
    final model = TfliteModel.scoring;
    final interpreter = await Interpreter.fromAsset(model.file);
    final inputs = interpreter.getInputTensors();
    final outputs = interpreter.getOutputTensors();

    // ignore: avoid_print
    print('INPUTS:');
    for (final t in inputs) {
      // ignore: avoid_print
      print('  ${t.name} shape=${t.shape} type=${t.type}');
    }
    // ignore: avoid_print
    print('OUTPUTS:');
    for (final t in outputs) {
      // ignore: avoid_print
      print('  ${t.name} shape=${t.shape} type=${t.type}');
    }

    final detector = TfliteDetector();
    await detector.loadModel(
      modelPath: model.file,
      labelsPath: model.labels,
      isAsset: true,
    );

    // Synthetic "castle-ish" image: colorful blocks so the net isn't all zeros.
    final image = img.Image(width: 800, height: 600);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        image.setPixelRgb(
          x,
          y,
          (x * 3) % 255,
          (y * 5) % 255,
          ((x + y) * 2) % 255,
        );
      }
    }

    for (final threshold in [0.01, 0.1, 0.4]) {
      for (final rotations in [0, 1, 2, 3]) {
        final results = await detector.detectOnImage(
          image: image,
          inputImageSize: model.inputImageSize,
          scoreThreshold: threshold,
          overlapThreshold: 0.45,
          mean: 0,
          std: 255,
          rotations: rotations,
          logExtra: false,
        );
        // ignore: avoid_print
        print(
          'threshold=$threshold rotations=$rotations → ${results.length} detections',
        );
      }
    }

    // Also try mean/std 127.5 which Debug ML UI used to suggest.
    final alt = await detector.detectOnImage(
      image: image,
      inputImageSize: model.inputImageSize,
      scoreThreshold: 0.01,
      mean: 127.5,
      std: 127.5,
      rotations: 0,
    );
    // ignore: avoid_print
    print('alt mean/std 127.5 threshold=0.01 → ${alt.length} detections');

    await detector.close();
    interpreter.close();
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('input byte path does not resize tensor', () async {
    final model = TfliteModel.scoring;
    final interpreter = await Interpreter.fromAsset(model.file);
    final shapeBefore = List<int>.from(interpreter.getInputTensors().first.shape);

    final floats = Float32List(1 * model.inputImageSize * model.inputImageSize * 3);
    final bytes = Uint8List.view(
      floats.buffer,
      floats.offsetInBytes,
      floats.lengthInBytes,
    );

    final outputs = <int, Object>{};
    final outTensors = interpreter.getOutputTensors();
    for (var i = 0; i < outTensors.length; i++) {
      Object build(List<int> dims) {
        if (dims.isEmpty) return 0.0;
        if (dims.length == 1) return List<double>.filled(dims[0], 0.0);
        return List.generate(dims[0], (_) => build(dims.sublist(1)));
      }

      outputs[i] = build(outTensors[i].shape);
    }

    interpreter.runForMultipleInputs([bytes], outputs);
    final shapeAfter = interpreter.getInputTensors().first.shape;
    // ignore: avoid_print
    print('shape before=$shapeBefore after=$shapeAfter');
    expect(shapeAfter, shapeBefore);

    // Contrast: Float32List would resize — document expected broken shape.
    try {
      interpreter.runForMultipleInputs([floats], outputs);
      // ignore: avoid_print
      print('after Float32List input shape=${interpreter.getInputTensors().first.shape}');
    } catch (e) {
      // ignore: avoid_print
      print('Float32List path error (expected possible): $e');
    }

    interpreter.close();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
