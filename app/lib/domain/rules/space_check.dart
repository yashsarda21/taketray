/// Space TakeTray keeps free for the phone while it copies (D-119, R3):
/// 500 MB, decimal.
const int copyReserveBytes = 500 * 1000 * 1000;

/// The answer to "do these copies fit?".
class SpaceCheck {
  const SpaceCheck({
    required this.enough,
    required this.freeAfterBytes,
    required this.shortByBytes,
  });

  /// True when the copies fit and [copyReserveBytes] is still free.
  final bool enough;

  /// Free space after the copies: free minus need. Negative when the copies
  /// alone do not fit.
  final int freeAfterBytes;

  /// How much more space is needed, reserve included; 0 when [enough].
  final int shortByBytes;
}

/// Whether [needBytes] of copies fit in [freeBytes] and leave the reserve.
SpaceCheck spaceCheck({required int needBytes, required int freeBytes}) {
  final required = needBytes + copyReserveBytes;
  final enough = freeBytes >= required;
  return SpaceCheck(
    enough: enough,
    freeAfterBytes: freeBytes - needBytes,
    shortByBytes: enough ? 0 : required - freeBytes,
  );
}
