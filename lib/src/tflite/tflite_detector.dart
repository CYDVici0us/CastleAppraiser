import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:btcc/src/tflite/flex_delegate.dart';
import 'package:btcc/src/tflite/image_pipeline_mode.dart';
import 'package:btcc/src/tflite/letterbox_coords.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Snapshot of one detection pass — shown on Debug ML status line.
class DetectionDiag {
  final int rotations;
  final int leaves;
  final double maxScore;
  final int aboveThreshold;
  final int afterNms;
  final double scoreThreshold;
  final int expectedAttrs;
  final int labelCount;

  const DetectionDiag({
    required this.rotations,
    required this.leaves,
    required this.maxScore,
    required this.aboveThreshold,
    required this.afterNms,
    required this.scoreThreshold,
    required this.expectedAttrs,
    required this.labelCount,
  });

  String get statusLine =>
      'unravel: leaves=$leaves maxScore=${maxScore.toStringAsFixed(4)} '
      'aboveThreshold=$aboveThreshold afterNms=$afterNms '
      'threshold=$scoreThreshold rotations=$rotations '
      'expectedAttrs=$expectedAttrs labels=$labelCount';
}

/// Dart port of the custom `detectObjectOnImageGeneric` / frame path from the
/// previous native `flutter_tflite` fork. Returns JSON-compatible maps matching
/// [TfliteProcessedGuess.fromMap] (`label` is a class index int).
class TfliteDetector {
  Interpreter? _interpreter;
  List<String> _labels = [];
  String? _loadedModelPath;
  String? _loadedLabelsPath;

  DetectionDiag? lastDiag;
  DetectionDiag? get lastDetectionDiag => lastDiag;
  int _lastLeavesSeen = 0;
  double _lastMaxScore = 0;

  /// When true, always swap W/H for box mapping and use strict edge rejection
  /// (original native-plugin / early Dart port behavior).
  ImagePipelineMode pipelineMode = ImagePipelineMode.modern;

  Future<InterpreterOptions> _buildOptions({int numThreads = 8}) async {
    final options = InterpreterOptions()..threads = numThreads;
    final flex = await acquireAndroidFlexDelegate();
    if (flex != null) {
      options.addDelegate(flex);
      log('tflite: attached Android Flex (Select TF ops) delegate');
    } else {
      log('tflite: no Flex delegate (non-Android or channel unavailable)');
    }
    return options;
  }

