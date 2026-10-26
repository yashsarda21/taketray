/// A VN folder name that is not in [taken]: [base], else `base (2)`,
/// `base (3)`, … (spec §3).
///
/// Names are compared without regard to case, because Android's shared
/// storage treats `Goa` and `goa` as the same folder.
String uniqueFolderName(String base, Set<String> taken) {
  final takenLower = {for (final name in taken) name.toLowerCase()};
  var candidate = base;
  for (var number = 2; takenLower.contains(candidate.toLowerCase()); number++) {
    candidate = '$base ($number)';
  }
  return candidate;
}
