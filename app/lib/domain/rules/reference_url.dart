import 'package:taketray/domain/models/enums.dart';

/// Why a reference link is not acceptable: [normalizeReferenceUrl] returned
/// null.
enum ReferenceUrlProblem { invalid }

final _trailingSlashes = RegExp(r'/+$');

/// Hosts whose query string is only tracking (`?igsh=`, `?utm_source=`). Not
/// every `*.instagram.com` host: `l.instagram.com/?u=<target>` keeps its
/// whole meaning in the query.
const _instagramHosts = {'instagram.com', 'www.instagram.com', 'instagr.am'};

/// Cleans a link the user pasted or shared, so the same page saved twice is
/// recognised as one reference. Returns null when it is not an http(s) link
/// with a host.
///
/// - Trims (a space inside the link makes it invalid), lowercases the scheme
///   and host, and drops a `#fragment`.
/// - Instagram: drops the query and ends the path with exactly one `/`, so
///   `.../reel/ABC/?igsh=x`, `.../reel/ABC?igsh=y` and `.../reel/ABC//` are
///   all `https://www.instagram.com/reel/ABC/`.
/// - Every other host keeps its query (`youtube.com/watch?v=` needs it).
Uri? normalizeReferenceUrl(String raw) {
  final trimmed = raw.trim();
  // A link has no spaces. Uri.parse would quietly encode them, turning a
  // pasted sentence into a "valid" host.
  if (trimmed.contains(RegExp(r'\s'))) return null;

  final Uri parsed;
  try {
    parsed = Uri.parse(trimmed);
  } on FormatException {
    return null;
  }
  if (parsed.scheme != 'http' && parsed.scheme != 'https') return null;
  if (parsed.host.isEmpty) return null;

  final withoutFragment = parsed.removeFragment();
  if (!_instagramHosts.contains(parsed.host)) return withoutFragment;

  return Uri(
    scheme: parsed.scheme,
    userInfo: parsed.userInfo,
    host: parsed.host,
    port: parsed.hasPort ? parsed.port : null,
    path: '${parsed.path.replaceFirst(_trailingSlashes, '')}/',
  );
}

/// Which site a link points to. [url] should come from
/// [normalizeReferenceUrl].
ReferenceSource referenceSourceOf(Uri url) {
  final host = url.host.toLowerCase();
  bool onDomain(String domain) => host == domain || host.endsWith('.$domain');

  if (onDomain('instagram.com') || onDomain('instagr.am')) {
    return ReferenceSource.instagram;
  }
  if (onDomain('youtube.com') || onDomain('youtu.be')) {
    return ReferenceSource.youtube;
  }
  if (onDomain('tiktok.com')) return ReferenceSource.tiktok;
  return ReferenceSource.link;
}
