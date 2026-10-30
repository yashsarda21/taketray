/// The city of an IANA zone id, as the clip viewer names it ("London time",
/// spec §8.3a, D-83): the last `/` segment, with `_` as a space.
///
/// "America/New_York" gives "New York", "Europe/Isle_of_Man" "Isle of Man".
/// Null for an id with no `/` ("UTC", "GMT"), an `Etc/…` id ("Etc/GMT+5"
/// names no place) and an empty last segment.
///
/// The city tells where someone was: never log it (D-10).
String? zoneCity(String zoneId) {
  final slash = zoneId.lastIndexOf('/');
  if (slash < 0 || zoneId.startsWith('Etc/')) return null;
  final city = zoneId.substring(slash + 1).replaceAll('_', ' ');
  return city.isEmpty ? null : city;
}
