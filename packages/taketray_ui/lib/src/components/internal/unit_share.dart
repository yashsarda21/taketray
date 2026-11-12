/// [fraction] as a share from 0 to 1 that is always safe to multiply a width
/// by: more than 1 (or infinity) is 1; less than 0 (or minus infinity) and
/// "not a number" are 0.
///
/// A caller that divides sizes can produce any of these (a division by zero,
/// a negative difference), and a layout given NaN fails in a release build.
double unitShare(double fraction) {
  if (fraction.isNaN) return 0;
  return fraction.clamp(0, 1).toDouble();
}
