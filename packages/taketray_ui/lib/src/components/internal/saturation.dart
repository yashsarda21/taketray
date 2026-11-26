/// The 4 x 5 colour matrix (row-major, for `ColorFilter.matrix`) of the CSS
/// `saturate([amount])` filter, as the W3C Filter Effects module defines it
/// (D-175).
///
/// 1 leaves colours as they are, 0 turns them to grey (by the luma weights
/// 0.2126, 0.7152, 0.0722) and above 1 pushes them away from the grey. Alpha
/// and the offsets are untouched. Every row of colour weights sums to 1, so
/// white and the greys stay as they are.
List<double> ttSaturationMatrix(double amount) {
  final s = amount;
  return [
    0.2126 + 0.7874 * s, 0.7152 - 0.7152 * s, 0.0722 - 0.0722 * s, 0, 0, //
    0.2126 - 0.2126 * s, 0.7152 + 0.2848 * s, 0.0722 - 0.0722 * s, 0, 0,
    0.2126 - 0.2126 * s, 0.7152 - 0.7152 * s, 0.0722 + 0.9278 * s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}
