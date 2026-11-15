enum ByteUnit { mb, gb }

/// A size ready to show: [number] is `"900"` or `"1.2"`; the view adds the
/// translated unit.
class ByteSize {
  const ByteSize(this.unit, this.number);

  final ByteUnit unit;
  final String number;
}

/// [bytes] as decimal MB or GB, like the prototype's `fmt.size` (D-119).
///
/// Whole MB below 1 GB, GB with one decimal (a `.0` is dropped) from 1 GB.
/// Rounds half up, and rounds before picking the unit, so 999,500,000 is
/// `1 GB`, never `1000 MB`, and 9,950,000,000 is `10 GB`, never `9.10`.
/// Unlike `fmt.size`, any size above 0 shows at least `1 MB`, so a copy
/// never reads "0 MB" when something is there. Integer arithmetic only.
ByteSize byteSize(int bytes) {
  if (bytes <= 0) return const ByteSize(ByteUnit.mb, '0');
  final megabytes = (bytes + 500000) ~/ 1000000;
  if (megabytes < 1000) {
    return ByteSize(ByteUnit.mb, (megabytes < 1 ? 1 : megabytes).toString());
  }
  final tenths = (bytes + 50000000) ~/ 100000000;
  final whole = tenths ~/ 10;
  final decimal = tenths % 10;
  return ByteSize(ByteUnit.gb, decimal == 0 ? '$whole' : '$whole.$decimal');
}
