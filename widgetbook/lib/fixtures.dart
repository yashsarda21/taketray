import 'package:flutter/widgets.dart';

/// Sample thumbnail [n] (1 to 12) from `assets/thumbs/`, for catalogue use
/// cases.
ImageProvider wbThumb(int n) {
  RangeError.checkValueInInterval(n, 1, 12, 'n');
  return AssetImage('assets/thumbs/c$n.jpg');
}
