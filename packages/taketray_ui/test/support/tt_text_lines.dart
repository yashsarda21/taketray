import 'package:flutter/rendering.dart';

/// How many lines [paragraph] is laid out over, at the width it was given.
///
/// For a check that text wraps (more than one line) or stays on one line. The
/// `didExceedMaxLines` flag says nothing of a text with no line limit: it is
/// always false there, whatever the text does.
int ttLineCount(RenderParagraph paragraph) => (TextPainter(
  text: paragraph.text,
  textDirection: paragraph.textDirection,
  textScaler: paragraph.textScaler,
  maxLines: paragraph.maxLines,
)..layout(maxWidth: paragraph.size.width)).computeLineMetrics().length;
