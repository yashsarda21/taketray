import 'package:taketray/domain/models/enums.dart';

/// Why a reference link is not acceptable: [normalizeReferenceUrl] returned
/// null.
enum ReferenceUrlProblem { invalid }

final _trailingSlashes = RegExp(r'/+$');

/// An Instagram post path: `/p/CODE`, `/reel/CODE`, `/reels/CODE` or
/// `/tv/CODE`, optionally behind a `/user` segment. Group 1 is the code.
final _instagramPostPath = RegExp(
  r'^/(?:[^/]+/)?(?:p|reel|reels|tv)/([A-Za-z0-9_-]+)/*$',
);

/// Hosts that all lead to the same Instagram pages and whose query string is
/// only tracking (`?igsh=`, `?utm_source=`). Not every `*.instagram.com` host:
/// `l.instagram.com/?u=<target>` keeps its whole meaning in the query.
const _instagramHosts = {
  'instagram.com',
  'www.instagram.com',
  'm.instagram.com',
  'instagr.am',
};

/// The one form every [_instagramHosts] link is rewritten to.
const _instagramCanonicalHost = 'www.instagram.com';

/// Cleans a link the user pasted or shared, so the same page saved twice is
/// recognised as one reference. Returns null when it is not an http(s) link
/// with a host.
///
/// - Trims (a space inside the link makes it invalid), lowercases the scheme
///   and host, and drops a `#fragment`.
/// - Instagram (`instagram.com`, `www.`, `m.`, `instagr.am`): rewritten to
///   `https://www.instagram.com`, query dropped, path ended with exactly one
///   `/`. A post path (`/p/`, `/reel/`, `/reels/` or `/tv/` + code, with an
///   optional `/user` before it) becomes `/p/<code>/`, so
///   `http://instagram.com/reel/ABC?utm_source=x`,
///   `https://m.instagram.com/someuser/reel/ABC/` and
///   `https://www.instagram.com/tv/ABC//?igsh=y` are all
///   `https://www.instagram.com/p/ABC/`.
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
    scheme: 'https',
    host: _instagramCanonicalHost,
    path: _instagramPath(parsed.path),
  );
}

/// `/p/CODE/` for a post path (Instagram redirects `/p/<reel code>` to the
/// reel, so one form covers all of them; the code keeps its case). Any other
/// path only gets exactly one trailing slash.
String _instagramPath(String path) {
  final code = _instagramPostPath.firstMatch(path)?.group(1);
  if (code != null) return '/p/$code/';
  return '${path.replaceFirst(_trailingSlashes, '')}/';
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
