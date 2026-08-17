import 'dart:convert';
import 'dart:io';

import 'package:btcc/src/utils/log.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';

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

  /// Reads EXIF orientation.
  ///
  /// [strict] matches pre-August behavior: missing/unsupported tags throw.
  /// When false (modern), defaults to [ImageRotation.Normal] so gallery photos
  /// without metadata do not crash.
  static Future<ImageRotation> getImageRotation(
    String imagePath, {
    bool strict = false,
  }) async {
    try {
      final image = File(imagePath);
      final bytes = await image.readAsBytes();
      final data = await readExifFromBytes(bytes);
      final tag = data['Image Orientation'];
      if (tag == null) {
        if (strict) {
          throw Exception('Missing Image Orientation EXIF tag');
        }
        return ImageRotation.Normal;
      }

      final val = tag.values.firstAsInt();
      switch (val) {
        case 1:
          return ImageRotation.Normal;
        case 6:
          return ImageRotation.NinetyClockwise;
        case 3:
          return ImageRotation.OneEighty;
        case 8:
          return ImageRotation.NinetyCounterClockwise;
        case 2:
          if (strict) {
            throw Exception('Unsupported image rotation type: $val');
          }
          return ImageRotation.Normal;
        case 5:
          if (strict) {
            throw Exception('Unsupported image rotation type: $val');
          }
          return ImageRotation.NinetyClockwise;
        case 4:
          if (strict) {
            throw Exception('Unsupported image rotation type: $val');
          }
          return ImageRotation.OneEighty;
        case 7:
          if (strict) {
            throw Exception('Unsupported image rotation type: $val');
          }
          return ImageRotation.NinetyCounterClockwise;
        default:
          if (strict) {
            throw Exception('Unsupported image rotation type: $val');
          }
          log('Unsupported EXIF orientation $val; defaulting to Normal');
          return ImageRotation.Normal;
      }
    } catch (ex) {
      if (strict) rethrow;
      log('getImageRotation failed: $ex; defaulting to Normal');
      return ImageRotation.Normal;
    }
  }
}

enum ImageRotation {
  Normal,
  NinetyClockwise,
  OneEighty,
  NinetyCounterClockwise,
}
