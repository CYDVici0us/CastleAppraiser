/// Try-order for Modern multi-rotation throne search.
///
/// Caps at [maxAttempts] (default 4 = all unique 90° turns). Order matters:
/// preferred EXIF first, then 180° complement, then upright-for-bitmap-shape,
/// then remaining. Stopping at first throne keeps typical cost at 1–2 passes.
List<int> modernRotationOrder({
  required int preferred,
  required bool landscapeBitmap,
  int maxAttempts = 4,
}) {
  if (maxAttempts < 1) return const [];
  preferred %= 4;
  final out = <int>[];
  void add(int r) {
    r %= 4;
    if (!out.contains(r)) out.add(r);
  }

  add(preferred);
  add(preferred + 2); // complementary flip
  if (landscapeBitmap) {
    // Landscape pixels are usually already upright for the model.
    add(0);
    add(1);
    add(3);
  } else {
    // Portrait phones often need 0 or 3 depending on bake/EXIF.
    add(0);
    add(3);
    add(1);
  }
  add(2);
  return out.take(maxAttempts).toList();
}
