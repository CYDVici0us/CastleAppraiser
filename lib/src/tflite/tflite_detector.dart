import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:btcc/src/tflite/letterbox.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Dart port of the custom `detectObjectOnImageGeneric` / frame path from the
/// previous native `flutter_tflite` fork. Returns JSON-compatible maps matching
/// [TfliteProcessedGuess.fromMap] (`label` is a class index int).
class TfliteDetector {
  Interpreter? _interpreter;
  List<String> _labels = [];
  String? _loadedModelPath;
  String? _loadedLabelsPath;

  Future<void> loadModel({
    required String modelPath,
    required String labelsPath,
    bool isAsset = true,
    int numThreads = 8,
  }) async {
    await close();

    if (isAsset) {
      _interpreter = await Interpreter.fromAsset(
        modelPath,
        options: InterpreterOptions()..threads = numThreads,
      );
      final labelData = await rootBundle.loadString(labelsPath);
      _labels = labelData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      _interpreter = Interpreter.fromFile(
        File(modelPath),
        options: InterpreterOptions()..threads = numThreads,
      );
      _labels = (await File(labelsPath).readAsString())
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    _loadedModelPath = modelPath;
    _loadedLabelsPath = labelsPath;
    log('tflite loaded: $modelPath (${_labels.length} labels)');
  }

  Future<void> close() async {
    _interpreter?.close();
    _interpreter = null;
    _labels = [];
    _loadedModelPath = null;
    _loadedLabelsPath = null;
  }

  bool get isLoaded => _interpreter != null;

  String? get loadedModelPath => _loadedModelPath;
  String? get loadedLabelsPath => _loadedLabelsPath;

  Future<List<String>> detectOnImageFile({
    required String path,
    required int inputImageSize,
    double scoreThreshold = 0.4,
    double overlapThreshold = 0.45,
    double mean = 0,
    double std = 255,
    int rotations = 0,
    bool logExtra = false,
  }) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not decode image at $path');
    }
    return detectOnImage(
      image: decoded,
      inputImageSize: inputImageSize,
      scoreThreshold: scoreThreshold,
      overlapThreshold: overlapThreshold,
      mean: mean,
      std: std,
      rotations: rotations,
      logExtra: logExtra,
    );
  }

  Future<List<String>> detectOnImage({
    required img.Image image,
    required int inputImageSize,
    double scoreThreshold = 0.4,
    double overlapThreshold = 0.45,
    double mean = 0,
    double std = 255,
    int rotations = 0,
    bool logExtra = false,
  }) async {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('TFLite model is not loaded');
    }

    final geometry = LetterboxGeometry.fromImageSize(image.width, image.height);
    final input = _preprocess(
      image: image,
      geometry: geometry,
      inputImageSize: inputImageSize,
      mean: mean,
      std: std,
      rotations: rotations,
    );

    final outputTensors = interpreter.getOutputTensors();
    final outputs = <int, Object>{};
    for (var i = 0; i < outputTensors.length; i++) {
      outputs[i] = _createOutputBuffer(outputTensors[i].shape);
    }

    interpreter.runForMultipleInputs([input], outputs);

    final unraveled = _unravelResults(
      outputs: outputs,
      scoreThreshold: scoreThreshold,
      inputImageSize: inputImageSize,
      rotations: rotations,
      geometry: geometry,
      logExtra: logExtra,
    );

    final nms = _runNms(unraveled, overlapThreshold);
    return nms.map((g) => g.toJsonString()).toList();
  }

  /// Camera YUV420 planes → RGB image → same detection path.
  Future<List<String>> detectOnCameraPlanes({
    required List<Uint8List> bytesList,
    required int imageWidth,
    required int imageHeight,
    required int inputImageSize,
    double scoreThreshold = 0.4,
    double overlapThreshold = 0.45,
    double mean = 0,
    double std = 255,
    int rotations = 3,
    bool logExtra = false,
  }) async {
    final rgb = _yuv420ToImage(bytesList, imageWidth, imageHeight);
    return detectOnImage(
      image: rgb,
      inputImageSize: inputImageSize,
      scoreThreshold: scoreThreshold,
      overlapThreshold: overlapThreshold,
      mean: mean,
      std: std,
      rotations: rotations,
      logExtra: logExtra,
    );
  }

  Float32List _preprocess({
    required img.Image image,
    required LetterboxGeometry geometry,
    required int inputImageSize,
    required double mean,
    required double std,
    required int rotations,
  }) {
    // Pad to square, resize, rotate 90° clockwise `rotations` times, normalize.
    var work = img.Image(width: geometry.padSize, height: geometry.padSize);
    img.fill(work, color: img.ColorRgb8(0, 0, 0));
    img.compositeImage(work, image, dstX: geometry.ox, dstY: geometry.oy);
    work = img.copyResize(
      work,
      width: inputImageSize,
      height: inputImageSize,
      interpolation: img.Interpolation.linear,
    );
    for (var i = 0; i < rotations; i++) {
      work = img.copyRotate(work, angle: 90);
    }

    final buffer = Float32List(1 * inputImageSize * inputImageSize * 3);
    var idx = 0;
    for (var y = 0; y < inputImageSize; y++) {
      for (var x = 0; x < inputImageSize; x++) {
        final p = work.getPixel(x, y);
        buffer[idx++] = (p.r - mean) / std;
        buffer[idx++] = (p.g - mean) / std;
        buffer[idx++] = (p.b - mean) / std;
      }
    }
    return buffer;
  }

  Object _createOutputBuffer(List<int> shape) {
    Object build(List<int> dims) {
      if (dims.isEmpty) return 0.0;
      if (dims.length == 1) {
        return List<double>.filled(dims[0], 0.0);
      }
      return List.generate(dims[0], (_) => build(dims.sublist(1)));
    }

    return build(shape);
  }

  List<_ProcessedGuess> _unravelResults({
    required Map<int, Object> outputs,
    required double scoreThreshold,
    required int inputImageSize,
    required int rotations,
    required LetterboxGeometry geometry,
    required bool logExtra,
  }) {
    final unraveled = <_ProcessedGuess>[];

    void walk(dynamic node, void Function(List<double> leaf) onLeaf) {
      if (node is List) {
        if (node.isNotEmpty && node.first is num) {
          onLeaf(node.map((e) => (e as num).toDouble()).toList());
        } else {
          for (final child in node) {
            walk(child, onLeaf);
          }
        }
      }
    }

    for (final entry in outputs.entries) {
      walk(entry.value, (leaf) {
        if (leaf.length < 6) return;
        final block = _BlockGuess(leaf);
        if (block.highestScore <= scoreThreshold) return;

        final mapped = mapModelBoxToImage(
          xMin: block.xPos - 0.5 * block.width,
          xMax: block.xPos + 0.5 * block.width,
          yMin: block.yPos - 0.5 * block.height,
          yMax: block.yPos + 0.5 * block.height,
          inputImageSize: inputImageSize,
          rotations: rotations,
          geometry: geometry,
        );

        final probability = block.probs[block.highestIndex];
        final guess = _ProcessedGuess(
          xMin: mapped.xMin,
          xMax: mapped.xMax,
          yMin: mapped.yMin,
          yMax: mapped.yMax,
          label: block.highestIndex,
          confidence: block.confidence,
          probability: probability,
          score: block.confidence * probability,
        );

        if (logExtra) {
          final labelName = block.highestIndex < _labels.length
              ? _labels[block.highestIndex]
              : '${block.highestIndex}';
          log('GUESS: ${mapped.valid}, $labelName, $guess');
        }

        if (mapped.valid) {
          unraveled.add(guess);
        }
      });
    }

    return unraveled;
  }

  List<_ProcessedGuess> _runNms(
    List<_ProcessedGuess> guesses,
    double overlapThreshold,
  ) {
    final copy = List<_ProcessedGuess>.from(guesses)
      ..sort((a, b) => b.score.compareTo(a.score));
    final best = <_ProcessedGuess>[];

    while (copy.isNotEmpty) {
      final top = copy.removeAt(0);
      best.add(top);
      copy.removeWhere((g) => top.calculateOverlap(g) > overlapThreshold);
    }
    return best;
  }

  img.Image _yuv420ToImage(
    List<Uint8List> planes,
    int width,
    int height,
  ) {
    final yPlane = planes[0];
    final uPlane = planes[1];
    final vPlane = planes[2];
    final out = img.Image(width: width, height: height);

    // Approximate NV21-style conversion (matches prior plugin byte packing intent).
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final yp = yPlane[y * width + x] & 0xff;
        final uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);
        final up = uPlane[math.min(uvIndex, uPlane.length - 1)] & 0xff;
        final vp = vPlane[math.min(uvIndex, vPlane.length - 1)] & 0xff;
        var r = (yp + 1.370705 * (vp - 128)).round();
        var g = (yp - 0.337633 * (up - 128) - 0.698001 * (vp - 128)).round();
        var b = (yp + 1.732446 * (up - 128)).round();
        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }
}

