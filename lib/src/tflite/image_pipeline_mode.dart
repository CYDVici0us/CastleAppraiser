/// A/B toggle for camera preview + detection preprocessing.
///
/// [legacy] matches the original in-app camera (pre-August):
/// - camera preview: portrait `height = width * aspectRatio`, landscape
///   `width = height * aspectRatio` (no FittedBox cover-crop)
/// - box mapping: always swap W↔H (`width = image.height`)
/// - edge boxes: strict reject if touching border
/// - rotations: single EXIF-derived pass only
/// - EXIF: require Image Orientation tag (throws if missing/unsupported)
///
/// [modern] is today's path (orientation-aware preview, odd-only swap, soft
/// edges, multi-rotation throne search, soft EXIF defaults).
///
/// Dart/Flutter upgrade necessities stay on in both modes (notably feeding
/// TFLite via float32 byte buffers so the input tensor is not resized to 1-D).
enum ImagePipelineMode {
  legacy,
  modern,
}

extension ImagePipelineModeX on ImagePipelineMode {
  String get label => switch (this) {
        ImagePipelineMode.legacy => 'Legacy (pre-August)',
        ImagePipelineMode.modern => 'Modern (current)',
      };

  String get shortLabel => switch (this) {
        ImagePipelineMode.legacy => 'Legacy',
        ImagePipelineMode.modern => 'Modern',
      };
}
