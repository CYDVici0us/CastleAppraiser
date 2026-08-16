import 'dart:convert';
import 'dart:io';

import 'package:btcc/src/utils/log.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ImageHelper {

  static String getFullImagePath(String path) => '$path/Pictures';

  static Image imageFromBase64String(String base64) {
    return Image.memory(base64Decode(base64));
  }

  static Future<String> imageToBase64String(String path) async {
    File file = File(path);
    var bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  /// Reads EXIF orientation. Missing or unsupported tags default to [ImageRotation.Normal]
  /// so gallery photos without metadata do not crash the pipeline.
  static Future<ImageRotation> getImageRotation(String imagePath) async {
    try {
      final image = File(imagePath);
      final bytes = await image.readAsBytes();
      final data = await readExifFromBytes(bytes);
      final tag = data['Image Orientation'];
      if (tag == null) {
        return ImageRotation.Normal;
      }

      final val = tag.values.firstAsInt();
      switch (val) {
        case 1:
        case 2: // mirrored horizontal
          return ImageRotation.Normal;
        case 6:
        case 5: // mirrored + 90 CW
          return ImageRotation.NinetyClockwise;
        case 3:
        case 4: // mirrored vertical
          return ImageRotation.OneEighty;
        case 8:
        case 7: // mirrored + 90 CCW
          return ImageRotation.NinetyCounterClockwise;
        default:
          log('Unsupported EXIF orientation $val; defaulting to Normal');
          return ImageRotation.Normal;
      }
    } catch (ex) {
      log('getImageRotation failed: $ex; defaulting to Normal');
      return ImageRotation.Normal;
    }
  }

  /// Bakes EXIF orientation into pixel data and rewrites [imagePath] as JPEG
  /// with Orientation=1. Detection and [Image.file] then agree without relying
  /// on EXIF alone (important for gallery images).
  static Future<void> bakeOrientationInPlace(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not decode image at $imagePath');
    }

    final baked = img.bakeOrientation(decoded);
    await file.writeAsBytes(img.encodeJpg(baked, quality: 95));
  }
}

enum ImageRotation {
  Normal,
  NinetyClockwise,
  OneEighty,
  NinetyCounterClockwise,
}