  Future<void> loadModel({
    required String modelPath,
    required String labelsPath,
    bool isAsset = true,
    int numThreads = 8,
  }) async {
    await close();

    final options = await _buildOptions(numThreads: numThreads);

    if (isAsset) {
      _interpreter = await Interpreter.fromAsset(
        modelPath,
        options: options,
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
        options: options,
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

  /// Public so [TfStore] can decode once and run multiple rotations.
  Future<img.Image> decodeImageFile(String path) => _decodeImageFile(path);

  Future<List<String>> detectOnImageFile({
    required String path,
    required int inputImageSize,
    double scoreThreshold = 0.3,
    double overlapThreshold = 0.45,
    double mean = 0,
    double std = 255,
    int rotations = 0,
    bool logExtra = false,
  }) async {
    final decoded = await _decodeImageFile(path);
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

  /// Prefer package:image; modern mode falls back to Flutter's codec for
  /// HEIC/WebP/etc. Legacy matches pre-August and only uses package:image.
  Future<img.Image> _decodeImageFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      log('decoded via package:image ${decoded.width}x${decoded.height}');
      return decoded;
    }

    if (pipelineMode == ImagePipelineMode.legacy) {
      throw Exception('Could not decode image at $path');
    }

    log('package:image failed for $path; trying Flutter codec');
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final uiImage = frame.image;
    final bd = await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) {
      throw Exception('Could not decode image at $path');
    }
    final rgba = bd.buffer.asUint8List();
    final out = img.Image(width: uiImage.width, height: uiImage.height);
    var i = 0;
    for (var y = 0; y < uiImage.height; y++) {
      for (var x = 0; x < uiImage.width; x++) {
        out.setPixelRgba(x, y, rgba[i], rgba[i + 1], rgba[i + 2], rgba[i + 3]);
        i += 4;
      }
    }
    uiImage.dispose();
    log('decoded via Flutter codec ${out.width}x${out.height}');
    return out;
  }

  Future<List<String>> detectOnImage({
    required img.Image image,
    required int inputImageSize,
    double scoreThreshold = 0.3,
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

    // Shrink huge gallery photos before pad-to-square. Model input is only
    // [inputImageSize]²; padding a 4000² canvas four times was very slow.
    // Boxes are scaled back to the full-resolution bitmap afterwards.
    final fullW = image.width;
    final fullH = image.height;
    final detectImage = _shrinkForDetect(image, inputImageSize);
    final scaleX = fullW / detectImage.width;
    final scaleY = fullH / detectImage.height;
    if (detectImage.width != fullW || detectImage.height != fullH) {
      log('detect shrink ${fullW}x$fullH → '
          '${detectImage.width}x${detectImage.height}');
    }

    // Legacy: always swap (matched native plugin). Modern uses letterbox undo
    // instead of swapDims+unrotate (critical for portrait: side tiles were
    // compressed into the center tower and NMS'd away).
    final useLetterboxUndo = pipelineMode == ImagePipelineMode.modern;
    final swapDims = pipelineMode == ImagePipelineMode.legacy
        ? true
        : rotations.isOdd;
    final letterbox = LetterboxGeom.fromSource(
      srcW: detectImage.width,
      srcH: detectImage.height,
      inputSize: inputImageSize,
      rotations: rotations,
    );
    final originalImageWidth = useLetterboxUndo
        ? inputImageSize.toDouble()
        : (swapDims ? detectImage.height : detectImage.width).toDouble();
    final originalImageHeight = useLetterboxUndo
        ? inputImageSize.toDouble()
        : (swapDims ? detectImage.width : detectImage.height).toDouble();
    log('pipeline=${pipelineMode.shortLabel} rotations=$rotations '
        'letterboxUndo=$useLetterboxUndo '
        'pad=${letterbox.padSize} ox=${letterbox.ox} oy=${letterbox.oy} '
        'bitmap=${detectImage.width}x${detectImage.height}');

    final input = _preprocess(
      image: detectImage,
      inputImageSize: inputImageSize,
      mean: mean,
      std: std,
      rotations: rotations,
      padSize: letterbox.padSize,
      ox: letterbox.ox,
      oy: letterbox.oy,
    );

    final inputTensors = interpreter.getInputTensors();
    final outputTensors = interpreter.getOutputTensors();
    if (logExtra) {
      log('input tensors: ${inputTensors.map((t) => '${t.shape}/${t.type}').toList()}');
      log('output tensors: ${outputTensors.map((t) => '${t.shape}/${t.type}').toList()}');
      log('input buffer floats=${input.length} bytes=${input.lengthInBytes}');
    }

    // Pass raw float32 bytes (Uint8List view). A bare Float32List is treated as
    // shape [N] and tflite_flutter will resize the input tensor to 1-D, which
    // silently destroys [1,H,W,3] and yields zero detections.
    final inputBytes = Uint8List.view(
      input.buffer,
      input.offsetInBytes,
      input.lengthInBytes,
    );

    final expectedBytes = inputTensors.isEmpty
        ? input.lengthInBytes
        : inputTensors.first.numElements() * 4;
    if (input.lengthInBytes != expectedBytes) {
      throw StateError(
        'Input size mismatch: prepared ${input.lengthInBytes} bytes but model '
        'expects $expectedBytes (shape ${inputTensors.first.shape}). '
        'Check InputImageSize matches the loaded model '
        '(scoring=1664, identify=320).',
      );
    }

    final outputs = <int, Object>{};
    for (var i = 0; i < outputTensors.length; i++) {
      outputs[i] = _createOutputBuffer(outputTensors[i].shape);
    }

    interpreter.runForMultipleInputs([inputBytes], outputs);

    // Model-space boxes (inputSize²). Legacy then scales with swapDims;
    // modern undoes pad→resize→rotate into detectImage coordinates.
    final unraveled = _unravelResults(
      outputs: outputs,
      scoreThreshold: scoreThreshold,
      inputImageSize: inputImageSize,
      originalImageWidth: originalImageWidth,
      originalImageHeight: originalImageHeight,
      logExtra: logExtra,
      rotations: rotations,
      strictEdges: pipelineMode == ImagePipelineMode.legacy,
    );

    var mapped = unraveled;
    if (useLetterboxUndo) {
      mapped = [];
      for (final g in unraveled) {
        final box = undoLetterboxBox(
          xMin: g.xMin,
          xMax: g.xMax,
          yMin: g.yMin,
          yMax: g.yMax,
          g: letterbox,
        );
        if (box.xMin >= box.xMax || box.yMin >= box.yMax) continue;
        mapped.add(_ProcessedGuess(
          xMin: box.xMin,
          xMax: box.xMax,
          yMin: box.yMin,
          yMax: box.yMax,
          score: g.score,
          label: g.label,
          probability: g.probability,
          confidence: g.confidence,
        ));
      }
      log('letterbox undo → ${mapped.length} boxes in '
          '${detectImage.width}x${detectImage.height}');
    } else if (rotations % 4 != 0) {
      // Legacy-style swapDims path with unrotate (kept for A/B).
      mapped = _unrotateGuessesToSource(
        mapped,
        rotations: rotations % 4,
        sourceWidth: detectImage.width.toDouble(),
        sourceHeight: detectImage.height.toDouble(),
      );
    }

    // Scale detect-resolution boxes up to the full bitmap.
    if (scaleX != 1.0 || scaleY != 1.0) {
      mapped = [
        for (final g in mapped)
          _ProcessedGuess(
            xMin: g.xMin * scaleX,
            xMax: g.xMax * scaleX,
            yMin: g.yMin * scaleY,
            yMax: g.yMax * scaleY,
            score: g.score,
            label: g.label,
            probability: g.probability,
            confidence: g.confidence,
          ),
      ];
    }

    final nms = _runNms(mapped, overlapThreshold);
    final thronePre =
        mapped.where((g) => _isThroneLabelIndex(g.label)).length;
    final thronePost =
        nms.where((g) => _isThroneLabelIndex(g.label)).length;
    if (thronePre > 0 || thronePost > 0) {
      log('throne boxes: preNms=$thronePre postNms=$thronePost');
    }
    lastDiag = DetectionDiag(
      rotations: rotations,
      leaves: _lastLeavesSeen,
      maxScore: _lastMaxScore,
      aboveThreshold: mapped.length,
      afterNms: nms.length,
      scoreThreshold: scoreThreshold,
      expectedAttrs: 5 + _labels.length,
      labelCount: _labels.length,
    );
    log(lastDiag!.statusLine);
    return nms.map((g) => g.toJsonString()).toList();
  }

  /// Camera YUV420 planes → RGB image → same detection path.
  Future<List<String>> detectOnCameraPlanes({
    required List<Uint8List> bytesList,
    required int imageWidth,
    required int imageHeight,
    required int inputImageSize,
    double scoreThreshold = 0.3,
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

  /// Downscale huge photos before pad-to-square. Keeps longest side at most
  /// 2× model input (e.g. 3328 for 1664) so preprocessing stays cheap while
  /// still giving the network more than one native pixel per input cell.
  img.Image _shrinkForDetect(img.Image image, int inputImageSize) {
    final maxSide = math.max(image.width, image.height);
    final limit = inputImageSize * 2;
    if (maxSide <= limit) return image;
    final scale = limit / maxSide;
    return img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      height: math.max(1, (image.height * scale).round()),
      interpolation: img.Interpolation.linear,
    );
  }

  /// Boxes from a preprocess with [rotations]×90° CW live in the rotated
  /// bitmap's axes (swapDims for odd turns). Map them back to [sourceWidth]×
  /// [sourceHeight] (the unrotated detect image / photo).
  List<_ProcessedGuess> _unrotateGuessesToSource(
    List<_ProcessedGuess> guesses, {
    required int rotations,
    required double sourceWidth,
    required double sourceHeight,
  }) {
    final turns = rotations % 4;
    if (turns == 0 || guesses.isEmpty) return guesses;

    var w = turns.isOdd ? sourceHeight : sourceWidth;
    var h = turns.isOdd ? sourceWidth : sourceHeight;
    var current = guesses;

    for (var step = 0; step < turns; step++) {
      current = [
        for (final g in current) _undoOneCw90Box(g, curW: w, curH: h),
      ];
      final nextW = h;
      final nextH = w;
      w = nextW;
      h = nextH;
    }
    return current;
  }

  /// Inverse of one 90° clockwise image rotation for an axis-aligned box.
  /// Current space is [curW]×[curH]; result space is [curH]×[curW].
  _ProcessedGuess _undoOneCw90Box(
    _ProcessedGuess g, {
    required double curW,
    required double curH,
  }) {
    // Forward CW: (ox, oy) in A×B → (B - oy, ox) in B×A.
    // Inverse:     (x, y)  in B×A → (y, B - x) in A×B.
    final corners = <(double, double)>[
      (g.xMin, g.yMin),
      (g.xMax, g.yMin),
      (g.xMin, g.yMax),
      (g.xMax, g.yMax),
    ];
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final (x, y) in corners) {
      final ox = y;
      final oy = curW - x;
      minX = math.min(minX, ox);
      maxX = math.max(maxX, ox);
      minY = math.min(minY, oy);
      maxY = math.max(maxY, oy);
    }
    return _ProcessedGuess(
      xMin: minX,
      xMax: maxX,
      yMin: minY,
      yMax: maxY,
      label: g.label,
      probability: g.probability,
      confidence: g.confidence,
      score: g.score,
    );
  }

  Float32List _preprocess({
    required img.Image image,
    required int inputImageSize,
    required double mean,
    required double std,
    required int rotations,
    required int padSize,
    required int ox,
    required int oy,
  }) {
    // Pad to square, resize, rotate 90° clockwise `rotations` times, normalize.
    // Box mapping undoes this via [LetterboxGeom] / [undoLetterboxBox] (modern).
    var work = img.Image(width: padSize, height: padSize);
    img.fill(work, color: img.ColorRgb8(0, 0, 0));
    img.compositeImage(work, image, dstX: ox, dstY: oy);
    work = img.copyResize(
      work,
      width: inputImageSize,
      height: inputImageSize,
      interpolation: img.Interpolation.linear,
    );
    for (var i = 0; i < rotations; i++) {
      work = img.copyRotate(work, angle: 90);
    }
    // Orthogonal rotate of a non-square pad is fine; keep model input exact.
    if (work.width != inputImageSize || work.height != inputImageSize) {
      work = img.copyResize(
        work,
        width: inputImageSize,
        height: inputImageSize,
        interpolation: img.Interpolation.linear,
      );
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
    required double originalImageWidth,
    required double originalImageHeight,
    required bool logExtra,
    required int rotations,
    required bool strictEdges,
  }) {
    final unraveled = <_ProcessedGuess>[];
    var leavesSeen = 0;
    var maxScore = 0.0;
    final expectedAttrs = 5 + _labels.length;

    void considerLeaf(List<double> leaf) {
      leavesSeen++;
      if (leaf.length < 6) return;
      final block = _BlockGuess(leaf);
      if (block.highestScore > maxScore) {
        maxScore = block.highestScore;
      }
      // Throne rooms are large and often under-confident vs tokens sitting on
      // them — keep a softer gate so they reach NMS.
      final isThrone = _isThroneLabelIndex(block.highestIndex);
      final gate = isThrone ? scoreThreshold * 0.55 : scoreThreshold;
      if (block.highestScore <= gate) return;

      var xMin = block.xPos - 0.5 * block.width;
      var xMax = block.xPos + 0.5 * block.width;
      var yMin = block.yPos - 0.5 * block.height;
      var yMax = block.yPos + 0.5 * block.height;

      xMin = xMin * originalImageWidth / inputImageSize;
      xMax = xMax * originalImageWidth / inputImageSize;
      yMin = yMin * originalImageHeight / inputImageSize;
      yMax = yMax * originalImageHeight / inputImageSize;

      final bool valid;
      if (strictEdges) {
        // Legacy: drop any box that touches/crosses the border.
        valid = xMin < xMax &&
            yMin < yMax &&
            xMin > 0 &&
            yMin > 0 &&
            xMax < originalImageWidth &&
            yMax < originalImageHeight;
      } else {
        // Modern: clamp overhang so near-edge tiles (incl. throne) survive.
        xMin = xMin.clamp(0.0, originalImageWidth);
        xMax = xMax.clamp(0.0, originalImageWidth);
        yMin = yMin.clamp(0.0, originalImageHeight);
        yMax = yMax.clamp(0.0, originalImageHeight);
        valid = xMin < xMax && yMin < yMax;
      }

      if (!valid && !logExtra) return;

      final probability = block.probs[block.highestIndex];
      final guess = _ProcessedGuess(
        xMin: xMin,
        xMax: xMax,
        yMin: yMin,
        yMax: yMax,
        label: block.highestIndex,
        confidence: block.confidence,
        probability: probability,
        score: block.confidence * probability,
      );

      if (logExtra) {
        final labelName = block.highestIndex < _labels.length
            ? _labels[block.highestIndex]
            : '${block.highestIndex}';
        log('GUESS: $valid, $labelName, $guess');
      }

      if (valid) {
        unraveled.add(guess);
      }
    }

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
      final value = entry.value;
      // Common TF YOLO export: [1, attrs, boxes] instead of [1, boxes, attrs].
      if (value is List &&
          value.isNotEmpty &&
          value.first is List &&
          (value.first as List).isNotEmpty &&
          (value.first as List).first is List) {
        final batch = value.first as List;
        if (batch.length == expectedAttrs &&
            batch.first is List &&
            (batch.first as List).isNotEmpty &&
            (batch.first as List).first is num) {
          final numBoxes = (batch.first as List).length;
          log('transposed output detected: attrs=${batch.length} boxes=$numBoxes');
          for (var b = 0; b < numBoxes; b++) {
            final leaf = <double>[
              for (var a = 0; a < batch.length; a++)
                ((batch[a] as List)[b] as num).toDouble(),
            ];
            considerLeaf(leaf);
          }
          continue;
        }
      }
      walk(value, considerLeaf);
    }

    _lastLeavesSeen = leavesSeen;
    _lastMaxScore = maxScore;
    return unraveled;
  }

  List<_ProcessedGuess> _runNms(
    List<_ProcessedGuess> guesses,
    double overlapThreshold, {
    double crossClassIou = 0.7,
  }) {
    final copy = List<_ProcessedGuess>.from(guesses)
      ..sort((a, b) => b.score.compareTo(a.score));
    final best = <_ProcessedGuess>[];

    while (copy.isNotEmpty) {
      final top = copy.removeAt(0);
      best.add(top);
      // Class-aware + throne/token guards: attendants may sit on the throne
      // *or* beside it; bonus cards sit beside the castle. Never drop those
      // classes to cross-class overlap with a room or throne box.
      copy.removeWhere((g) {
        final iou = top.calculateOverlap(g);
        if (g.label == top.label) return iou > overlapThreshold;
        if (_isThroneLabelIndex(g.label) || _isTokenLabelIndex(g.label)) {
          return false;
        }
        // Contained smaller box winning first must not kill a much larger parent.
        final gArea = g.area();
        final topArea = top.area();
        if (gArea > topArea * 1.8) {
          final inter = _intersectionArea(top, g);
          if (topArea > 0 && inter / topArea > 0.7) return false;
        }
        return iou > crossClassIou;
      });
    }
    return best;
  }

  bool _isThroneLabelIndex(int index) {
    if (index < 0 || index >= _labels.length) return false;
    final name = _labels[index];
    return name == 'TRLS' ||
        name == 'TRLC' ||
        name == 'TRUS' ||
        name == 'TRCD' ||
        name == 'TRFS' ||
        name == 'TRUF' ||
        name == 'TRCF' ||
        name == 'TRAO';
  }

  bool _isTokenLabelIndex(int index) {
    if (index < 0 || index >= _labels.length) return false;
    final name = _labels[index];
    return name.startsWith('RA') || name.startsWith('BC');
  }

  double _intersectionArea(_ProcessedGuess a, _ProcessedGuess b) {
    final xMinInter = math.max(a.xMin, b.xMin);
    final xMaxInter = math.min(a.xMax, b.xMax);
    final yMinInter = math.max(a.yMin, b.yMin);
    final yMaxInter = math.min(a.yMax, b.yMax);
    return math.max(0.0, (xMaxInter - xMinInter) * (yMaxInter - yMinInter));
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
