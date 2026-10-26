import 'package:characters/characters.dart';

/// The longest reel name, in characters.
const reelNameMaxLength = 40;

/// The longest reference label, in characters.
const referenceLabelMaxLength = 60;

/// Why a reel name is not acceptable.
enum ReelNameProblem { empty, tooLong }

/// Why a reference label is not acceptable.
enum ReferenceLabelProblem { tooLong }

/// Thrown by repositories when the user's input breaks a rule. [problem] is
/// one of the problem enums ([ReelNameProblem], [ReferenceLabelProblem],
/// `ReferenceUrlProblem`) so the screen can show the matching message.
class InvalidInputException implements Exception {
  const InvalidInputException(this.problem);

  final Enum problem;

  @override
  String toString() => 'InvalidInputException($problem)';
}

/// Removes the spaces around a name; the inside is left alone.
String normalizeName(String raw) => raw.trim();

/// Checks a reel name the way it will be saved: trimmed, then 1 to
/// [reelNameMaxLength] characters.
///
/// Characters are what the user sees (`String.characters`), not UTF-16 units:
/// an emoji, a flag or a letter with a combining accent counts once, so 40
/// emoji pass and 41 do not.
ReelNameProblem? checkReelName(String raw) {
  final length = normalizeName(raw).characters.length;
  if (length == 0) return ReelNameProblem.empty;
  if (length > reelNameMaxLength) return ReelNameProblem.tooLong;
  return null;
}

/// Checks a reference label: null or empty means "no label" and is fine,
/// otherwise at most [referenceLabelMaxLength] characters after trimming.
ReferenceLabelProblem? checkReferenceLabel(String? raw) {
  if (raw == null) return null;
  if (normalizeName(raw).characters.length > referenceLabelMaxLength) {
    return ReferenceLabelProblem.tooLong;
  }
  return null;
}