class _BlockGuess {
  final double xPos;
  final double yPos;
  final double width;
  final double height;
  final double confidence;
  final List<double> probs;
  int highestIndex = 0;
  double highestScore = 0;

  _BlockGuess(List<double> res)
      : xPos = res[0],
        yPos = res[1],
        width = res[2],
        height = res[3],
        confidence = res[4],
        probs = res.sublist(5) {
    var highest = 0.0;
    for (var i = 0; i < probs.length; i++) {
      if (probs[i] > highest) {
        highestIndex = i;
        highest = probs[i];
        highestScore = highest * confidence;
      }
    }
  }
}

class _ProcessedGuess {
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final int label;
  final double probability;
  final double confidence;
  final double score;

  _ProcessedGuess({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.label,
    required this.probability,
    required this.confidence,
    required this.score,
  });

  double area() => (xMax - xMin) * (yMax - yMin);

  double calculateOverlap(_ProcessedGuess other) {
    final xMinInter = math.max(xMin, other.xMin);
    final xMaxInter = math.min(xMax, other.xMax);
    final yMinInter = math.max(yMin, other.yMin);
    final yMaxInter = math.min(yMax, other.yMax);
    final interArea =
        math.max(0, (xMaxInter - xMinInter) * (yMaxInter - yMinInter));
    final unionArea = area() + other.area() - interArea;
    if (unionArea <= 0) return 0;
    return interArea / unionArea;
  }

  String toJsonString() =>
      '{"xMin": $xMin, "xMax": $xMax, "yMin": $yMin, "yMax": $yMax, "score": $score, "label": $label, "probability": $probability, "confidence": $confidence}';
}
