import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:btcc/src/models/enums/identify_labels.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/tflite/content_band.dart';
import 'package:btcc/src/tflite/image_pipeline_mode.dart';
import 'package:btcc/src/tflite/rotation_order.dart';
import 'package:btcc/src/tflite/tflite_detector.dart';
import 'package:btcc/src/tflite/tflite_helper.dart';
import 'package:btcc/src/tflite/tflite_model.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';
import 'package:btcc/src/utils/image_helper.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class TfStore extends ChangeNotifier {
  static bool perFrameRunning = false;
  static const TfliteModel defaultModel = TfliteModel.scoring;
  static const TfliteModel identifyModel = TfliteModel.identify;

  final TfliteDetector _detector = TfliteDetector();

  bool _useIdentifyModel = false;
  bool get useIdentifyModel => _useIdentifyModel;
  set useIdentifyModel(bool other) {
    _useIdentifyModel = other;
    notifyListeners();
  }

  String _modelPath = defaultModel.file;
  String get modelPath => _modelPath;
  set modelPath(String other) {
    _modelPath = other;
    _shouldRefreshModel = true;
    notifyListeners();
  }

  String _labelsPath = defaultModel.labels;
  String get labelsPath => _labelsPath;
  set labelsPath(String other) {
    _labelsPath = other;
    _shouldRefreshModel = true;
    notifyListeners();
  }

  int _inputImageSize = defaultModel.inputImageSize;
  int get inputImageSize => _inputImageSize;
  set inputImageSize(int other) {
    _inputImageSize = other;
    notifyListeners();
  }

  double _scoreThreshold = .3;
  double get scoreThreshold => _scoreThreshold;
  set scoreThreshold(double other) {
    _scoreThreshold = other;
    notifyListeners();
  }

  double _overlapThreshold = .45;
  double get overlapThreshold => _overlapThreshold;
  set overlapThreshold(double other) {
    _overlapThreshold = other;
    notifyListeners();
  }

  double _mean = 0;
  double get mean => _mean;
  set mean(double other) {
    _mean = other;
    notifyListeners();
  }

  double _std = 255;
  double get std => _std;
  set std(double other) {
    _std = other;
    notifyListeners();
  }

  int _rotations = 3;
  int get rotations => _rotations;
  set rotations(int other) {
    _rotations = other;
    notifyListeners();
  }

  ImagePipelineMode _pipelineMode = ImagePipelineMode.modern;
  ImagePipelineMode get pipelineMode => _pipelineMode;
  set pipelineMode(ImagePipelineMode other) {
    _pipelineMode = other;
    _detector.pipelineMode = other;
    notifyListeners();
  }

  bool _running = false;
  bool get running => _running;

  bool _shouldRefreshModel = false;

  /// Last detection pass diagnostics (for Debug ML status line).
  DetectionDiag? get lastDetectionDiag => _detector.lastDetectionDiag;
  final List<DetectionDiag> _runDiags = [];
  List<DetectionDiag> get lastRunDiags => List.unmodifiable(_runDiags);
  String get lastUnravelStatus {
    if (_runDiags.isEmpty) {
      return _detector.lastDetectionDiag?.statusLine ??
          'unravel: (no run yet)';
    }
    return _runDiags.map((d) => d.statusLine).join('\n');
  }

  TfStore() {
    init(defaultModel, true);
  }

  Future<bool> init(
    TfliteModel model,
    bool isAsset, {
    bool useGpuDelegate = false,
  }) async {
    try {
      await _detector.loadModel(
        modelPath: model.file,
        labelsPath: model.labels,
        isAsset: isAsset,
        numThreads: 8,
      );
      log('tflite loaded');

      _modelPath = model.file;
      _labelsPath = model.labels;
      _inputImageSize = model.inputImageSize;
      _shouldRefreshModel = false;
      notifyListeners();
      return true;
    } catch (ex) {
      log('Exception: ${ex.toString()}');
    }

    return false;
  }

  /// Force-reload the default scoring model (use after a bad tensor resize).
  Future<void> reloadScoringModel() async {
    _shouldRefreshModel = false;
    await init(defaultModel, true);
  }

  /// Images have an exif values stored on the image that we get with
  /// getImageRotation. Then we use this to decide how many 90 degree clockwise rotations
  /// are needed to pass the image to the tf model so that it looks correct
  Future<int> _getRotationsFromImageOrientation(String imagePath) async {
    final rotation = await ImageHelper.getImageRotation(
      imagePath,
      strict: _pipelineMode == ImagePipelineMode.legacy,
    );
    log('Detected Image rotation: $rotation (strict legacy=${_pipelineMode == ImagePipelineMode.legacy})');
    switch (rotation) {
      case ImageRotation.NinetyClockwise:
        return 3;
      case ImageRotation.Normal:
        return 0;
      case ImageRotation.NinetyCounterClockwise:
        return 1;
      case ImageRotation.OneEighty:
        return 2;
    }
  }

  Future<void> prepareForIdentify() async {
    await init(identifyModel, true, useGpuDelegate: false);
  }

  /// Load scoring model only if it is not already active (avoids re-attaching
  /// Flex and re-reading the .tflite on every photo).
  Future<void> prepareForScoring() async {
    if (_detector.isLoaded &&
        _modelPath == defaultModel.file &&
        !_shouldRefreshModel) {
      return;
    }
    await init(defaultModel, true);
  }

  /// Classify a single image crop (tile-selection flow).
  Future<List<TfliteProcessedGuess>> runOnImageCrop(
    img.Image source, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    final cx = x.clamp(0, source.width - 1);
    final cy = y.clamp(0, source.height - 1);
    final cw = width.clamp(1, source.width - cx);
    final ch = height.clamp(1, source.height - cy);
    final crop = img.copyCrop(source, x: cx, y: cy, width: cw, height: ch);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    // Single-tile crops are small; use a softer threshold than full-frame scan.
    final cropThreshold = math.min(_scoreThreshold, 0.18);
    final raw = await _detectRaw(crop, 0, scoreThreshold: cropThreshold);
    return _parseGuesses(raw);
  }

  List<TfliteProcessedGuess> _parseGuesses(List<String> res) {
    final guesses = <TfliteProcessedGuess>[];
    for (final x in res) {
      // fromMap → getLabelFromGuessLabel used to log every box (dozens/pass).
      guesses.add(TfliteProcessedGuess.fromMap(jsonDecode(x)));
    }
    log('parsed ${guesses.length} guesses');
    return guesses;
  }

  bool _hasThroneRoom(List<TfliteProcessedGuess> guesses) {
    return guesses.any(TfliteHelper.isThroneRoom);
  }

  bool _needsMoreRoomTiles(
    List<TfliteProcessedGuess> guesses,
    int? expectedRoomTileCount,
  ) {
    return TfliteHelper.isUnderExpectedRoomCount(
      TfliteHelper.countRoomDetections(guesses),
      expectedRoomTileCount,
    );
  }

  double _guessesQuality(List<TfliteProcessedGuess> guesses) {
    return guesses.fold<double>(0, (sum, g) => sum + g.score) + guesses.length;
  }

  /// Adaptive zoom+pan refine: portrait → L/R, landscape → T/B.
  Future<List<TfliteProcessedGuess>> _refineWithZoomPan({
    required img.Image full,
    required List<TfliteProcessedGuess> seed,
    required int rotations,
  }) async {
    // Include attendants in the anchor box — they mark throne height/center
    // when room detections alone miss the extremes.
    final anchors = seed.where((g) {
      if (!TfliteHelper.isNonTile(g)) return true;
      final tile = TfliteHelper.getCorrectTile(g, const <Tile>[]);
      return tile.tileType == TileType.RoyalAttendant;
    }).toList();
    if (anchors.isEmpty) return seed;

    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    var sumW = 0.0;
    var sumH = 0.0;
    for (final g in anchors) {
      minX = math.min(minX, g.xMin);
      maxX = math.max(maxX, g.xMax);
      minY = math.min(minY, g.yMin);
      maxY = math.max(maxY, g.yMax);
      sumW += g.xMax - g.xMin;
      sumH += g.yMax - g.yMin;
    }

    final avgTileW = sumW / anchors.length;
    final avgTileH = sumH / anchors.length;

    // Always plan up to 4 wing pans — stopping at 2 when the center stack
    // already has ~10 tiles was skipping the far wing on tall castles.
    const maxCrops = 4;

    final plan = planZoomPanCrops(
      imageW: full.width,
      imageH: full.height,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      avgTileW: avgTileW,
      avgTileH: avgTileH,
      maxCrops: maxCrops,
    );
    if (plan.crops.isEmpty) {
      log('zoom+pan refine skipped (${plan.reason})');
      return seed;
    }

    log('zoom+pan refine ${plan.reason}: ${plan.crops}');
    var merged = seed;
    for (final band in plan.crops) {
      final crop = img.copyCrop(
        full,
        x: band.x,
        y: band.y,
        width: band.width,
        height: band.height,
      );
      List<String> raw = const [];
      try {
        raw = await _detectRaw(crop, rotations);
      } catch (ex) {
        log('zoom+pan ${band.tag} failed: $ex');
        continue;
      }
      final diag = _detector.lastDetectionDiag;
      if (diag != null) _runDiags.add(diag);

      final shifted = [
        for (final g in _parseGuesses(raw))
          TfliteProcessedGuess(
            xMin: g.xMin + band.x,
            xMax: g.xMax + band.x,
            yMin: g.yMin + band.y,
            yMax: g.yMax + band.y,
            label: g.label,
            probability: g.probability,
            confidence: g.confidence,
            score: g.score,
          ),
      ];
      log('zoom+pan ${band.tag}: ${shifted.length} detections');
      if (shifted.isEmpty) continue;

      final beforeCount = merged.length;
      merged = TfliteHelper.classAwareNms(
        [...merged, ...shifted],
        sameClassIou: _overlapThreshold,
      );
      if (merged.length <= beforeCount) {
        log('zoom+pan ${band.tag}: no new tiles after NMS — continuing');
      }
    }

    log('zoom+pan refine: seed=${seed.length} → ${merged.length} after NMS');
    return merged;
  }

  bool _shouldRefineZoomPan(
    List<TfliteProcessedGuess> guesses, {
    int? imageW,
    int? imageH,
    int? expectedRoomTileCount,
  }) {
    if (guesses.isEmpty) return false;

    if (_needsMoreRoomTiles(guesses, expectedRoomTileCount)) {
      log('zoom+pan refine: under expected room count '
          '(${TfliteHelper.countRoomDetections(guesses)}/$expectedRoomTileCount)');
      return true;
    }

    final hasThrone = _hasThroneRoom(guesses);
    if (hasThrone &&
        guesses.length >= 10 &&
        imageW != null &&
        imageH != null &&
        !_likelyMissingWings(guesses, imageW: imageW, imageH: imageH)) {
      log('zoom+pan refine skipped: throne + ${guesses.length} tiles, '
          'detections span frame');
      return false;
    }

    if (hasThrone) return true;
    var rooms = 0;
    var attendants = 0;
    for (final g in guesses) {
      if (TfliteHelper.isNonTile(g)) {
        final tile = TfliteHelper.getCorrectTile(g, const <Tile>[]);
        if (tile.tileType == TileType.RoyalAttendant) attendants++;
      } else {
        rooms++;
      }
    }
    // Inferred-throne cases often have RAs but no TR* yet — still zoom.
    return attendants > 0 || rooms >= 3;
  }

  /// True when pass-1 boxes hug the center — side wings/basement likely clipped.
  bool _likelyMissingWings(
    List<TfliteProcessedGuess> guesses, {
    required int imageW,
    required int imageH,
  }) {
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final g in guesses) {
      minX = math.min(minX, g.xMin);
      maxX = math.max(maxX, g.xMax);
      minY = math.min(minY, g.yMin);
      maxY = math.max(maxY, g.yMax);
    }
    final spanW = maxX - minX;
    final spanH = maxY - minY;
    final edgeMarginW = imageW * 0.14;
    final edgeMarginH = imageH * 0.10;
    final missingLeft = minX > edgeMarginW;
    final missingRight = maxX < imageW - edgeMarginW;
    final missingTop = minY > edgeMarginH;
    final missingBottom = maxY < imageH - edgeMarginH;
    final narrowW = spanW < imageW * 0.52;
    final narrowH = spanH < imageH * 0.55;
    return (missingLeft || missingRight) && narrowW ||
        (missingTop || missingBottom) && narrowH;
  }

  /// First upright pass already has a usable castle → don't burn 2–3 more
  /// full-frame Flex runs (each can take minutes under camera binder load).
  bool _goodEnoughToSkipMoreRotations(
    List<TfliteProcessedGuess> guesses, {
    int? expectedRoomTileCount,
  }) {
    if (_needsMoreRoomTiles(guesses, expectedRoomTileCount)) return false;
    if (guesses.length < 8) return false;
    return _shouldRefineZoomPan(guesses, expectedRoomTileCount: expectedRoomTileCount);
  }

  Future<List<String>> _detectRaw(
    img.Image image,
    int rotations, {
    double? scoreThreshold,
  }) async {
    // Prefer the known asset model size; fall back to store value.
    var size = _inputImageSize;
    try {
      size = TfliteModel.modelFromPath(_modelPath).inputImageSize;
    } catch (_) {
      // Custom / file-picked model — keep whatever the UI set.
    }
    if (_inputImageSize != size) {
      log('Overriding inputImageSize $_inputImageSize → $size for $_modelPath');
      _inputImageSize = size;
    }
    // Yield so CameraX/UI binders can drain between Flex passes.
    await Future<void>.delayed(const Duration(milliseconds: 32));
    log('Flex detect begin rotations=$rotations '
        '${image.width}x${image.height}');
    final sw = Stopwatch()..start();
    final raw = await _detector.detectOnImage(
      image: image,
      inputImageSize: size,
      scoreThreshold: scoreThreshold ?? _scoreThreshold,
      overlapThreshold: _overlapThreshold,
      mean: _mean,
      std: _std,
      rotations: rotations,
      logExtra: false,
    );
    log('Flex detect end rotations=$rotations '
        'in ${sw.elapsedMilliseconds}ms (${raw.length} raw)');
    return raw;
  }

  /// Runs detection. Legacy: single EXIF-derived rotation (original path).
  /// Modern: try preferred, then other 90° turns, **stop at first throne**.
  /// When [expectedRoomTileCount] is set, keeps trying rotations / refine /
  /// a softer threshold pass until the room count is met or options run out.
  Future<List<TfliteProcessedGuess>> runOnImage(
    String imagePath, {
    int? expectedRoomTileCount,
  }) async {
    if (_running) {
      log('runOnImage ignored: already running');
      return const [];
    }
    logNow(tag: 'StartModel');
    _running = true;
    notifyListeners();

    if (_shouldRefreshModel) {
      final model = TfliteModel(
        file: modelPath,
        labels: labelsPath,
        inputImageSize: inputImageSize,
      );
      final success = await init(model, false);
      if (success) {
        log('successfully refreshed model');
      } else {
        log('failed to refresh model');
      }
    }

    log('Model: $_modelPath');
    log('Labels: $_labelsPath');
    log('pipeline=${_pipelineMode.label}');
    if (expectedRoomTileCount != null) {
      log('expected room tiles=$expectedRoomTileCount');
    }
    _detector.pipelineMode = _pipelineMode;
    if (!_detector.isLoaded) {
      await prepareForScoring();
    }
    var guesses = <TfliteProcessedGuess>[];
    _runDiags.clear();
    try {
      // Decode once — re-decoding a 12MP JPEG per rotation was a major cost.
      final decoded = await _detector.decodeImageFile(imagePath);
      final preferred = await _getRotationsFromImageOrientation(imagePath);
      // Modern: try all 4 unique turns if needed, preferred/complement/upright
      // first. (Earlier cap of preferred+2 alts skipped the landscape turn that
      // finds the throne — e.g. preferred=0 → never tried 3.)
      final List<int> order;
      if (_pipelineMode == ImagePipelineMode.legacy) {
        order = <int>[preferred];
      } else {
        order = modernRotationOrder(
          preferred: preferred,
          landscapeBitmap: decoded.width >= decoded.height,
        );
      }
      log('rotation try order=$order (bitmap ${decoded.width}x${decoded.height})');

      var preferredGuesses = <TfliteProcessedGuess>[];
      var best = <TfliteProcessedGuess>[];
      var bestHasThrone = false;
      var bestQuality = double.negativeInfinity;
      var throneRotations = preferred;

      for (final rotations in order) {
        List<String> raw = const [];
        try {
          raw = await _detectRaw(decoded, rotations);
        } catch (ex) {
          log('detect rotations=$rotations failed: $ex');
          await prepareForScoring();
          try {
            raw = await _detectRaw(decoded, rotations);
          } catch (ex2) {
            log('detect retry failed: $ex2');
            continue;
          }
        }
        final diag = _detector.lastDetectionDiag;
        if (diag != null) {
          _runDiags.add(diag);
        }
        final candidate = _parseGuesses(raw);
        final hasThrone = _hasThroneRoom(candidate);
        final quality = _guessesQuality(candidate);
        log('rotations=$rotations → raw=${raw.length}, '
            'parsed=${candidate.length}, throne=$hasThrone, quality=$quality');
        if (diag != null) {
          log(diag.statusLine);
        }

        if (candidate.isEmpty) continue;

        if (_pipelineMode == ImagePipelineMode.legacy) {
          best = candidate;
          break;
        }

        if (rotations == preferred) {
          preferredGuesses = candidate;
        }

        if (hasThrone) {
          throneRotations = rotations;
          // Merge EXIF/preferred pass when it differed (no extra inference).
          if (preferredGuesses.isNotEmpty &&
              !identical(preferredGuesses, candidate)) {
            best = TfliteHelper.classAwareNms(
              [...preferredGuesses, ...candidate],
              sameClassIou: _overlapThreshold,
            );
            log('merged preferred(${preferredGuesses.length}) + '
                'throne(${candidate.length}) → ${best.length}');
          } else {
            best = candidate;
          }
          bestHasThrone = true;

          final roomCount = TfliteHelper.countRoomDetections(best);
          if (!_needsMoreRoomTiles(best, expectedRoomTileCount)) {
            log('stopping: throne found at rotations=$rotations '
                '($roomCount room tiles)');
            break;
          }
          log('throne at rotations=$rotations but only $roomCount/'
              '$expectedRoomTileCount rooms — trying more rotations');
          continue;
        }
        if (!bestHasThrone && quality > bestQuality) {
          best = candidate;
          bestQuality = quality;
          throneRotations = rotations;
        }
        // Landscape/portrait often already have plenty of rooms on the first
        // upright pass — skip the other 3 Flex rotations and go to zoom+pan.
        if (_pipelineMode == ImagePipelineMode.modern &&
            _goodEnoughToSkipMoreRotations(
              candidate,
              expectedRoomTileCount: expectedRoomTileCount,
            )) {
          log('stopping: enough detections for zoom+pan '
              '(skip remaining rotations)');
          best = candidate;
          throneRotations = rotations;
          break;
        }
      }

      // Adaptive zoom+pan even when TR* was missing (attendants / rooms only).
      if (_pipelineMode == ImagePipelineMode.modern &&
          _shouldRefineZoomPan(
            best,
            imageW: decoded.width,
            imageH: decoded.height,
            expectedRoomTileCount: expectedRoomTileCount,
          )) {
        best = await _refineWithZoomPan(
          full: decoded,
          seed: best,
          rotations: throneRotations,
        );
      }

      if (_needsMoreRoomTiles(best, expectedRoomTileCount)) {
        final softer = (_scoreThreshold * 0.72).clamp(0.15, _scoreThreshold);
        log('expected room count not met — softer threshold pass ($softer)');
        List<String> raw = const [];
        try {
          raw = await _detectRaw(
            decoded,
            throneRotations,
            scoreThreshold: softer,
          );
        } catch (ex) {
          log('softer threshold pass failed: $ex');
        }
        if (raw.isNotEmpty) {
          final softerGuesses = _parseGuesses(raw);
          best = TfliteHelper.classAwareNms(
            [...best, ...softerGuesses],
            sameClassIou: _overlapThreshold,
          );
          log('after softer pass: ${TfliteHelper.countRoomDetections(best)} '
              'room tiles');
          if (_shouldRefineZoomPan(
            best,
            imageW: decoded.width,
            imageH: decoded.height,
            expectedRoomTileCount: expectedRoomTileCount,
          )) {
            best = await _refineWithZoomPan(
              full: decoded,
              seed: best,
              rotations: throneRotations,
            );
          }
        }
      }

      if (_needsMoreRoomTiles(best, expectedRoomTileCount)) {
        log('finished under expected room count: '
            '${TfliteHelper.countRoomDetections(best)}/$expectedRoomTileCount');
      }

      guesses = best;
    } catch (ex, st) {
      log(ex);
      log(st);
    }

    logNow(tag: 'EndModel');
    _running = false;
    notifyListeners();

    final file = File(imagePath);
    final decodedImage = await decodeImageFromList(file.readAsBytesSync());
    log('original image: ${decodedImage.width}x${decodedImage.height}');
    return guesses;
  }

  Future<List<TfliteProcessedGuess>> runOnFrame(CameraImage image) async {
    if (perFrameRunning) {
      return [];
    }

    perFrameRunning = true;

    List<String> res = [];

    try {
      res = await _detector.detectOnCameraPlanes(
        bytesList: image.planes.map((e) => e.bytes).toList(),
        inputImageSize: _inputImageSize,
        imageHeight: image.height,
        imageWidth: image.width,
        scoreThreshold: _scoreThreshold,
        overlapThreshold: _overlapThreshold,
        mean: _mean,
        std: _std,
        rotations: 3,
      );
    } catch (ex) {
      log(ex);
    }

    final guesses = <TfliteProcessedGuess<IdentifyLabels>>[];
    for (final x in res) {
      guesses.add(TfliteProcessedGuess.identifyGuessFromMap(jsonDecode(x)));
    }
    perFrameRunning = false;
    return guesses;
  }
}
